import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

/// Incremental Voxtral transcription over the server WebSocket API.
public final class MistralStreamingTranscriptionModel: StreamingTranscriptionModel, Sendable {
    public let providerID = "mistral.transcription"
    public let modelID: String
    private let http: AIProviderHTTPClient
    private let webSocketTransport: any AIDuplexWebSocketTransport

    public init(modelID: String, http: AIProviderHTTPClient, webSocketTransport: any AIDuplexWebSocketTransport = URLSessionDuplexWebSocketTransport.shared) {
        self.modelID = modelID; self.http = http; self.webSocketTransport = webSocketTransport
    }

    public func stream(_ request: StreamingTranscriptionRequest) async throws -> StreamingTranscriptionResult {
        var handedOff = false
        defer { if !handedOff { request.audio.cancelFromConsumer() } }
        try Task.checkCancellation(); try request.abortSignal?.throwIfAborted()
        let rate = request.inputAudioFormat.sampleRate ?? 16_000
        guard request.inputAudioFormat.mediaType == "audio/pcm", rate > 0 else { throw AIError.invalidArgument(argument: "inputAudioFormat", message: "Mistral realtime transcription requires audio/pcm with a positive sample rate.") }
        let options = try mistralTranscriptionOptions(from: .init(audio: Data(), providerOptions: request.providerOptions))
        var session: [String: JSONValue] = ["audio_format": .object(["encoding": "pcm_s16le", "sample_rate": .number(Double(rate))])]
        session["language"] = options.language.map(JSONValue.string)
        session["context_bias"] = options.contextBias.map { .array($0.map(JSONValue.string)) }
        session["diarize"] = options.diarize.map(JSONValue.bool)
        session["target_streaming_delay_ms"] = options.realtime["targetStreamingDelayMs"]
        session["speaker_references"] = options.realtime["speakerReferences"]
        session["turn_detection"] = options.realtime["turnDetection"]
        var warnings: [AIWarning] = []
        if options.returnLanguage != nil { warnings.append(.init(type: "unsupported", feature: "providerOptions.mistral.returnLanguage", message: "This option is only supported for offline transcription.")) }
        if options.temperature != nil { warnings.append(.init(type: "unsupported", feature: "providerOptions.mistral.temperature", message: "This option is only supported for offline transcription.")) }
        if options.timestampGranularities != nil { warnings.append(.init(type: "unsupported", feature: "providerOptions.mistral.timestampGranularities", message: "This option is only supported for offline transcription.")) }
        var components = URLComponents(url: try http.url(modelID, "/audio/transcriptions/realtime"), resolvingAgainstBaseURL: false)!
        components.scheme = components.scheme == "http" ? "ws" : (components.scheme == "https" ? "wss" : components.scheme)
        let query = (components.queryItems ?? []) + [.init(name: "model", value: modelID)]
        components.percentEncodedQuery = query.map { "\(urlQueryEncode($0.name))=\(urlQueryEncode($0.value ?? ""))" }.joined(separator: "&")
        guard let endpoint = components.url else { throw AIError.invalidArgument(argument: "baseURL", message: "Invalid Mistral WebSocket URL.") }
        let headers = try await http.resolvedHeaders(request.headers)
        let connection = try await webSocketTransport.connect(.init(url: endpoint, headers: headers, abortSignal: request.abortSignal))
        let pair = AsyncThrowingStream<StreamingTranscriptionPart, Error>.makeStream()
        pair.continuation.yield(.streamStart(warnings: warnings))
        let state = MistralStreamingSession(connection: connection, request: request, continuation: pair.continuation, session: .object(session), modelID: modelID)
        pair.continuation.onTermination = { termination in if case .cancelled = termination { Task { await state.cancel() } } }
        await state.start(); handedOff = true
        return .init(stream: pair.stream, requestMetadata: .init(body: .object(session), url: endpoint.absoluteString), responseMetadata: .init(timestamp: Date(), modelID: modelID), cancel: { Task { await state.cancel() } })
    }
}

private actor MistralStreamingSession {
    let connection: any AIDuplexWebSocketConnection
    let request: StreamingTranscriptionRequest
    let continuation: AsyncThrowingStream<StreamingTranscriptionPart, Error>.Continuation
    let session: JSONValue
    let modelID: String
    var eventTask: Task<Void, Never>?
    var audioTask: Task<Void, Never>?
    var registration: AIAbortHandlerRegistration?
    var completed = false
    var configured = false
    var sending = false

    init(connection: any AIDuplexWebSocketConnection, request: StreamingTranscriptionRequest, continuation: AsyncThrowingStream<StreamingTranscriptionPart, Error>.Continuation, session: JSONValue, modelID: String) {
        self.connection = connection; self.request = request; self.continuation = continuation; self.session = session; self.modelID = modelID
    }
    func start() {
        if Task.isCancelled { fail(CancellationError()); return }
        if let signal = request.abortSignal, signal.isAborted { fail(AIAbortError(reason: signal.reason, reasonName: signal.reasonName)); return }
        registration = request.abortSignal?.addAbortHandler { [weak self, signal = request.abortSignal] reason in Task { await self?.fail(AIAbortError(reason: reason, reasonName: signal?.reasonName)) } }
        eventTask = Task { await consumeEvents() }
    }
    func cancel() { complete() }
    func fail(_ error: any Error) { complete(error: error) }
    private func complete(error: (any Error)? = nil, finish: StreamingTranscriptionFinish? = nil) {
        guard !completed else { return }; completed = true
        if let finish { continuation.yield(.finish(finish)) }
        if let error { continuation.finish(throwing: error) } else { continuation.finish() }
        registration?.cancel(); registration = nil
        eventTask?.cancel(); audioTask?.cancel()
        request.audio.cancelFromConsumer()
        Task { await connection.close() }
    }
    private func send(_ value: JSONValue) async throws { try await connection.send(text: String(decoding: encodeJSONBody(value), as: UTF8.self)) }
    private func consumeEvents() async {
        do {
            for try await event in connection.events {
                guard !completed else { return }
                try request.abortSignal?.throwIfAborted()
                switch event {
                case .opened: break // The server's session.created event starts configuration.
                case let .message(message):
                    let data: Data
                    switch message { case let .text(text): data = Data(text.utf8); case let .binary(bytes): data = bytes }
                    let raw = try JSONDecoder().decode(JSONValue.self, from: data)
                    guard raw.objectValue != nil, let type = raw["type"]?.stringValue else { throw invalidEvent(raw) }
                    if request.includeRawChunks { continuation.yield(.raw(raw)) }
                    try await handle(raw, type: type)
                case let .closed(close):
                    throw AIStreamingTranscriptionError(provider: "mistral.transcription", code: String(close.code), message: "Mistral realtime transcription connection closed before transcription.done (code: \(close.code)\(close.reason.map { ", reason: \($0)" } ?? "")).", closeMetadata: close)
                }
            }
            if !completed { throw AIStreamingTranscriptionError(provider: "mistral.transcription", message: "Mistral realtime transcription connection closed before transcription.done.") }
        } catch { if !completed { fail(error) } }
    }
    private func sendAudio() async {
        do {
            for try await chunk in request.audio {
                try Task.checkCancellation(); try request.abortSignal?.throwIfAborted(); guard !completed else { return }
                var offset = chunk.startIndex
                while offset < chunk.endIndex {
                    guard !completed else { return }; try Task.checkCancellation()
                    let end = min(offset + 64 * 1024, chunk.endIndex)
                    try await send(.object(["type": "input_audio.append", "audio": .string(chunk[offset..<end].base64EncodedString())]))
                    offset = end
                }
            }
            guard !completed else { return }
            try await send(.object(["type": "input_audio.end"]))
        } catch { if !completed { fail(error) } }
    }
    private func invalidEvent(_ raw: JSONValue) -> AIStreamingTranscriptionError { .init(provider: "mistral.transcription", message: "Invalid Mistral streaming transcription event.", rawValue: raw) }
    private func validateSegment(_ raw: JSONValue) throws {
        guard raw.objectValue != nil, raw["text"]?.stringValue != nil else { throw invalidEvent(raw) }
        for key in ["start", "end"] { if let value = raw[key], value != .null, value.doubleValue == nil { throw invalidEvent(raw) } }
        if let value = raw["speaker_id"], value != .null, value.stringValue == nil { throw invalidEvent(raw) }
    }
    private func handle(_ raw: JSONValue, type: String) async throws {
        switch type {
        case "session.created":
            guard !configured else { return }; configured = true
            try await send(.object(["type": "session.update", "session": session]))
        case "session.updated":
            guard configured && !sending && !completed else { return }; sending = true
            audioTask = Task { await sendAudio() }
        case "transcription.text.delta":
            guard let text = raw["text"]?.stringValue else { throw invalidEvent(raw) }
            continuation.yield(.transcriptDelta(id: nil, delta: text))
        case "transcription.segment":
            try validateSegment(raw)
            let metadata: [String: JSONValue] = raw["speaker_id"]?.stringValue.map { ["mistral": .object(["speakerId": .string($0)])] } ?? [:]
            continuation.yield(.transcriptFinal(id: nil, text: raw["text"]!.stringValue!, startSecond: raw["start"]?.doubleValue, endSecond: raw["end"]?.doubleValue, providerMetadata: metadata))
        case "transcription.done":
            guard let text = raw["text"]?.stringValue else { throw invalidEvent(raw) }
            for key in ["model", "language"] { if let value = raw[key], value != .null, value.stringValue == nil { throw invalidEvent(raw) } }
            if let value = raw["usage"], value != .null, value.objectValue == nil { throw invalidEvent(raw) }
            if let value = raw["segments"], value != .null, value.arrayValue == nil { throw invalidEvent(raw) }
            let rawSegments = raw["segments"]?.arrayValue ?? []
            for value in rawSegments { try validateSegment(value) }
            let segments = rawSegments.compactMap { value -> TranscriptionSegment? in
                guard let start = value["start"]?.doubleValue, let end = value["end"]?.doubleValue else { return nil }
                return .init(text: value["text"]!.stringValue!, startSecond: start, endSecond: end)
            }
            var metadata: [String: JSONValue] = [:]
            if let usage = raw["usage"], usage != .null { metadata["usage"] = usage }
            do {
                metadata["segments"] = .array(rawSegments.map { value in
                    var segment: [String: JSONValue] = ["text": value["text"]!]
                    if let start = value["start"], start != .null { segment["startSecond"] = start }
                    if let end = value["end"], end != .null { segment["endSecond"] = end }
                    if let speaker = value["speaker_id"], speaker != .null { segment["speakerId"] = speaker }
                    return .object(segment)
                })
            }
            continuation.yield(.responseMetadata(.init(timestamp: Date(), modelID: raw["model"]?.stringValue ?? modelID, body: raw)))
            complete(finish: .init(text: text, segments: segments, language: raw["language"]?.stringValue, durationInSeconds: raw["usage"]?["prompt_audio_seconds"]?.doubleValue, providerMetadata: metadata.isEmpty ? [:] : ["mistral": .object(metadata)], usage: raw["usage"]?.objectValue))
        case "error":
            guard let message = raw["error"]?["message"]?.stringValue else { throw invalidEvent(raw) }
            throw AIStreamingTranscriptionError(provider: "mistral.transcription", message: message, rawValue: raw)
        default: break
        }
    }
}
