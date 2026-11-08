import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

/// Gemini transcription through Vertex generateContent and its authenticated Live API.
public struct GoogleVertexGeminiTranscriptionModel: TranscriptionModel, StreamingTranscriptionModel, Sendable {
    public var providerID: String { config.providerID }
    public let modelID: String
    private let config: GoogleVertexConfig
    private let webSocketTransport: any AIDuplexWebSocketTransport
    private let finishGraceMilliseconds: Int
    init(modelID: String, config: GoogleVertexConfig, webSocketTransport: any AIDuplexWebSocketTransport, finishGraceMilliseconds: Int = 3_000) {
        self.modelID = modelID; self.config = config; self.webSocketTransport = webSocketTransport; self.finishGraceMilliseconds = finishGraceMilliseconds
    }

    public func transcribe(_ request: AudioTranscriptionRequest) async throws -> TranscriptionResult {
        guard !modelID.contains("-live") else { throw AIError.invalidArgument(argument: "modelID", message: "Model '\(modelID)' only supports streaming transcription. Use streamingTranscriptionModel, or a unary model such as gemini-3.5-transcribe.") }
        let timestamp = config.date()
        var options = try vertexGeminiTranscriptionOptions(request.providerOptions)
        var warnings: [AIWarning] = []
        let wantsWord = request.timestampGranularities?.contains(.word) == true
        if wantsWord && options["wordTimestamp"] == false { warnings.append(AIWarning(type: "unsupported", feature: "timestampGranularities", message: "The provider wordTimestamp option is false and overrides the requested word timings.")) }
        if request.timestampGranularities?.contains(.segment) == true { warnings.append(AIWarning(type: "unsupported", feature: "timestampGranularities", message: "Vertex Gemini transcription returns word timings and does not provide separate caption segments.")) }
        if wantsWord && options["wordTimestamp"] == nil { options["wordTimestamp"] = true }
        var body: [String: JSONValue] = ["contents": .array([.object(["role": "user", "parts": .array([.object(["inlineData": .object(["mimeType": .string(request.mimeType), "data": .string(request.audio.base64EncodedString())])])])])])]
        if !options.isEmpty { body["generationConfig"] = .object(["audioTranscriptionConfig": .object(options)]) }
        let response = try await config.sendJSONResponse(path: "/models/\(modelID):generateContent", body: .object(body), headers: request.headers, abortSignal: request.abortSignal)
        let raw = response.json
        let parts = raw["candidates"]?[0]?["content"]?["parts"]?.arrayValue ?? []
        let plain = parts.compactMap { $0["text"]?.stringValue }.joined()
        let text = plain.isEmpty ? parts.compactMap { $0["audioTranscription"]?["text"]?.stringValue }.joined() : plain
        var language: String?
        var words: [TranscriptionSegment] = []
        for part in parts {
            let transcription = part["audioTranscription"]
            language = language ?? transcription?["languageCode"]?.stringValue
            for word in transcription?["words"]?.arrayValue ?? [] {
                guard let text = word["word"]?.stringValue, let start = vertexTranscriptionOffset(word["startOffset"]?.stringValue), let end = vertexTranscriptionOffset(word["endOffset"]?.stringValue) else { continue }
                words.append(.init(text: text, startSecond: start, endSecond: end))
            }
        }
        if wantsWord && options["wordTimestamp"] != false && words.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { warnings.append(AIWarning(type: "other", message: "The Vertex Gemini transcription response omitted the requested word timings.")) }
        let usage = raw["usageMetadata"]?.objectValue
        return TranscriptionResult(text: text, rawValue: raw, segments: words, language: language, warnings: warnings, providerMetadata: usage.map { ["google": .object(["usageMetadata": .object($0)])] } ?? [:], requestMetadata: .init(body: .object(body), headers: request.headers, url: config.baseURL + "/models/\(modelID):generateContent"), responseMetadata: .init(timestamp: timestamp, modelID: modelID, headers: response.response.headers, body: raw), usage: usage, words: words.isEmpty ? nil : words)
    }

    public func stream(_ request: StreamingTranscriptionRequest) async throws -> StreamingTranscriptionResult {
        do {
            try request.abortSignal?.throwIfAborted()
            guard modelID.contains("-live") else { throw AIError.invalidArgument(argument: "modelID", message: "Model '\(modelID)' does not support streaming transcription. Use a Live model such as gemini-3.5-transcribe-live.") }
            guard request.inputAudioFormat.mediaType == "audio/pcm", request.inputAudioFormat.sampleRate == nil || request.inputAudioFormat.sampleRate == 16_000 else { throw AIError.invalidArgument(argument: "inputAudioFormat", message: "The Gemini Live transcription API only supports 16kHz 16-bit PCM input audio.") }
            guard !config.usesAPIKey, let project = config.project, !project.isEmpty, let location = config.location, !location.isEmpty else { throw AIError.invalidArgument(argument: "credentials", message: "Vertex Live transcription requires project, location and OAuth Bearer credentials.") }
            try validateHostnamePart(location, argument: "location")
            let options = try vertexGeminiTranscriptionOptions(request.providerOptions)
            let host: String
            if location == "global" { host = "aiplatform.googleapis.com" }
            else if location == "eu" || location == "us" { host = "aiplatform.\(location).rep.googleapis.com" }
            else { host = "\(location)-aiplatform.googleapis.com" }
            let url = try requireURL("wss://\(host)/ws/google.cloud.aiplatform.v1.LlmBidiService/BidiGenerateContent")
            let setup: JSONValue = .object(["model": .string("projects/\(project)/locations/\(location)/publishers/google/models/\(modelID)"), "inputAudioTranscription": .object(options)])
            let headers = try await config.authenticatedHeaders(request.headers)
            try request.abortSignal?.throwIfAborted()
            let connection = try await webSocketTransport.connect(.init(url: url, headers: headers, abortSignal: request.abortSignal))
            let session = VertexLiveTranscriptionSession(connection: connection, request: request, setup: setup, providerID: providerID, finishGraceMilliseconds: finishGraceMilliseconds)
            return .init(stream: session.makeStream(), requestMetadata: .init(body: setup, headers: request.headers, url: url.absoluteString), responseMetadata: .init(timestamp: config.date(), modelID: modelID), cancel: { Task { await session.cancel() } })
        } catch {
            request.audio.cancelFromConsumer()
            throw error
        }
    }
}

private func vertexGeminiTranscriptionOptions(_ values: [String: JSONValue]) throws -> [String: JSONValue] {
    let resolved = try resolveProviderOptions(providerOptions: values, namespaces: ["googleVertex", "vertex", "google"], resolution: .first)
    let options = resolved.options ?? [:]
    let keys = Set(["languageCodes", "customVocabulary", "wordTimestamp", "diarization", "mode"])
    for (key, value) in options where keys.contains(key) {
        let valid: Bool
        switch key {
        case "languageCodes", "customVocabulary": valid = value.arrayValue?.allSatisfy { $0.stringValue != nil } == true
        case "wordTimestamp", "diarization": valid = value.boolValue != nil
        case "mode": valid = value == "SMART" || value == "VERBATIM"
        default: valid = true
        }
        if !valid { throw AIError.invalidArgument(argument: key, message: "Invalid Vertex Gemini transcription provider option '\(key)'.") }
    }
    return options.filter { keys.contains($0.key) }
}

private func vertexTranscriptionOffset(_ value: String?) -> Double? {
    guard let value else { return nil }
    // Google duration offsets carry an `s` suffix. Preserve fractional seconds.
    let prefix = value.prefix { "0123456789+-.eE".contains($0) }
    guard let result = Double(prefix), result.isFinite else { return nil }
    return result
}

private actor VertexLiveTranscriptionSession {
    typealias Continuation = AsyncThrowingStream<StreamingTranscriptionPart, Error>.Continuation
    let connection: any AIDuplexWebSocketConnection
    let request: StreamingTranscriptionRequest
    let setup: JSONValue
    let providerID: String
    let finishGraceMilliseconds: Int
    var continuation: Continuation?
    var eventTask: Task<Void, Never>?
    var audioTask: Task<Void, Never>?
    var finishTask: Task<Void, Never>?
    var abortRegistration: AIAbortHandlerRegistration?
    var finished = false
    var started = false
    var setupComplete = false
    var audioEnded = false
    var segment = 0
    var buffer = ""
    var interim = ""
    var fullText = ""
    var language: String?
    var usage: [String: JSONValue]?

    init(connection: any AIDuplexWebSocketConnection, request: StreamingTranscriptionRequest, setup: JSONValue, providerID: String, finishGraceMilliseconds: Int) {
        self.connection = connection; self.request = request; self.setup = setup; self.providerID = providerID; self.finishGraceMilliseconds = finishGraceMilliseconds
    }
    nonisolated func makeStream() -> AsyncThrowingStream<StreamingTranscriptionPart, Error> {
        AsyncThrowingStream { continuation in
            Task { await self.start(continuation) }
            continuation.onTermination = { termination in if case .cancelled = termination { Task { await self.cancel() } } }
        }
    }
    func start(_ continuation: Continuation) {
        guard !started else { continuation.finish(throwing: AIError.invalidArgument(argument: "stream", message: "A streaming transcription result can only be consumed once.")); return }
        guard !finished else { continuation.finish(); return }
        started = true; self.continuation = continuation
        abortRegistration = request.abortSignal?.addAbortHandler { [weak self, signal = request.abortSignal] reason in
            Task { await self?.fail(AIAbortError(reason: reason, reasonName: signal?.reasonName)) }
        }
        eventTask = Task { await consumeEvents() }
    }
    func cancel() { complete(error: nil) }
    func fail(_ error: Error) { complete(error: error) }
    private func complete(error: Error?) {
        guard !finished else { return }
        finished = true
        if let error { continuation?.finish(throwing: error) } else { continuation?.finish() }
        abortRegistration?.cancel(); abortRegistration = nil
        finishTask?.cancel(); audioTask?.cancel(); eventTask?.cancel()
        request.audio.cancelFromConsumer()
        Task { await connection.close(code: 1_000) }
    }
    private func completeSegment() {
        if buffer.isEmpty { buffer = interim }
        guard !buffer.isEmpty else { return }
        continuation?.yield(.transcriptFinal(id: "google-segment-\(segment)", text: buffer))
        fullText += fullText.isEmpty ? buffer : " " + buffer
        buffer = ""; interim = ""; segment += 1
    }
    private func finish() {
        guard !finished else { return }
        completeSegment()
        let metadata: [String: JSONValue] = usage.map { ["google": .object(["usageMetadata": .object($0)])] } ?? [:]
        continuation?.yield(.finish(.init(text: fullText, language: language, providerMetadata: metadata, usage: usage)))
        complete(error: nil)
    }
    private func scheduleFinish() {
        guard audioEnded && !finished else { return }
        finishTask?.cancel()
        let delay = UInt64(max(0, finishGraceMilliseconds)) * 1_000_000
        finishTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: delay); await self?.finish() } catch { }
        }
    }
    private func send(_ value: JSONValue) async throws { try await connection.send(text: String(decoding: try encodeJSONBody(value), as: UTF8.self)) }
    private func sendAudio() async {
        do {
            for try await chunk in request.audio {
                if finished { return }
                try await send(.object(["realtimeInput": .object(["audio": .object(["data": .string(chunk.base64EncodedString()), "mimeType": "audio/pcm;rate=16000"])])]))
            }
            guard !finished else { return }
            try await send(.object(["realtimeInput": .object(["audioStreamEnd": true])]))
            guard !finished else { return }
            audioEnded = true; scheduleFinish()
        } catch { if !finished { fail(error) } }
    }
    private func consumeEvents() async {
        do {
            for try await event in connection.events {
                if finished { return }
                switch event {
                case .opened:
                    continuation?.yield(.streamStart(warnings: []))
                    try await send(.object(["setup": setup]))
                case let .message(message):
                    let text: String
                    switch message { case let .text(value): text = value; case let .binary(data): text = String(decoding: data, as: UTF8.self) }
                    guard let raw = try? secureJSONParse(text) else { continue }
                    if request.includeRawChunks { continuation?.yield(.raw(raw)) }
                    if let error = raw["error"], error != .null { fail(AIStreamingTranscriptionError(provider: providerID, message: error["message"]?.stringValue ?? "Vertex Live API error", rawValue: raw)); return }
                    if let acknowledged = raw["setupComplete"], acknowledged != .null, !setupComplete {
                        setupComplete = true; audioTask = Task { await sendAudio() }
                    }
                    if let value = raw["usageMetadata"]?.objectValue { usage = value }
                    let content = raw["serverContent"]
                    if let text = content?["interimInputTranscription"]?["text"]?.stringValue, !text.isEmpty {
                        scheduleFinish(); interim = text
                        continuation?.yield(.transcriptPartial(id: "google-segment-\(segment)", text: text))
                    }
                    if let transcription = content?["inputTranscription"] ?? raw["inputTranscription"], transcription != .null {
                        if let value = transcription["languageCode"]?.stringValue { language = value }
                        if let text = transcription["text"]?.stringValue, !text.isEmpty {
                            scheduleFinish(); interim = ""; buffer += text
                            continuation?.yield(.transcriptDelta(id: "google-segment-\(segment)", delta: text))
                        }
                        if transcription["finished"] == true { completeSegment() }
                    }
                    if content?["turnComplete"] == true { completeSegment() }
                    let status = content?["interactionStatus"]?.stringValue
                    if audioEnded && (status == "IDLE" || status == "REQUIRES_ACTION" || (content?["turnComplete"] == true && status == nil)) { finish(); return }
                case let .closed(metadata):
                    if audioEnded { finish() }
                    else { fail(AIStreamingTranscriptionError(provider: providerID, message: "Vertex Live transcription WebSocket closed unexpectedly before finishing (code \(metadata.code)).", closeMetadata: metadata)) }
                    return
                }
            }
            if !finished { if audioEnded { finish() } else { fail(AIStreamingTranscriptionError(provider: providerID, message: "Vertex Live transcription stream ended before audio completed.")) } }
        } catch { if !finished { fail(error) } }
    }
}
