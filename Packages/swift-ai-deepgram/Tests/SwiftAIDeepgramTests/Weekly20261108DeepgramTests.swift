@testable import SwiftAIDeepgram
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Foundation
import Testing

private actor DeepgramTestSocket: AIDuplexWebSocketConnection {
    nonisolated let events: AsyncThrowingStream<AIDuplexWebSocketEvent, Error>
    nonisolated let continuation: AsyncThrowingStream<AIDuplexWebSocketEvent, Error>.Continuation
    var sent: [AIDuplexWebSocketMessage] = []
    var closes = 0
    var blockNext = false
    var blocked: CheckedContinuation<Void, Error>?
    init() { let pair = AsyncThrowingStream<AIDuplexWebSocketEvent, Error>.makeStream(); events = pair.stream; continuation = pair.continuation }
    func send(_ message: AIDuplexWebSocketMessage) async throws { sent.append(message); if blockNext { blockNext = false; try await withCheckedThrowingContinuation { blocked = $0 } } }
    func close(code: Int, reason: Data?) async { closes += 1; unblock(throwing: CancellationError()) }
    func block() { blockNext = true }
    func unblock(throwing error: (any Error)? = nil) { let value = blocked; blocked = nil; if let error { value?.resume(throwing: error) } else { value?.resume() } }
    nonisolated func message(_ raw: String) { continuation.yield(.message(.text(raw))) }
    nonisolated func open() { continuation.yield(.opened(protocol: nil)) }
}
private actor DeepgramTestWebSockets: AIDuplexWebSocketTransport {
    let socket: DeepgramTestSocket
    var requests: [AIDuplexWebSocketRequest] = []
    init(_ socket: DeepgramTestSocket = .init()) { self.socket = socket }
    func connect(_ request: AIDuplexWebSocketRequest) async throws -> any AIDuplexWebSocketConnection { requests.append(request); return socket }
}
private func deepgramWait(_ predicate: () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while !(await predicate()) { guard ContinuousClock.now < deadline else { throw AIError.timeout(durationNanoseconds: 3_000_000_000) }; try await Task.sleep(nanoseconds: 1_000_000) }
}
private func deepgramParts(_ result: StreamingTranscriptionResult) async throws -> [StreamingTranscriptionPart] { var parts: [StreamingTranscriptionPart] = []; for try await part in result.stream { parts.append(part) }; return parts }
private func deepgramStream(_ sockets: DeepgramTestWebSockets, options: [String: JSONValue] = [:], audio: AIStreamingAudioInput = .chunks([Data([1, 2]), Data(), Data([3])]), abort: AIAbortSignal? = nil, raw: Bool = false) async throws -> StreamingTranscriptionResult {
    let provider = try DeepgramProvider(configuration: .init(apiKey: "secret", webSocketTransport: sockets))
    return try await provider.streamingTranscriptionModel("nova-3").stream(.init(audio: audio, inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 16000), providerOptions: options.isEmpty ? [:] : ["deepgram": .object(options)], includeRawChunks: raw, abortSignal: abort))
}

@Test func weekly20261108DeepgramStreamBuildsAuthAndMappedRepeatedOptions() async throws {
    let sockets = DeepgramTestWebSockets()
    let provider = try DeepgramProvider(configuration: .init(apiKey: "secret", baseURL: "http://proxy.test/api", headers: ["X-Provider": "yes"], queryParams: ["custom": "q"], webSocketTransport: sockets))
    let result = try await provider.streamingTranscriptionModel("nova-3").stream(.init(audio: .chunks([]), inputAudioFormat: .init(mediaType: "audio/pcmu", sampleRate: 8000), providerOptions: ["deepgram": .object(["redact": .array(["pci", "ssn"]), "streaming": .object(["interimResults": true, "endpointing": false, "channels": 2, "vadEvents": true, "utteranceEndMs": 1000])])], headers: ["Authorization": "bEaReR override"]))
    let request = try #require(await sockets.requests.first)
    #expect(request.url.scheme == "ws")
    #expect(request.protocols == ["bearer", "override"])
    #expect(!request.url.absoluteString.contains("secret")); #expect(!request.url.absoluteString.contains("override"))
    let query = URLComponents(url: request.url, resolvingAgainstBaseURL: false)!.queryItems!
    #expect(query.filter { $0.name == "redact" }.compactMap(\.value) == ["pci", "ssn"])
    #expect(query.contains(.init(name: "encoding", value: "mulaw")))
    #expect(query.contains(.init(name: "endpointing", value: "false")))
    #expect(query.contains(.init(name: "interim_results", value: "true")))
    #expect(query.contains(.init(name: "channels", value: "2")))
    #expect(result.requestMetadata.headers.isEmpty)
    result.cancel(); try await deepgramWait { await sockets.socket.closes == 1 }
}

@Test func weekly20261108DeepgramStreamAggregatesOnlyFinalsAndPreservesMetadata() async throws {
    let sockets = DeepgramTestWebSockets()
    let result = try await deepgramStream(sockets, raw: true)
    let collected = Task { try await deepgramParts(result) }
    sockets.socket.open()
    try await deepgramWait { await sockets.socket.sent.contains(.text(#"{"type":"CloseStream"}"#)) }
    sockets.socket.message(#"{"type":"Results","start":0,"duration":0.5,"channel":{"alternatives":[{"transcript":"draft"}]}}"#)
    sockets.socket.message(#"{"type":"Results","is_final":true,"speech_final":true,"start":2,"duration":1,"channel_index":[1],"channel":{"alternatives":[{"transcript":"later","languages":["en"],"words":[{"word":"later","punctuated_word":"Later.","start":2,"end":3}]}]}}"#)
    sockets.socket.message(#"{"type":"Results","is_final":true,"start":0,"duration":1,"channel_index":[0],"channel":{"alternatives":[{"transcript":"first","words":[{"word":"first","start":0,"end":1}]}]}}"#)
    sockets.socket.message(#"{"type":"SpeechStarted","future":true}"#)
    sockets.socket.message(#"{"type":"Metadata","duration":4}"#)
    let parts = try await collected.value
    guard case let .finish(finish) = parts.last else { Issue.record("Expected finish"); return }
    #expect(finish.text == "first later"); #expect(finish.language == "en")
    #expect(finish.durationInSeconds == 4); #expect(finish.usage == ["seconds": 4])
    #expect(finish.segments.map(\.text) == ["first", "Later."])
    #expect(parts.contains { if case .transcriptPartial(_, "draft", _, _, _, _) = $0 { true } else { false } })
    #expect(parts.contains { if case let .raw(value) = $0 { value["type"] == "SpeechStarted" } else { false } })
    try await deepgramWait { await sockets.socket.closes == 1 }
    #expect(await sockets.socket.sent == [.binary(Data([1, 2])), .binary(Data([3])), .text(#"{"type":"CloseStream"}"#)])
}

@Test func weekly20261108DeepgramTimingDoesNotInventUsage() async throws {
    let sockets = DeepgramTestWebSockets(); let result = try await deepgramStream(sockets)
    let collected = Task { try await deepgramParts(result) }; sockets.socket.open()
    try await deepgramWait { await sockets.socket.sent.count == 3 }
    sockets.socket.message(#"{"type":"Results","is_final":true,"start":1,"duration":2,"channel":{"alternatives":[{"transcript":"ok"}]}}"#)
    sockets.socket.continuation.yield(.closed(.init(code: 1000)))
    guard case let .finish(finish) = try await collected.value.last else { Issue.record("Expected finish"); return }
    #expect(finish.durationInSeconds == 3); #expect(finish.usage == nil)
}

@Test(arguments: ["invalid-json", "invalid-event", "provider", "early-close", "abnormal-close", "input", "socket"])
func weekly20261108DeepgramStreamingFailuresCleanUp(_ failure: String) async throws {
    let socket = DeepgramTestSocket(); let sockets = DeepgramTestWebSockets(socket)
    let pair = AIStreamingAudioInput.makeStream()
    let result = try await deepgramStream(sockets, audio: pair.input)
    let collected = Task { try await deepgramParts(result) }; socket.open()
    switch failure {
    case "invalid-json": socket.message("{")
    case "invalid-event": socket.message(#"{"type":"Results","channel":{"alternatives":[{"transcript":123}]}}"#)
    case "provider": socket.message(#"{"type":"Error","description":"bad audio"}"#)
    case "early-close": socket.continuation.yield(.closed(.init(code: 1000, reason: "early")))
    case "abnormal-close": socket.continuation.yield(.closed(.init(code: 1008, reason: "DATA-0000")))
    case "input": pair.writer.cancel(reason: "microphone failed")
    default: socket.continuation.finish(throwing: AIError.invalidResponse(provider: "socket", message: "lost"))
    }
    await #expect(throws: (any Error).self) { _ = try await collected.value }
    try await deepgramWait { await socket.closes == 1 }
    #expect(pair.writer.send(Data([9])) == .terminated)
}

@Test func weekly20261108DeepgramBackpressureAndKeepaliveStopOnCancel() async throws {
    let socket = DeepgramTestSocket(); await socket.block()
    let sockets = DeepgramTestWebSockets(socket)
    let result = try await deepgramStream(sockets)
    socket.open(); try await deepgramWait { await socket.sent.count == 1 }
    #expect(await socket.sent.count == 1)
    await socket.unblock(); try await deepgramWait { await socket.sent.count == 3 }
    result.cancel(); try await deepgramWait { await socket.closes == 1 }

    let live = AIStreamingAudioInput.makeStream(); let keepSocket = DeepgramTestSocket()
    let http = AIProviderHTTPClient(providerID: "deepgram", headers: ["authorization": "Token secret"], transport: RecordingTransport(response: jsonResponse("{}")), url: { _, path in URL(string: "https://example.test\(path)")! })
    let model = DeepgramStreamingTranscriptionModel(modelID: "nova-3", http: http, webSocketTransport: DeepgramTestWebSockets(keepSocket), keepAliveNanoseconds: 2_000_000)
    let keep = try await model.stream(.init(audio: live.input, inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 16000)))
    keepSocket.open(); try await deepgramWait { await keepSocket.sent.contains(.text(#"{"type":"KeepAlive"}"#)) }
    keep.cancel(); try await deepgramWait { await keepSocket.closes == 1 }
    let count = await keepSocket.sent.count; try await Task.sleep(nanoseconds: 8_000_000)
    #expect(await keepSocket.sent.count == count); #expect(live.writer.send(Data([0])) == .terminated)
}

@Test(arguments: [JSONValue.null, .object(["endpointing": true]), .object(["channels": 0]), .object(["channels": .number(.infinity)]), .object(["utteranceEndMs": 999]), .object(["interimResults": "true"])])
func weekly20261108DeepgramStreamingValidation(_ options: JSONValue) async throws {
    let sockets = DeepgramTestWebSockets()
    await #expect(throws: AIError.self) { _ = try await deepgramStream(sockets, options: ["streaming": options]) }
    #expect(await sockets.requests.isEmpty)
}

@Test func weekly20261108DeepgramAbortAuthFluxAndSpeechCallbacks() async throws {
    let socket = DeepgramTestSocket(); let sockets = DeepgramTestWebSockets(socket)
    let pair = AIStreamingAudioInput.makeStream(); let abort = AIAbortController(); abort.abort(reason: "stop")
    await #expect(throws: AIAbortError.self) { _ = try await deepgramStream(sockets, audio: pair.input, abort: abort.signal) }
    #expect(await sockets.requests.isEmpty); #expect(pair.writer.send(Data([1])) == .terminated)
    let live = AIStreamingAudioInput.makeStream(); let active = AIAbortController()
    let result = try await deepgramStream(sockets, audio: live.input, abort: active.signal)
    let collected = Task { try await deepgramParts(result) }; active.abort(reason: "stop")
    await #expect(throws: AIAbortError.self) { _ = try await collected.value }; try await deepgramWait { await socket.closes == 1 }
    for model in ["flux-general-en", "nova-3"] {
        let invalid = try DeepgramProvider(configuration: .init(apiKey: "secret", headers: ["Authorization": "Basic secret"], webSocketTransport: sockets))
        await #expect(throws: AIError.self) { _ = try await invalid.streamingTranscriptionModel(model).stream(.init(audio: .chunks([]), inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 16000))) }
    }
    let http = RecordingTransport(response: AIHTTPResponse(statusCode: 200, headers: [:], body: Data([1])))
    let provider = try DeepgramProvider(configuration: .init(apiKey: "secret", transport: http))
    await #expect(throws: AIError.self) { _ = try await provider.speechModel("aura-asteria-en").speak(.init(text: "Hi", providerOptions: ["deepgram": .object(["callback": "https://callback.test"])])) }
    #expect(await http.requests().isEmpty)
    let speech = try await provider.speechModel("aura-asteria-en").speak(.init(text: "Hi", providerOptions: ["deepgram": .object(["callbackMethod": "POST"])]))
    #expect(speech.warnings.contains { $0.feature == "providerOptions.deepgram.callbackMethod" })
    #expect(!(await http.requests().last!.url.absoluteString).contains("callback"))
}

@Test func weekly20261108DeepgramOptionalTimingAndMissingAlternatives() async throws {
    let socket = DeepgramTestSocket(); let input = AIStreamingAudioInput.makeStream()
    let result = try await deepgramStream(DeepgramTestWebSockets(socket), audio: input.input)
    let collected = Task { try await deepgramParts(result) }; socket.open()
    socket.message(#"{"type":"Results","channel":{"alternatives":[{"transcript":"partial"}]}}"#)
    socket.message(#"{"type":"Metadata","duration":1}"#) // metadata while live must not finish the stream
    input.writer.finish(); try await deepgramWait { await socket.sent.contains(.text(#"{"type":"CloseStream"}"#)) }
    socket.continuation.yield(.closed(.init(code: 1000)))
    let parts = try await collected.value
    #expect(parts.contains { if case let .transcriptPartial(_, "partial", _, duration, channel, _) = $0 { duration == nil && channel == nil } else { false } })
    guard case let .finish(finish) = parts.last else { Issue.record("Expected finish"); return }
    #expect(finish.usage == ["seconds": 1])
    let missing = DeepgramTestSocket(); let failed = try await deepgramStream(DeepgramTestWebSockets(missing))
    let failing = Task { try await deepgramParts(failed) }; missing.open(); missing.message(#"{"type":"Results","channel":{"alternatives":[]}}"#)
    await #expect(throws: AIStreamingTranscriptionError.self) { _ = try await failing.value }
}

@Test func weekly20261108DeepgramCancelReleasesBlockedSendAndConnectionFailureInput() async throws {
    let socket = DeepgramTestSocket(); await socket.block()
    let pair = AIStreamingAudioInput.makeStream()
    let result = try await deepgramStream(DeepgramTestWebSockets(socket), audio: pair.input)
    socket.open(); pair.writer.send(Data([1])); try await deepgramWait { await socket.sent.count == 1 }
    result.cancel(); try await deepgramWait { await socket.closes == 1 }
    #expect(await socket.blocked == nil); #expect(pair.writer.send(Data([2])) == .terminated)
    struct Failing: AIDuplexWebSocketTransport {
        func connect(_ request: AIDuplexWebSocketRequest) async throws -> any AIDuplexWebSocketConnection { throw AIError.invalidResponse(provider: "socket", message: "connect failed") }
    }
    let input = AIStreamingAudioInput.makeStream()
    let provider = try DeepgramProvider(configuration: .init(apiKey: "key", webSocketTransport: Failing()))
    await #expect(throws: AIError.self) { _ = try await provider.streamingTranscriptionModel("nova-3").stream(.init(audio: input.input, inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 16000))) }
    #expect(input.writer.send(Data([0])) == .terminated)
}

@Test func weekly20261108DeepgramBatchStreamingWarningAndConnectionCredentials() async throws {
    let transport = RecordingTransport(response: jsonResponse(#"{"results":{"channels":[{"alternatives":[{"transcript":"Hi"}]}]}}"#))
    let batch = try DeepgramProvider(configuration: .init(apiKey: "key", transport: transport))
    let value = try await batch.transcriptionModel("nova-3").transcribe(.init(audio: Data([0]), providerOptions: ["deepgram": .object(["streaming": .object(["interimResults": true])])]))
    #expect(value.warnings.count == 1); #expect(value.warnings[0].feature == "providerOptions.deepgram.streaming")
    #expect(!(await transport.requests())[0].url.absoluteString.contains("interim"))
    actor Keys { var value = 0; func next() -> String { value += 1; return "key-\(value)" } }
    let keys = Keys(); let sockets = DeepgramTestWebSockets()
    let provider = try DeepgramProvider(configuration: .init(apiKeyProvider: { await keys.next() }, webSocketTransport: sockets))
    for _ in 0..<2 {
        let result = try await provider.streamingTranscriptionModel("nova-3").stream(.init(audio: .chunks([]), inputAudioFormat: .init(mediaType: "audio/pcma", sampleRate: 8000)))
        result.cancel()
    }
    #expect(await sockets.requests.map(\.protocols) == [["token", "key-1"], ["token", "key-2"]])
    #expect(await sockets.requests.first?.url.absoluteString.contains("encoding=alaw") == true)
}
