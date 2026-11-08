@testable import SwiftAIMistral
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Foundation
import Testing

private actor MistralTestSocket: AIDuplexWebSocketConnection {
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
private actor MistralTestWebSockets: AIDuplexWebSocketTransport {
    let socket: MistralTestSocket
    var requests: [AIDuplexWebSocketRequest] = []
    init(_ socket: MistralTestSocket = .init()) { self.socket = socket }
    func connect(_ request: AIDuplexWebSocketRequest) async throws -> any AIDuplexWebSocketConnection { requests.append(request); return socket }
}
private func mistralWait(_ predicate: () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while !(await predicate()) { guard ContinuousClock.now < deadline else { throw AIError.timeout(durationNanoseconds: 3_000_000_000) }; try await Task.sleep(nanoseconds: 1_000_000) }
}
private func mistralParts(_ result: StreamingTranscriptionResult) async throws -> [StreamingTranscriptionPart] { var parts: [StreamingTranscriptionPart] = []; for try await part in result.stream { parts.append(part) }; return parts }
private func mistralStream(_ sockets: MistralTestWebSockets, options: [String: JSONValue] = [:], audio: AIStreamingAudioInput = .chunks([Data([1, 2]), Data(), Data([3])]), abort: AIAbortSignal? = nil, raw: Bool = false) async throws -> StreamingTranscriptionResult {
    let provider = try MistralProvider(configuration: .init(apiKey: "secret", webSocketTransport: sockets))
    return try await provider.streamingTranscriptionModel("voxtral-mini-transcribe-realtime-3").stream(.init(audio: audio, inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 24000), providerOptions: ["mistral": .object(options)], includeRawChunks: raw, abortSignal: abort))
}
private func mistralStart(_ socket: MistralTestSocket) async throws {
    socket.open(); socket.message(#"{"type":"session.created"}"#)
    try await mistralWait { await socket.sent.count == 1 }
    socket.message(#"{"type":"session.updated"}"#)
}

@Test func weekly20261108MistralStreamingHandshakeFinalsAndUntimedSpeakers() async throws {
    let sockets = MistralTestWebSockets()
    let result = try await mistralStream(sockets, options: ["language": "en", "diarize": true, "contextBias": .array(["AI SDK"]), "targetStreamingDelayMs": 480, "speakerReferences": .object(["Jane": "AQI="])], raw: true)
    #expect(await sockets.socket.sent.isEmpty)
    let collected = Task { try await mistralParts(result) }
    try await mistralStart(sockets.socket)
    try await mistralWait { await sockets.socket.sent.count == 4 }
    let messages = try await sockets.socket.sent.map { value -> JSONValue in guard case let .text(text) = value else { throw AIError.invalidResponse(provider: "test", message: "Expected text") }; return try decodeJSONBody(Data(text.utf8)) }
    #expect(messages[0]["type"] == "session.update"); #expect(messages[0]["session"]?["audio_format"] == .object(["encoding": "pcm_s16le", "sample_rate": 24000]))
    #expect(messages[0]["session"]?["speaker_references"]?["Jane"] == "AQI=")
    #expect(messages[1]["audio"] == "AQI="); #expect(messages[2]["audio"] == "Aw=="); #expect(messages[3]["type"] == "input_audio.end")
    sockets.socket.message(#"{"type":"session.created"}"#); sockets.socket.message(#"{"type":"session.updated"}"#)
    sockets.socket.message(#"{"type":"transcription.text.delta","text":"Hi"}"#)
    sockets.socket.message(#"{"type":"transcription.segment","text":" Hi.","start":null,"end":null,"speaker_id":"Jane"}"#)
    sockets.socket.message(#"{"type":"turn.started","id":"turn-1"}"#)
    sockets.socket.message(#"{"type":"transcription.done","text":" Hi. Hello.","model":"resolved","language":"en","segments":[{"text":" Hi.","start":null,"end":null,"speaker_id":"Jane"},{"text":" Hello.","start":1,"end":2,"speaker_id":"speaker_2"}],"usage":{"prompt_audio_seconds":2,"total_tokens":5}}"#)
    sockets.socket.continuation.yield(.closed(.init(code: 1000))) // the accepted done event wins over the close
    let parts = try await collected.value
    guard case let .finish(finish) = parts.last else { Issue.record("Expected finish"); return }
    #expect(finish.text == " Hi. Hello."); #expect(finish.segments.count == 1)
    #expect(finish.providerMetadata["mistral"]?["segments"]?[0]?["startSecond"] == nil)
    #expect(finish.providerMetadata["mistral"]?["segments"]?[0]?["speakerId"] == "Jane")
    #expect(finish.usage == ["prompt_audio_seconds": 2, "total_tokens": 5])
    #expect(parts.contains { if case let .transcriptFinal(_, _, start, end, _, _) = $0 { start == nil && end == nil } else { false } })
    #expect(parts.contains { if case let .raw(raw) = $0 { raw["type"] == "turn.started" } else { false } })
    try await mistralWait { await sockets.socket.closes == 1 }
    #expect(await sockets.socket.sent.count == 4)
}

@Test func weekly20261108MistralStreamingSplitBackpressureAndOptionsWarnings() async throws {
    let socket = MistralTestSocket(); let sockets = MistralTestWebSockets(socket)
    let result = try await mistralStream(sockets, options: ["returnLanguage": true, "temperature": 0.2, "timestampGranularities": .array(["segment"])], audio: .chunks([Data(repeating: 1, count: 65_537)]))
    var iterator = result.stream.makeAsyncIterator()
    guard case let .streamStart(warnings) = try await iterator.next() else { Issue.record("Expected stream start"); return }
    #expect(warnings.count == 3)
    try await mistralStart(socket); try await mistralWait { await socket.sent.count == 4 }
    let messages = try await socket.sent.map { value -> JSONValue in guard case let .text(text) = value else { throw AIError.invalidResponse(provider: "test", message: "Expected text") }; return try decodeJSONBody(Data(text.utf8)) }
    #expect(messages[0]["session"]?.objectValue?.count == 1)
    #expect(Data(base64Encoded: messages[1]["audio"]!.stringValue!)?.count == 65_536)
    #expect(Data(base64Encoded: messages[2]["audio"]!.stringValue!)?.count == 1)
    result.cancel(); try await mistralWait { await socket.closes == 1 }

    let held = MistralTestSocket(); let pending = AIStreamingAudioInput.makeStream()
    let blocked = try await mistralStream(MistralTestWebSockets(held), audio: pending.input)
    try await mistralStart(held); await held.block(); pending.writer.send(Data([1])); pending.writer.send(Data([2]))
    try await mistralWait { await held.sent.count == 2 }
    #expect(await held.sent.count == 2)
    await held.unblock(); try await mistralWait { await held.sent.count == 3 }
    blocked.cancel(); try await mistralWait { await held.closes == 1 }
    #expect(pending.writer.send(Data([3])) == .terminated)
}

@Test(arguments: ["invalid-json", "invalid-event", "provider", "close", "input", "socket", "abort"])
func weekly20261108MistralStreamingFailureCleanup(_ failure: String) async throws {
    let socket = MistralTestSocket(); let sockets = MistralTestWebSockets(socket); let pair = AIStreamingAudioInput.makeStream(); let abort = AIAbortController()
    let result = try await mistralStream(sockets, audio: pair.input, abort: abort.signal)
    let collected = Task { try await mistralParts(result) }; try await mistralStart(socket)
    switch failure {
    case "invalid-json": socket.message("{")
    case "invalid-event": socket.message(#"{"type":"transcription.text.delta","text":123}"#)
    case "provider": socket.message(#"{"type":"error","error":{"message":"invalid model"}}"#); socket.continuation.yield(.closed(.init(code: 1000)))
    case "close": socket.continuation.yield(.closed(.init(code: 1008, reason: "denied")))
    case "input": pair.writer.cancel(reason: "mic failed")
    case "abort": abort.abort(reason: "stop")
    default: socket.continuation.finish(throwing: AIError.invalidResponse(provider: "socket", message: "lost"))
    }
    await #expect(throws: (any Error).self) { _ = try await collected.value }
    try await mistralWait { await socket.closes == 1 }; #expect(pair.writer.send(Data([9])) == .terminated)
}

@Test(arguments: [JSONValue.object(["targetStreamingDelayMs": 79]), .object(["targetStreamingDelayMs": 1201]), .object(["targetStreamingDelayMs": 2399]), .object(["targetStreamingDelayMs": 480.5]), .object(["speakerReferences": .object(["Jane": ""])]), .object(["turnDetection": .object(["endThreshold": 1.1])]), .object(["turnDetection": .object(["minSilenceMs": -1])]), .object(["turnDetection": .object(["minSilenceMs": .number(.infinity)])])])
func weekly20261108MistralStreamingRejectsInvalidOptions(_ options: JSONValue) async throws {
    let sockets = MistralTestWebSockets()
    await #expect(throws: AIError.self) { _ = try await mistralStream(sockets, options: options.objectValue!) }
    #expect(await sockets.requests.isEmpty)
}

@Test func weekly20261108MistralStreamingDynamicCredentialsURLAndPreAbort() async throws {
    actor Keys { var value = 0; func next() -> String { value += 1; return "key-\(value)" } }
    let keys = Keys(); let sockets = MistralTestWebSockets()
    let provider = try MistralProvider(configuration: .init(baseURL: "http://proxy.test/custom", headers: ["X-Provider": "yes"], apiKeyProvider: { await keys.next() }, webSocketTransport: sockets))
    for _ in 0..<2 {
        let result = try await provider.streamingTranscriptionModel("future/model").stream(.init(audio: .chunks([]), inputAudioFormat: .init(mediaType: "audio/pcm"), headers: ["X-Override": "new"]))
        result.cancel()
    }
    let requests = await sockets.requests
    #expect(requests.map { $0.headers["authorization"] } == ["Bearer key-1", "Bearer key-2"])
    #expect(requests[0].url.absoluteString.contains("model=future%2Fmodel"))
    #expect(requests[0].url.scheme == "ws"); #expect(requests[0].url.path == "/custom/audio/transcriptions/realtime")
    #expect(URLComponents(url: requests[0].url, resolvingAgainstBaseURL: false)!.queryItems?.contains(.init(name: "model", value: "future/model")) == true)
    let abort = AIAbortController(); abort.abort(reason: "stop"); let pair = AIStreamingAudioInput.makeStream()
    await #expect(throws: AIAbortError.self) { _ = try await mistralStream(sockets, audio: pair.input, abort: abort.signal) }
    #expect(await sockets.requests.count == 2); #expect(pair.writer.send(Data([1])) == .terminated)
}

@Test func weekly20261108MistralOfflineWarningsToolSerializationSpecificChoiceAndReasoning() async throws {
    #expect(mistralSerializeToolArguments(#" {"city":"Tokyo"} "#) == #" {"city":"Tokyo"} "#)
    #expect(mistralSerializeToolArguments("plain text") == #""plain text""#)
    let tools = mistralTools(from: ["a": .object(["type": "object"]), "b": .object(["type": "object"])])
    #expect(tools.tools.count == 2)
    #expect(mistralToolChoice(from: .object(["type": "tool", "toolName": "a"])) == .object(["type": "function", "function": .object(["name": "a"])]))
    for model in ["mistral-large-4", "mistral-large-4-0"] {
        var warnings: [AIWarning] = []
        #expect(mistralReasoningEffort("medium", modelID: model, warnings: &warnings) == "medium"); #expect(warnings.isEmpty)
        #expect(mistralReasoningEffort("none", modelID: model, warnings: &warnings) == "low"); #expect(warnings.count == 1)
    }
    let transport = RecordingTransport(response: jsonResponse(#"{"model":"voxtral-mini-transcribe-3","text":"Hi","usage":{"prompt_audio_seconds":2}}"#))
    let provider = try MistralProvider(configuration: .init(apiKey: "key", transport: transport))
    let transcription = try await provider.transcriptionModel("voxtral-mini-transcribe-3").transcribe(.init(audio: Data([1]), providerOptions: ["mistral": .object(["targetStreamingDelayMs": 2400, "speakerReferences": .object(["Jane": "AQI="]), "turnDetection": .object([:])])], timestampGranularities: [.segment]))
    #expect(transcription.warnings.count == 3)
    let body = String(decoding: (await transport.requests())[0].body!, as: UTF8.self)
    #expect(body.contains("timestamp_granularities")); #expect(!body.contains("target_streaming_delay")); #expect(!body.contains("speaker_references")); #expect(!body.contains("turn_detection"))
}

@Test func weekly20261108MistralVoiceSessionServerControlAndConfig() async throws {
    let transport = RecordingTransport(responses: [jsonResponse(#"{"id":"session-1","participant_token":"browser-token","server_url":"wss://voice.test","unused":true}"#), AIHTTPResponse(statusCode: 204, headers: [:], body: Data())])
    let provider = try MistralProvider(configuration: .init(apiKey: "key", baseURL: "https://proxy.test/v1/", headers: ["X-Custom": "yes"], transport: transport))
    let config = AIRealtimeSessionConfiguration(instructions: "Be concise", voice: "voice-1", outputModalities: [.audio, .text], inputAudioTranscription: .init(model: "native-stt", language: "en"), outputAudioTranscription: .init(), tools: [.init(name: "weather", parameters: .object(["type": "object"]))], providerOptions: ["mistral": .object([
        "stt": .object(["model": "overridden", "language": "fr", "contextBias": .array(["SDK"]), "targetStreamingDelayMs": 240, "turnDetection": .object(["endThreshold": 0.33, "minSilenceMs": 500])]),
        "tts": .object(["model": "tts-model", "voiceId": "overridden", "phonemeHints": .object(["SDK": .array(["s"])])]),
        "turn": .object(["allowInterruptions": false, "inactivity": .object(["timeoutMs": 10000, "maxReminders": 2, "messages": .array(["Hello?"])])]),
        "welcomeMessage": "Hi", "agentId": "saved", "agentVersion": 2
    ])])
    let session = try await provider.voiceSessions.create(modelID: "mistral-small-latest", sessionConfiguration: config)
    #expect(session == .init(id: "session-1", participantToken: "browser-token", serverURL: "wss://voice.test"))
    try await provider.voiceSessions.close(sessionID: "session/1?query")
    let requests = await transport.requests()
    #expect(requests[0].method == "POST"); #expect(requests[1].method == "DELETE")
    #expect(requests[1].url.absoluteString == "https://proxy.test/v1/audio/sessions/session%2F1%3Fquery")
    let body = try decodeJSONBody(requests[0].body!)
    #expect(body["llm"]?["model"] == "mistral-small-latest"); #expect(body["stt"]?["model"] == "native-stt")
    #expect(body["stt"]?["language"] == "en"); #expect(body["stt"]?["turn_detection"]?["end_threshold"] == 0.33)
    #expect(body["tts"]?["voice_id"] == "voice-1"); #expect(body["turn"]?["inactivity"]?["timeout_ms"] == 10000)
    #expect(body["tools"]?[0]?["function"]?["name"] == "weather"); #expect(body["agent_version"] == 2)
    let updated = try provider.voiceSessions.buildSessionConfiguration(.init(instructions: "Updated", tools: [], providerOptions: ["mistral": .object(["turn": .object(["allowInterruptions": true])])]), update: true)
    #expect(updated == .object(["instructions": "Updated", "tools": .array([JSONValue]()), "turn": .object(["allow_interruptions": true])]))
}

@Test func weekly20261108MistralVoiceValidatesAndMapsEventsWithoutMediaClaims() async throws {
    let transport = RecordingTransport(response: jsonResponse("{}")); let provider = try MistralProvider(configuration: .init(apiKey: "key", transport: transport))
    for options: [String: JSONValue] in [["agentVersion": 2], ["agentId": "a", "agentVersion": .number(.infinity)], ["tts": .object(["expressiveness": 2])], ["stt": .object(["targetStreamingDelayMs": 2400])], ["stt": .object(["turnDetection": .object(["endThreshold": 2])])]] {
        #expect(throws: AIError.self) { _ = try provider.voiceSessions.buildSessionConfiguration(.init(providerOptions: ["mistral": .object(options)])) }
    }
    #expect(throws: AIError.self) { _ = try provider.voiceSessions.buildSessionConfiguration(.init(voice: "new"), update: true) }
    #expect(throws: AIError.self) { _ = try provider.voiceSessions.buildSessionConfiguration(.init(inputAudioFormat: .init(type: "audio/pcm"))) }
    for id in ["", ".", ".."] { await #expect(throws: AIError.self) { try await provider.voiceSessions.close(sessionID: id) } }
    #expect(await transport.requests().isEmpty)
    await #expect(throws: AIError.self) { _ = try await provider.voiceSessions.create(modelID: "model") }
    #expect(try MistralVoiceSessions.parseServerEvent(.object(["type": "transcription.segment", "id": "x", "role": "assistant", "content": "draft", "final": false])).isEmpty)
    let raw: JSONValue = .object(["type": "transcription.segment", "id": "x", "role": "assistant", "content": "Final", "final": true])
    let events = try MistralVoiceSessions.parseServerEvent(raw)
    #expect(events.count == 4); #expect(events.last == .responseDone(responseID: "x", status: "completed", raw: raw))
    let future: JSONValue = .object(["type": "future", "field": 42])
    #expect(try MistralVoiceSessions.parseServerEvent(future) == [.custom(rawType: "future", raw: future)])
}

@Test func weekly20261108MistralVoiceErrorsCredentialRotationAndFinalUserEvent() async throws {
    actor Keys { var value = 0; func next() -> String { value += 1; return "key-\(value)" } }
    let keys = Keys()
    let transport = RecordingTransport(responses: [jsonResponse(#"{"id":"s","participant_token":"t","server_url":"wss://voice.test"}"#), AIHTTPResponse(statusCode: 204, headers: [:], body: Data()), AIHTTPResponse(statusCode: 401, headers: [:], body: Data(#"{"message":"Invalid key"}"#.utf8))])
    let provider = try MistralProvider(configuration: .init(transport: transport, apiKeyProvider: { await keys.next() }))
    _ = try await provider.voiceSessions.create(modelID: "model")
    try await provider.voiceSessions.close(sessionID: "s")
    await #expect(throws: AIError.self) { try await provider.voiceSessions.close(sessionID: "s") }
    #expect(await transport.requests().map { $0.headers["authorization"] } == ["Bearer key-1", "Bearer key-2", "Bearer key-3"])
    let raw: JSONValue = .object(["type": "transcription.segment", "id": "u", "role": "user", "content": "Hi", "final": true])
    #expect(try MistralVoiceSessions.parseServerEvent(raw) == [.inputTranscriptionCompleted(itemID: "u", transcript: "Hi", raw: raw)])
}

@Test func weekly20261108MistralMediumEffortWireAndRawToolArguments() async throws {
    let transport = RecordingTransport(response: jsonResponse(#"{"id":"c","model":"mistral-large-4","choices":[{"index":0,"message":{"role":"assistant","content":"ok"},"finish_reason":"stop"}]}"#))
    let provider = try MistralProvider(configuration: .init(apiKey: "key", transport: transport))
    let result = try await provider.languageModel("mistral-large-4").generate(.init(messages: [AIMessage(role: .assistant, content: [.toolCall(.init(id: "a", name: "tool", arguments: "not json"))]), .user("Continue")], providerOptions: ["mistral": .object(["reasoningEffort": "medium"])]))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["reasoning_effort"] == "medium"); #expect(result.warnings.isEmpty)
    #expect(body["messages"]?[0]?["tool_calls"]?[0]?["function"]?["arguments"] == .string(#""not json""#))
}

@Test func weekly20261108MistralCancellationReleasesBlockedSendAndConnectFailure() async throws {
    let socket = MistralTestSocket(); let input = AIStreamingAudioInput.makeStream()
    let result = try await mistralStream(MistralTestWebSockets(socket), audio: input.input)
    try await mistralStart(socket); await socket.block(); input.writer.send(Data([1]))
    try await mistralWait { await socket.sent.count == 2 }
    result.cancel(); try await mistralWait { await socket.closes == 1 }
    #expect(await socket.blocked == nil); #expect(input.writer.send(Data([2])) == .terminated)
    struct Failing: AIDuplexWebSocketTransport {
        func connect(_ request: AIDuplexWebSocketRequest) async throws -> any AIDuplexWebSocketConnection { throw AIError.invalidResponse(provider: "socket", message: "connect failed") }
    }
    let pending = AIStreamingAudioInput.makeStream()
    let provider = try MistralProvider(configuration: .init(apiKey: "key", webSocketTransport: Failing()))
    await #expect(throws: AIError.self) { _ = try await provider.streamingTranscriptionModel("future").stream(.init(audio: pending.input, inputAudioFormat: .init(mediaType: "audio/pcm"))) }
    #expect(pending.writer.send(Data([0])) == .terminated)
}
