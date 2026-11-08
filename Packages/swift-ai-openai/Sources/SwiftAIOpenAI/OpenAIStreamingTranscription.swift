import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

func openAITranscriptionIsStreamingOnly(_ modelID: String) -> Bool {
    ["gpt-live-transcribe", "gpt-realtime-whisper"].contains { modelID == $0 || modelID.hasPrefix($0 + "-") }
}

extension OpenAICompatibleTranscriptionModel {
    public func stream(_ request: StreamingTranscriptionRequest) async throws -> StreamingTranscriptionResult {
        let supportsDelay = openAITranscriptionIsStreamingOnly(modelID)
        let turnBased = modelID == "gpt-transcribe" || modelID.hasPrefix("gpt-transcribe-")
        guard supportsDelay || turnBased else {
            throw AIError.invalidArgument(argument: "modelID", message: "Streaming transcription is not supported with \(modelID).")
        }
        try request.abortSignal?.throwIfAborted()
        if let value = request.providerOptions["openai"], value.objectValue == nil { throw invalidStreamingOption("openai") }
        let options = request.providerOptions["openai"]?.objectValue ?? [:]
        var warnings: [AIWarning] = []
        for option in ["include", "languages", "keywords", "prompt", "temperature", "timestampGranularities"] where options[option] != nil {
            warnings.append(AIWarning(type: "unsupported", feature: "providerOptions.openai.\(option)", message: "OpenAI streaming transcription does not support \(option)."))
        }
        let language = options["language"]?.stringValue
        if let value = options["language"], value.stringValue == nil { throw invalidStreamingOption("language") }
        let streaming = options["streaming"]?.objectValue ?? [:]
        if options["streaming"] != nil, options["streaming"]?.objectValue == nil { throw invalidStreamingOption("streaming") }
        if let delay = streaming["delay"], !["minimal", "low", "medium", "high", "xhigh"].contains(delay.stringValue ?? "") { throw invalidStreamingOption("streaming.delay") }
        if let include = streaming["include"], include.arrayValue?.allSatisfy({ $0.stringValue != nil }) != true { throw invalidStreamingOption("streaming.include") }
        if !supportsDelay, streaming["delay"] != nil {
            warnings.append(AIWarning(type: "unsupported", feature: "providerOptions.openai.streaming.delay", message: "OpenAI streaming transcription with \(modelID) does not support delay."))
        }
        var transcription: [String: JSONValue] = ["model": .string(modelID)]
        if let language { transcription[turnBased || modelID.hasPrefix("gpt-live-transcribe") ? "languages" : "language"] = turnBased || modelID.hasPrefix("gpt-live-transcribe") ? .array([.string(language)]) : .string(language) }
        if supportsDelay { transcription["delay"] = streaming["delay"] }
        let format: JSONValue = .object(["type": .string(request.inputAudioFormat.mediaType), "rate": request.inputAudioFormat.sampleRate.map { .number(Double($0)) }])
        let update: JSONValue = .object(["type": "session.update", "session": .object([
            "type": "transcription", "include": streaming["include"],
            "audio": .object(["input": .object(["format": format, "transcription": .object(transcription), "turn_detection": .null])])
        ])])
        let httpURL = try config.url(modelID, "/realtime")
        guard var components = URLComponents(url: httpURL, resolvingAgainstBaseURL: false) else { throw AIError.invalidURL(httpURL.absoluteString) }
        components.scheme = components.scheme == "http" ? "ws" : "wss"
        components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "intent", value: "transcription")]
        guard let url = components.url else { throw AIError.invalidURL(httpURL.absoluteString) }
        let connection: any AIDuplexWebSocketConnection
        do {
            let headers = try await config.http.resolvedHeaders(request.headers)
            try request.abortSignal?.throwIfAborted()
            connection = try await config.webSocketTransport.connect(.init(url: url, headers: headers, abortSignal: request.abortSignal))
        } catch {
            request.audio.cancelFromConsumer()
            throw error
        }
        let session = OpenAITranscriptionSession(providerID: providerID, connection: connection, request: request, update: update, language: language, warnings: warnings)
        let stream = await session.start()
        return StreamingTranscriptionResult(stream: stream,
            requestMetadata: .init(body: update, headers: request.headers), responseMetadata: .init(timestamp: Date(), modelID: modelID),
            cancel: { Task { await session.cancel() } })
    }

    private func invalidStreamingOption(_ option: String) -> AIError {
        .invalidArgument(argument: "providerOptions.openai.\(option)", message: "Invalid OpenAI transcription option.")
    }
}

private actor OpenAITranscriptionSession {
    let providerID: String
    let connection: any AIDuplexWebSocketConnection
    let request: StreamingTranscriptionRequest
    let update: JSONValue
    let language: String?
    let warnings: [AIWarning]
    var continuation: AsyncThrowingStream<StreamingTranscriptionPart, Error>.Continuation?
    var eventTask: Task<Void, Never>?
    var audioTask: Task<Void, Never>?
    var abortRegistration: AIAbortHandlerRegistration?
    var completed = false
    var opened = false

    init(providerID: String, connection: any AIDuplexWebSocketConnection, request: StreamingTranscriptionRequest,
         update: JSONValue, language: String?, warnings: [AIWarning]) {
        self.providerID = providerID; self.connection = connection; self.request = request
        self.update = update; self.language = language; self.warnings = warnings
    }

    func start() -> AsyncThrowingStream<StreamingTranscriptionPart, Error> {
        let pair = AsyncThrowingStream<StreamingTranscriptionPart, Error>.makeStream()
        continuation = pair.continuation
        continuation?.onTermination = { termination in
            if case .cancelled = termination { Task { await self.cancel() } }
        }
        abortRegistration = request.abortSignal?.addAbortHandler { [weak signal = request.abortSignal] reason in
            Task { await self.complete(error: AIAbortError(reason: reason, reasonName: signal?.reasonName), finish: nil) }
        }
        eventTask = Task { await consumeEvents() }
        return pair.stream
    }

    func cancel() async { await complete(error: nil, finish: nil) }

    private func consumeEvents() async {
        do {
            for try await event in connection.events {
                guard !completed else { return }
                switch event {
                case .opened:
                    guard !opened else { continue }
                    opened = true
                    continuation?.yield(.streamStart(warnings: warnings))
                    try await send(update)
                    audioTask = Task { await sendAudio() }
                case let .message(message):
                    let data: Data
                    switch message { case let .text(text): data = Data(text.utf8); case let .binary(bytes): data = bytes }
                    guard let raw = try? decodeJSONBody(data) else { continue }
                    if request.includeRawChunks { continuation?.yield(.raw(raw)) }
                    switch raw["type"]?.stringValue {
                    case "conversation.item.input_audio_transcription.delta":
                        continuation?.yield(.transcriptDelta(id: raw["item_id"]?.stringValue, delta: raw["delta"]?.stringValue ?? ""))
                    case "conversation.item.input_audio_transcription.completed":
                        let text = raw["transcript"]?.stringValue ?? ""
                        if let id = raw["item_id"]?.stringValue { continuation?.yield(.transcriptFinal(id: id, text: text)) }
                        await complete(error: nil, finish: .init(text: text, language: language))
                    case "error":
                        await complete(error: AIStreamingTranscriptionError(provider: providerID, code: raw["error"]?["code"]?.stringValue,
                            message: raw["error"]?["message"]?.stringValue ?? "OpenAI realtime error", rawValue: raw), finish: nil)
                    default: break
                    }
                case .closed: await complete(error: nil, finish: nil)
                }
            }
            if !completed { await complete(error: nil, finish: nil) }
        } catch { await complete(error: error, finish: nil) }
    }

    private func sendAudio() async {
        do {
            for try await chunk in request.audio {
                guard !completed else { return }
                try Task.checkCancellation()
                try await send(["type": "input_audio_buffer.append", "audio": .string(chunk.base64EncodedString())])
            }
            if !completed { try await send(["type": "input_audio_buffer.commit"]) }
        } catch { await complete(error: error, finish: nil) }
    }

    private func send(_ value: JSONValue) async throws {
        guard !completed else { return }
        try await connection.send(text: String(decoding: try encodeJSONBody(value), as: UTF8.self))
    }

    private func complete(error: Error?, finish: StreamingTranscriptionFinish?) async {
        guard !completed else { return }
        completed = true
        eventTask?.cancel(); audioTask?.cancel(); abortRegistration?.cancel()
        request.audio.cancelFromConsumer()
        if let finish { continuation?.yield(.finish(finish)) }
        if let error { continuation?.finish(throwing: error) } else { continuation?.finish() }
        continuation = nil
        await connection.close(code: finish == nil ? 1001 : 1000)
    }
}
