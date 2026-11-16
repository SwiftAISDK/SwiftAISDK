import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

/// Raw PCM, μ-law or A-law streaming transcription using Deepgram's v1 listen protocol.
public final class DeepgramStreamingTranscriptionModel: StreamingTranscriptionModel, Sendable {
    public let providerID = "deepgram.transcription"
    public let modelID: String
    private let http: AIProviderHTTPClient
    private let webSocketTransport: any AIDuplexWebSocketTransport
    private let keepAliveNanoseconds: UInt64

    public init(modelID: String, http: AIProviderHTTPClient, webSocketTransport: any AIDuplexWebSocketTransport = URLSessionDuplexWebSocketTransport.shared) {
        self.modelID = modelID; self.http = http; self.webSocketTransport = webSocketTransport
        self.keepAliveNanoseconds = 4_000_000_000
    }

    init(modelID: String, http: AIProviderHTTPClient, webSocketTransport: any AIDuplexWebSocketTransport, keepAliveNanoseconds: UInt64) {
        self.modelID = modelID; self.http = http; self.webSocketTransport = webSocketTransport; self.keepAliveNanoseconds = keepAliveNanoseconds
    }

    public func stream(_ request: StreamingTranscriptionRequest) async throws -> StreamingTranscriptionResult {
        var handedOff = false
        defer { if !handedOff { request.audio.cancelFromConsumer() } }
        try Task.checkCancellation(); try request.abortSignal?.throwIfAborted()
        guard !modelID.hasPrefix("flux") else { throw AIError.invalidArgument(argument: "modelID", message: "Deepgram Flux requires the v2 protocol; use a v1 listen model.") }
        let encodings = ["audio/pcm": "linear16", "audio/pcmu": "mulaw", "audio/pcma": "alaw"]
        guard let encoding = encodings[request.inputAudioFormat.mediaType],
              let sampleRate = request.inputAudioFormat.sampleRate, sampleRate > 0 else {
            throw AIError.invalidArgument(argument: "inputAudioFormat", message: "Deepgram streaming requires audio/pcm (16-bit little-endian), audio/pcmu, or audio/pcma and a positive integer sample rate.")
        }
        var options: [String: JSONValue] = [:]
        if let value = request.providerOptions["deepgram"], value != .null {
            guard let object = value.objectValue else { throw AIError.invalidArgument(argument: "providerOptions.deepgram", message: "Deepgram provider options must be an object.") }
            options = try deepgramValidateTranscriptionProviderOptions(object)
        }
        var url = URLComponents(url: try http.url(modelID, "/v1/listen"), resolvingAgainstBaseURL: false)!
        url.scheme = url.scheme == "http" ? "ws" : (url.scheme == "https" ? "wss" : url.scheme)
        var query = url.queryItems ?? []
        query += [.init(name: "model", value: modelID), .init(name: "encoding", value: encoding), .init(name: "sample_rate", value: String(sampleRate))]
        let shared = ["language": "language", "smartFormat": "smart_format", "punctuate": "punctuate", "diarize": "diarize", "fillerWords": "filler_words", "redact": "redact", "replace": "replace", "search": "search", "keyterm": "keyterm"]
        var warnings: [AIWarning] = []
        func append(_ name: String, _ value: JSONValue) {
            if let array = value.arrayValue { for item in array { append(name, item) }; return }
            let string = value.stringValue ?? value.boolValue.map(String.init) ?? value.doubleValue.map { $0.rounded() == $0 ? String(format: "%.0f", $0) : String($0) }
            if let string { query.append(.init(name: name, value: string)) }
        }
        // Upstream iterates the parsed options in schema order, so repeated
        // query parameters and warnings follow that order deterministically.
        for key in deepgramTranscriptionProviderOptionOrder {
            guard let value = options[key], value != .null, key != "streaming" else { continue }
            if let mapped = shared[key] { append(mapped, value) }
            else if value != .bool(false) { warnings.append(.init(type: "unsupported", feature: "providerOptions.deepgram.\(key)", message: "This option is not supported for Deepgram streaming transcription.")) }
        }
        let streamingKeys: KeyValuePairs = ["interimResults": "interim_results", "endpointing": "endpointing", "channels": "channels", "multichannel": "multichannel", "vadEvents": "vad_events", "utteranceEndMs": "utterance_end_ms"]
        let streaming = options["streaming"]?.objectValue ?? [:]
        for (key, mapped) in streamingKeys { if let value = streaming[key], value != .null { append(mapped, value) } }
        url.percentEncodedQuery = query.map { "\(urlQueryEncode($0.name))=\(urlQueryEncode($0.value ?? ""))" }.joined(separator: "&")
        guard let endpoint = url.url else { throw AIError.invalidArgument(argument: "baseURL", message: "Invalid Deepgram WebSocket URL.") }
        let headers = try await http.resolvedHeaders(request.headers)
        let authorization = headers.first { $0.key.caseInsensitiveCompare("authorization") == .orderedSame }?.value ?? ""
        let fields = authorization.split(separator: " ", omittingEmptySubsequences: false)
        guard fields.count == 2, ["token", "bearer"].contains(fields[0].lowercased()), !fields[1].isEmpty, !fields[1].contains(where: { $0.isWhitespace }) else { throw AIError.invalidArgument(argument: "headers", message: "Deepgram streaming authorization must use the Token or Bearer scheme.") }
        let connection = try await webSocketTransport.connect(.init(url: endpoint, headers: headers, protocols: [fields[0].lowercased(), String(fields[1])], abortSignal: request.abortSignal))
        let pair = AsyncThrowingStream<StreamingTranscriptionPart, Error>.makeStream()
        let timestamp = Date()
        let session = DeepgramStreamingSession(connection: connection, request: request, continuation: pair.continuation, warnings: warnings, modelID: modelID, language: options["language"]?.stringValue, timestamp: timestamp, keepAliveNanoseconds: keepAliveNanoseconds)
        pair.continuation.onTermination = { termination in if case .cancelled = termination { Task { await session.cancel() } } }
        await session.start(); handedOff = true
        return StreamingTranscriptionResult(stream: pair.stream, requestMetadata: .init(body: .string(endpoint.absoluteString), url: endpoint.absoluteString), responseMetadata: .init(timestamp: timestamp, modelID: modelID), cancel: { Task { await session.cancel() } })
    }
}

private actor DeepgramStreamingSession {
    let connection: any AIDuplexWebSocketConnection
    let request: StreamingTranscriptionRequest
    let continuation: AsyncThrowingStream<StreamingTranscriptionPart, Error>.Continuation
    let warnings: [AIWarning]
    let modelID: String
    let timestamp: Date
    let keepAliveNanoseconds: UInt64
    var language: String?
    var eventTask: Task<Void, Never>?
    var audioTask: Task<Void, Never>?
    var keepAliveTask: Task<Void, Never>?
    var registration: AIAbortHandlerRegistration?
    var completed = false
    var opened = false
    var inputEnded = false
    var reportedDuration: Double?
    var duration: Double?
    var texts: [(text: String, start: Double, channel: Int, sequence: Int)] = []
    var segments: [TranscriptionSegment] = []

    init(connection: any AIDuplexWebSocketConnection, request: StreamingTranscriptionRequest, continuation: AsyncThrowingStream<StreamingTranscriptionPart, Error>.Continuation, warnings: [AIWarning], modelID: String, language: String?, timestamp: Date, keepAliveNanoseconds: UInt64) {
        self.connection = connection; self.request = request; self.continuation = continuation; self.warnings = warnings; self.modelID = modelID; self.language = language; self.timestamp = timestamp; self.keepAliveNanoseconds = keepAliveNanoseconds
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
        eventTask?.cancel(); audioTask?.cancel(); keepAliveTask?.cancel()
        request.audio.cancelFromConsumer()
        Task { await connection.close() }
    }

    private func finish(_ close: AIDuplexWebSocketCloseMetadata? = nil) {
        let sorted = texts.sorted { $0.start == $1.start ? ($0.channel == $1.channel ? $0.sequence < $1.sequence : $0.channel < $1.channel) : $0.start < $1.start }
        complete(finish: .init(text: sorted.map(\.text).joined(separator: " "), segments: segments.sorted { $0.startSecond < $1.startSecond }, language: language, durationInSeconds: duration, closeMetadata: close, usage: reportedDuration.map { ["seconds": .number($0)] }))
    }

    private func consumeEvents() async {
        do {
            for try await event in connection.events {
                guard !completed else { return }
                try request.abortSignal?.throwIfAborted()
                switch event {
                case .opened:
                    guard !opened else { continue }; opened = true
                    continuation.yield(.streamStart(warnings: warnings))
                    audioTask = Task { await sendAudio() }
                    keepAliveTask = Task { await keepAlive() }
                case let .message(message):
                    let data: Data
                    switch message { case let .text(text): data = Data(text.utf8); case let .binary(bytes): data = bytes }
                    let raw = try JSONDecoder().decode(JSONValue.self, from: data)
                    guard raw.objectValue != nil, let type = raw["type"]?.stringValue else { throw invalidEvent(raw) }
                    if request.includeRawChunks { continuation.yield(.raw(raw)) }
                    try handle(raw, type: type)
                case let .closed(close):
                    guard close.code == 1000, inputEnded else { throw AIStreamingTranscriptionError(provider: "deepgram.transcription", code: String(close.code), message: "Deepgram streaming connection closed unexpectedly (\(close.code))\(close.reason.flatMap { $0.isEmpty ? nil : ": \($0)" } ?? ".")", closeMetadata: close) }
                    finish(close); return
                }
            }
            if !completed {
                if inputEnded { finish() }
                else { throw AIStreamingTranscriptionError(provider: "deepgram.transcription", message: "Deepgram streaming connection closed unexpectedly.") }
            }
        } catch { if !completed { fail(error) } }
    }

    private func sendAudio() async {
        do {
            for try await chunk in request.audio {
                try Task.checkCancellation(); try request.abortSignal?.throwIfAborted(); guard !completed else { return }
                if !chunk.isEmpty { try await connection.send(binary: chunk) }
            }
            guard !completed else { return }
            inputEnded = true; keepAliveTask?.cancel()
            try await connection.send(text: #"{"type":"CloseStream"}"#)
        } catch { if !completed { fail(error) } }
    }

    private func keepAlive() async {
        do {
            while !completed && !inputEnded {
                try await Task.sleep(nanoseconds: keepAliveNanoseconds)
                guard !completed && !inputEnded else { return }
                try request.abortSignal?.throwIfAborted()
                try await connection.send(text: #"{"type":"KeepAlive"}"#)
            }
        } catch is CancellationError {} catch { if !completed { fail(error) } }
    }

    private func invalidEvent(_ raw: JSONValue) -> AIStreamingTranscriptionError { .init(provider: "deepgram.transcription", message: "Invalid Deepgram streaming event.", rawValue: raw) }
    private func handle(_ raw: JSONValue, type: String) throws {
        switch type {
        case "Error":
            for key in ["description", "message"] { if let value = raw[key], value != .null, value.stringValue == nil { throw invalidEvent(raw) } }
            throw AIStreamingTranscriptionError(provider: "deepgram.transcription", message: raw["description"]?.stringValue ?? raw["message"]?.stringValue ?? "Deepgram streaming transcription failed.", rawValue: raw)
        case "Metadata":
            if let value = raw["duration"], value != .null {
                guard let value = value.doubleValue else { throw invalidEvent(raw) }
                reportedDuration = value; duration = value
            }
            continuation.yield(.responseMetadata(.init(timestamp: timestamp, modelID: modelID, body: raw)))
            if inputEnded { finish() }
        case "Results":
            for key in ["is_final", "speech_final"] { if let value = raw[key], value != .null, value.boolValue == nil { throw invalidEvent(raw) } }
            for key in ["start", "duration"] { if let value = raw[key], value != .null, value.doubleValue == nil { throw invalidEvent(raw) } }
            if let indexes = raw["channel_index"], indexes != .null, indexes.arrayValue?.allSatisfy({ $0.doubleValue != nil }) != true { throw invalidEvent(raw) }
            // `channel` is nullish upstream; a missing channel or an empty
            // alternatives list fails with the dedicated message below.
            let channelValue = raw["channel"] ?? .null
            if channelValue != .null, channelValue["alternatives"]?.arrayValue == nil { throw invalidEvent(raw) }
            let alternatives = channelValue["alternatives"]?.arrayValue ?? []
            for alternative in alternatives {
                guard alternative["transcript"]?.stringValue != nil else { throw invalidEvent(raw) }
                if let languages = alternative["languages"], languages != .null, languages.arrayValue?.allSatisfy({ $0.stringValue != nil }) != true { throw invalidEvent(raw) }
                if let words = alternative["words"], words != .null {
                    guard let items = words.arrayValue, items.allSatisfy({ $0["word"]?.stringValue != nil && $0["start"]?.doubleValue != nil && $0["end"]?.doubleValue != nil && ($0["punctuated_word"] == nil || $0["punctuated_word"] == .null || $0["punctuated_word"]?.stringValue != nil) }) else { throw invalidEvent(raw) }
                }
            }
            guard let alternative = alternatives.first else { throw AIStreamingTranscriptionError(provider: "deepgram.transcription", message: "Deepgram Results event is missing a transcript alternative.", rawValue: raw) }
            let text = alternative["transcript"]!.stringValue!
            let start = raw["start"]?.doubleValue ?? 0
            let span = raw["duration"]?.doubleValue ?? 0
            let end = start + span
            let channelNumber = raw["channel_index"]?[0]?.doubleValue ?? 0
            guard let channel = Int(exactly: channelNumber) else { throw invalidEvent(raw) }
            let channelIndex = raw["channel_index"]?[0] == nil ? nil : channel
            let speechFinal: JSONValue = raw["speech_final"]?.boolValue.map(JSONValue.bool) ?? .bool(false)
            let metadata: [String: JSONValue] = ["deepgram": .object(["speechFinal": speechFinal])]
            duration = max(duration ?? 0, end)
            language = alternative["languages"]?[0]?.stringValue ?? language
            if raw["is_final"] == .bool(true) {
                if !text.isEmpty { texts.append((text, start, channel, texts.count)) }
                for word in alternative["words"]?.arrayValue ?? [] { segments.append(.init(text: word["punctuated_word"]?.stringValue ?? word["word"]!.stringValue!, startSecond: word["start"]!.doubleValue!, endSecond: word["end"]!.doubleValue!)) }
                continuation.yield(.transcriptFinal(id: nil, text: text, startSecond: start, endSecond: end, channelIndex: channelIndex, providerMetadata: metadata))
            } else { continuation.yield(.transcriptPartial(id: nil, text: text, startSecond: start, durationInSeconds: raw["duration"]?.doubleValue, channelIndex: channelIndex, providerMetadata: metadata)) }
        default: break
        }
    }
}
