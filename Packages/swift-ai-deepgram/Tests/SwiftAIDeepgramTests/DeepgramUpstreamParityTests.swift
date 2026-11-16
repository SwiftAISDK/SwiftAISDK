@testable import SwiftAIDeepgram
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translated from @ai-sdk/deepgram deepgram-transcription-model.test.ts,
// deepgram-speech-model.test.ts, deepgram-error.test.ts and
// deepgram-streaming-transcription.test.ts at the pinned release ref.

private let galileoTranscript = "galileo was an american robotic space program that studied the planet jupiter and its moons as well as several other solar system bodies named after the italian astronomer galileo galilei the galileo spacecraft consisted of an orbiter and an atmospheric entry probe it was delivered into earth orbit on october eighteen nineteen eighty nine by space shuttle atlantis on the sts-thirty four mission and arrived at jupiter on december seven nineteen ninety five after gravity assist flybys of venus and earth and became the first spacecraft to orbit jupiter"

/// Compact form of `__fixtures__/deepgram-transcription.json` (same transcript,
/// duration, detected language and the first two word timings).
private let deepgramTranscriptionFixture = """
{"metadata":{"transaction_key":"deprecated","request_id":"e9ad6d71-4f48-4f6e-8b19-035dbcdda8cb","created":"2026-02-12T22:42:32.266Z","duration":36.744,"channels":1,"models":["2187e11a-3532-4498-b076-81fa530bdd49"]},"results":{"channels":[{"alternatives":[{"transcript":"\(galileoTranscript)","confidence":0.99902344,"words":[{"word":"galileo","start":0.16,"end":0.79999995,"confidence":0.99641925},{"word":"was","start":0.79999995,"end":0.96,"confidence":0.99902344}]}],"detected_language":"en","language_confidence":0.99352765}]}}
"""

private func deepgramParityProvider(_ transport: RecordingTransport, headers: [String: String] = [:]) throws -> DeepgramProvider {
    try AIProviders.deepgram(configuration: DeepgramProviderSettings(apiKey: "test-api-key", headers: headers, transport: transport))
}

// MARK: - Batch transcription

@Test func deepgramParityTranscriptionExtractsFixtureTextUsageLanguageAndResponse() async throws {
    let transport = RecordingTransport(response: jsonResponse(deepgramTranscriptionFixture, headers: ["x-request-id": "test-request-id", "x-ratelimit-remaining": "123"]))
    let model = try deepgramParityProvider(transport).transcriptionModel("nova-3")

    let result = try await model.transcribe(AudioTranscriptionRequest(
        audio: Data("audio".utf8),
        mimeType: "audio/wav",
        providerOptions: ["deepgram": ["detectLanguage": true]]
    ))

    #expect(result.text == galileoTranscript)
    #expect(result.usage == ["seconds": 36.744])
    #expect(result.durationInSeconds == 36.744)
    #expect(result.language == "en")
    #expect(result.segments.first == TranscriptionSegment(text: "galileo", startSecond: 0.16, endSecond: 0.79999995))
    #expect(result.responseMetadata.modelID == "nova-3")
    #expect(result.responseMetadata.headers["x-request-id"] == "test-request-id")
    #expect(result.responseMetadata.headers["x-ratelimit-remaining"] == "123")
    #expect(result.responseMetadata.body?["metadata"]?["duration"] == 36.744)
    let request = try #require(await transport.requests().first)
    #expect(request.url.absoluteString.contains("detect_language=true"))
}

@Test func deepgramParityTranscriptionPassesHeadersAndRawAudio() async throws {
    let transport = RecordingTransport(response: jsonResponse(deepgramTranscriptionFixture))
    let model = try deepgramParityProvider(transport, headers: ["Custom-Provider-Header": "provider-header-value"]).transcriptionModel("nova-3")

    _ = try await model.transcribe(AudioTranscriptionRequest(
        audio: Data([1, 2, 3]),
        mimeType: "audio/wav",
        headers: ["Custom-Request-Header": "request-header-value"]
    ))

    let request = try #require(await transport.requests().first)
    let headers = normalizeHeaders(request.headers)
    #expect(headers["authorization"] == "Token test-api-key")
    #expect(headers["content-type"] == "audio/wav")
    #expect(headers["custom-provider-header"] == "provider-header-value")
    #expect(headers["custom-request-header"] == "request-header-value")
    #expect(headers["user-agent"]?.contains("ai-sdk-deepgram/") == true)
    #expect(request.body == Data([1, 2, 3]))
    #expect(request.url.absoluteString == "https://api.deepgram.com/v1/listen?model=nova-3")
}

@Test func deepgramParityTranscriptionPassesKeytermParagraphsIntentsSentimentRedactAndReplace() async throws {
    let transport = RecordingTransport(response: jsonResponse(deepgramTranscriptionFixture))
    let model = try deepgramParityProvider(transport).transcriptionModel("nova-3")

    _ = try await model.transcribe(AudioTranscriptionRequest(
        audio: Data("audio".utf8),
        mimeType: "audio/wav",
        providerOptions: ["deepgram": [
            "keyterm": "galileo",
            "paragraphs": true,
            "intents": true,
            "sentiment": true,
            "redact": "numbers",
            "replace": "[redacted]"
        ]]
    ))

    let request = try #require(await transport.requests().first)
    let items = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
    #expect(value("keyterm") == "galileo")
    #expect(value("paragraphs") == "true")
    #expect(value("intents") == "true")
    #expect(value("sentiment") == "true")
    #expect(value("redact") == "numbers")
    #expect(value("replace") == "[redacted]")
    #expect(value("diarize") == nil)
}

@Test func deepgramParityTranscriptionReturnsInlineAndMissingDetectedLanguage() async throws {
    let detected = RecordingTransport(response: jsonResponse(#"{"metadata":{"duration":1.0},"results":{"channels":[{"detected_language":"sv","alternatives":[{"transcript":"hej","words":[]}]}]}}"#))
    let swedish = try await deepgramParityProvider(detected).transcriptionModel("nova-3").transcribe(AudioTranscriptionRequest(
        audio: Data("audio".utf8),
        providerOptions: ["deepgram": ["detectLanguage": true]]
    ))
    #expect(swedish.language == "sv")

    let missing = RecordingTransport(response: jsonResponse(#"{"metadata":{"duration":1.0},"results":{"channels":[{"alternatives":[{"transcript":"hello","words":[]}]}]}}"#))
    let english = try await deepgramParityProvider(missing).transcriptionModel("nova-3").transcribe(AudioTranscriptionRequest(audio: Data("audio".utf8)))
    #expect(english.language == nil)
}

@Test func deepgramParityTranscriptionOmitsDurationAndUsageWithoutMetadata() async throws {
    // Upstream reads duration only from `metadata.duration`; word timings are
    // not used to synthesize a duration.
    let transport = RecordingTransport(response: jsonResponse(#"{"results":{"channels":[{"alternatives":[{"transcript":"hi","words":[{"word":"hi","start":0,"end":0.5}]}]}]}}"#))
    let result = try await deepgramParityProvider(transport).transcriptionModel("nova-3").transcribe(AudioTranscriptionRequest(
        audio: Data("audio".utf8),
        providerOptions: ["deepgram": ["streaming": ["interimResults": true]]]
    ))
    #expect(result.durationInSeconds == nil)
    #expect(result.usage == nil)
    #expect(result.warnings == [AIWarning(
        type: "unsupported",
        feature: "providerOptions.deepgram.streaming",
        message: "Deepgram batch transcription does not support streaming options."
    )])
}

@Test(arguments: [
    (#"{"err_code":"INVALID_QUERY_PARAMETER","err_msg":"Invalid 'model' value of 'aura-2-not-a-real-voice-en'.","request_id":"01a00450-5a52-70f0-9253-2fc492123595"}"#, "Invalid 'model' value of 'aura-2-not-a-real-voice-en'."),
    (#"{"err_code":"INVALID_AUTH","err_msg":"Invalid credentials."}"#, "Invalid credentials.")
])
func deepgramParityErrorSchemaSurfacesErrMsg(_ body: String, _ message: String) async throws {
    let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 400, headers: ["content-type": "application/json"], body: Data(body.utf8)))
    let model = try deepgramParityProvider(transport).speechModel("aura-2")
    await #expect(throws: AIError.apiCall(provider: "deepgram.speech", statusCode: 400, body: message, headers: ["content-type": "application/json"])) {
        _ = try await model.speak(SpeechRequest(text: "Hello, world!", voice: "not-a-real-voice"))
    }
}

// MARK: - Speech

private func speechTransport(headers: [String: String] = [:]) -> RecordingTransport {
    RecordingTransport(response: AIHTTPResponse(statusCode: 200, headers: ["content-type": "audio/mp3"].merging(headers) { _, new in new }, body: Data(count: 100)))
}

@Test func deepgramParitySpeechRejectsCallbackBeforeAnyRequest() async throws {
    for options: [String: JSONValue] in [
        ["callback": "https://example.com/callback"],
        ["callback": "https://example.com/callback", "callbackMethod": "PUT"]
    ] {
        let transport = speechTransport()
        let model = try deepgramParityProvider(transport).speechModel("aura-2-helena-en")
        do {
            _ = try await model.speak(SpeechRequest(text: "Hello, welcome to Deepgram!", voice: "helena", providerOptions: ["deepgram": .object(options)]))
            Issue.record("Expected callback rejection")
        } catch let AIError.invalidArgument(argument, message) {
            #expect(argument == "providerOptions.deepgram.callback")
            #expect(message.contains("returns a JSON acknowledgement instead of audio"))
        }
        #expect(await transport.requests().isEmpty)
    }
}

@Test func deepgramParitySpeechWarnsAboutCallbackMethodWithoutCallback() async throws {
    let transport = speechTransport()
    let result = try await deepgramParityProvider(transport).speechModel("aura-2").speak(SpeechRequest(
        text: "Hello, welcome to Deepgram!",
        voice: "helena",
        providerOptions: ["deepgram": ["callbackMethod": "POST"]]
    ))
    #expect(result.warnings == [AIWarning(
        type: "unsupported",
        feature: "providerOptions.deepgram.callbackMethod",
        message: "providerOptions.deepgram.callbackMethod is only used together with `callback`, which is not supported by the AI SDK. Callback method was ignored."
    )])
    let request = try #require(await transport.requests().first)
    #expect(!request.url.absoluteString.contains("callback_method"))
}

@Test func deepgramParitySpeechContainerWarningKeepsCallerSpelling() async throws {
    let transport = speechTransport()
    let result = try await deepgramParityProvider(transport).speechModel("aura-2").speak(SpeechRequest(
        text: "Hello",
        voice: "helena",
        providerOptions: ["deepgram": ["encoding": "MP3", "container": "WAV"]]
    ))
    #expect(result.warnings == [AIWarning(
        type: "unsupported",
        feature: "providerOptions",
        message: "Encoding \"mp3\" does not support container parameter. Container \"WAV\" was ignored."
    )])
    let request = try #require(await transport.requests().first)
    #expect(request.url.absoluteString == "https://api.deepgram.com/v1/speak?encoding=mp3&model=aura-2-helena-en")
}

@Test func deepgramParitySpeechIgnoresEmptyEncodingTagAndInstructionsLikeUpstreamTruthiness() async throws {
    let transport = speechTransport()
    let result = try await deepgramParityProvider(transport).speechModel("aura-2").speak(SpeechRequest(
        text: "Hello",
        voice: "helena",
        instructions: "",
        providerOptions: ["deepgram": ["encoding": "", "tag": ""]]
    ))
    #expect(result.warnings.isEmpty)
    let request = try #require(await transport.requests().first)
    #expect(request.url.absoluteString == "https://api.deepgram.com/v1/speak?encoding=mp3&model=aura-2-helena-en")
}

@Test func deepgramParitySpeechUsesJavaScriptNumberSemanticsForRates() async throws {
    let transport = speechTransport()
    let result = try await deepgramParityProvider(transport).speechModel("aura-2").speak(SpeechRequest(
        text: "Hello",
        voice: "helena",
        format: "pcm",
        providerOptions: ["deepgram": ["encoding": "opus", "bitRate": "high"]]
    ))
    // `Number("high")` is NaN, which passes the opus range check upstream.
    #expect(result.warnings.isEmpty)
    let first = try #require(await transport.requests().first)
    #expect(first.url.absoluteString == "https://api.deepgram.com/v1/speak?bit_rate=high&container=ogg&encoding=opus&model=aura-2-helena-en")

    let second = speechTransport()
    let warned = try await deepgramParityProvider(second).speechModel("aura-2").speak(SpeechRequest(
        text: "Hello",
        voice: "helena",
        format: "wav",
        providerOptions: ["deepgram": ["sampleRate": 22050.5]]
    ))
    #expect(warned.warnings == [AIWarning(
        type: "unsupported",
        feature: "providerOptions",
        message: "Encoding \"linear16\" only supports sample rates: 8000, 16000, 24000, 32000, 48000. Sample rate 22050.5 was ignored."
    )])
}

@Test func deepgramParitySpeechReturnsEmptyMetadataRequestBodyAndInstructionsWarning() async throws {
    let transport = speechTransport(headers: ["x-request-id": "test-request-id"])
    let result = try await deepgramParityProvider(transport).speechModel("aura-2").speak(SpeechRequest(
        text: "Hello, welcome to Deepgram!",
        voice: "helena",
        instructions: "Speak slowly"
    ))
    #expect(result.audio == Data(count: 100))
    #expect(result.providerMetadata == ["deepgram": [:]])
    #expect(result.usage == nil)
    #expect(result.requestMetadata.body == ["text": "Hello, welcome to Deepgram!"])
    #expect(result.responseMetadata.modelID == "aura-2")
    #expect(result.responseMetadata.headers["x-request-id"] == "test-request-id")
    #expect(result.warnings == [AIWarning(
        type: "unsupported",
        feature: "instructions",
        message: "Deepgram TTS REST API does not support instructions. Instructions parameter was ignored."
    )])
}

// MARK: - Streaming transcription

private actor ParitySocket: AIDuplexWebSocketConnection {
    nonisolated let events: AsyncThrowingStream<AIDuplexWebSocketEvent, Error>
    nonisolated let continuation: AsyncThrowingStream<AIDuplexWebSocketEvent, Error>.Continuation
    var sent: [AIDuplexWebSocketMessage] = []
    var closes = 0
    init() { let pair = AsyncThrowingStream<AIDuplexWebSocketEvent, Error>.makeStream(); events = pair.stream; continuation = pair.continuation }
    func send(_ message: AIDuplexWebSocketMessage) async throws { sent.append(message) }
    func close(code: Int, reason: Data?) async { closes += 1 }
    nonisolated func open() { continuation.yield(.opened(protocol: nil)) }
    nonisolated func message(_ raw: String) { continuation.yield(.message(.text(raw))) }
    nonisolated func serverClose(_ code: Int = 1000, reason: String? = nil) { continuation.yield(.closed(.init(code: code, reason: reason))) }
}

private actor ParitySockets: AIDuplexWebSocketTransport {
    let socket = ParitySocket()
    var requests: [AIDuplexWebSocketRequest] = []
    func connect(_ request: AIDuplexWebSocketRequest) async throws -> any AIDuplexWebSocketConnection { requests.append(request); return socket }
}

private func parityWait(_ predicate: () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while !(await predicate()) {
        guard ContinuousClock.now < deadline else { throw AIError.timeout(durationNanoseconds: 3_000_000_000) }
        try await Task.sleep(nanoseconds: 1_000_000)
    }
}

private func parityStream(
    _ sockets: ParitySockets,
    options: [String: JSONValue]? = nil,
    format: AIStreamingAudioFormat = .init(mediaType: "audio/pcm", sampleRate: 16000),
    headers: [String: String] = [:],
    raw: Bool = false,
    model: String = "nova-3"
) async throws -> StreamingTranscriptionResult {
    let provider = try DeepgramProvider(configuration: .init(apiKey: "test-key", webSocketTransport: sockets))
    return try await provider.streamingTranscriptionModel(model).stream(.init(
        audio: .chunks([Data([1, 2]), Data([3, 4]), Data()]),
        inputAudioFormat: format,
        providerOptions: options.map { ["deepgram": .object($0)] } ?? [:],
        headers: headers,
        includeRawChunks: raw
    ))
}

private func parityCollect(_ result: StreamingTranscriptionResult) -> Task<[StreamingTranscriptionPart], Error> {
    Task { var parts: [StreamingTranscriptionPart] = []; for try await part in result.stream { parts.append(part) }; return parts }
}

private func deepgramResults(_ text: String, isFinal: Bool = true, channel: Int = 0) -> String {
    #"{"type":"Results","is_final":\#(isFinal),"speech_final":\#(isFinal),"start":0,"duration":1.5,"channel_index":[\#(channel),2],"channel":{"alternatives":[{"transcript":"\#(text)","languages":["en"],"words":[{"word":"hello","punctuated_word":"Hello!","start":0.2,"end":0.8}]}]}}"#
}

@Test func deepgramParityStreamingMapsRevisableAndFinalTranscripts() async throws {
    let sockets = ParitySockets()
    let result = try await parityStream(sockets, raw: true)
    let collected = parityCollect(result)
    sockets.socket.open()
    try await parityWait { await sockets.socket.sent.contains(.text(#"{"type":"CloseStream"}"#)) }
    sockets.socket.message(deepgramResults("Hel", isFinal: false))
    sockets.socket.message(deepgramResults("Hello!", isFinal: true, channel: 1))
    sockets.socket.message(#"{"type":"Metadata","duration":2.5,"request_id":"request-id"}"#)
    let parts = try await collected.value

    #expect(await sockets.socket.sent == [.binary(Data([1, 2])), .binary(Data([3, 4])), .text(#"{"type":"CloseStream"}"#)])
    #expect(parts.contains(.transcriptPartial(id: nil, text: "Hel", startSecond: 0, durationInSeconds: 1.5, channelIndex: 0, providerMetadata: ["deepgram": ["speechFinal": false]])))
    #expect(parts.contains(.transcriptFinal(id: nil, text: "Hello!", startSecond: 0, endSecond: 1.5, channelIndex: 1, providerMetadata: ["deepgram": ["speechFinal": true]])))
    #expect(parts.contains { if case let .raw(value) = $0 { value["channel_index"] == [1, 2] } else { false } })
    #expect(parts.last == .finish(.init(
        text: "Hello!",
        segments: [TranscriptionSegment(text: "Hello!", startSecond: 0.2, endSecond: 0.8)],
        language: "en",
        durationInSeconds: 2.5,
        usage: ["seconds": 2.5]
    )))
    try await parityWait { await sockets.socket.closes == 1 }
}

@Test func deepgramParityStreamingTreatsNullSpeechFinalAsFalse() async throws {
    let sockets = ParitySockets()
    let result = try await parityStream(sockets)
    let collected = parityCollect(result)
    sockets.socket.open()
    sockets.socket.message(#"{"type":"Results","speech_final":null,"channel":{"alternatives":[{"transcript":"partial"}]}}"#)
    try await parityWait { await sockets.socket.sent.count == 3 }
    sockets.socket.serverClose()
    let parts = try await collected.value
    #expect(parts.contains(.transcriptPartial(id: nil, text: "partial", startSecond: 0, durationInSeconds: nil, channelIndex: nil, providerMetadata: ["deepgram": ["speechFinal": false]])), "\(parts)")
}

@Test func deepgramParityStreamingWarnsAboutBatchOnlyOptionsInSchemaOrder() async throws {
    let sockets = ParitySockets()
    let result = try await parityStream(sockets, options: ["summarize": "v2", "detectLanguage": true, "streaming": ["interimResults": true]])
    let collected = parityCollect(result)
    sockets.socket.open()
    try await parityWait { await sockets.socket.sent.count == 3 }
    sockets.socket.serverClose()
    let parts = try await collected.value
    guard case let .streamStart(warnings) = parts.first else { Issue.record("Expected stream-start"); return }
    #expect(warnings.map(\.feature) == ["providerOptions.deepgram.detectLanguage", "providerOptions.deepgram.summarize"])
    #expect(warnings.allSatisfy { $0.type == "unsupported" && $0.message == "This option is not supported for Deepgram streaming transcription." })
    let request = try #require(await sockets.requests.first)
    let names = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems?.map(\.name) ?? []
    #expect(!names.contains("summarize"))
    #expect(names.contains("interim_results"))
}

@Test func deepgramParityStreamingDoesNotWarnAboutDisabledBatchOptions() async throws {
    let sockets = ParitySockets()
    let result = try await parityStream(sockets, options: ["detectLanguage": false, "summarize": false, "utterances": false])
    let collected = parityCollect(result)
    sockets.socket.open()
    try await parityWait { await sockets.socket.sent.count == 3 }
    sockets.socket.serverClose()
    let parts = try await collected.value
    #expect(parts.first == .streamStart(warnings: []))
    let request = try #require(await sockets.requests.first)
    #expect(!request.url.absoluteString.contains("detect_language"))
}

@Test func deepgramParityStreamingBuildsQueryInSchemaOrder() async throws {
    let sockets = ParitySockets()
    let result = try await parityStream(sockets, options: [
        "language": "fr",
        "redact": ["numbers", "names"],
        "streaming": ["interimResults": true, "endpointing": false, "channels": 2, "multichannel": true, "vadEvents": true, "utteranceEndMs": 1000]
    ])
    result.cancel()
    let request = try #require(await sockets.requests.first)
    #expect(request.url.absoluteString == "wss://api.deepgram.com/v1/listen?model=nova-3&encoding=linear16&sample_rate=16000&language=fr&redact=numbers&redact=names&interim_results=true&endpointing=false&channels=2&multichannel=true&vad_events=true&utterance_end_ms=1000")
    #expect(request.protocols == ["token", "test-key"])
}

@Test(arguments: [
    AIStreamingAudioFormat(mediaType: "audio/mp3", sampleRate: 16000),
    AIStreamingAudioFormat(mediaType: "audio/pcm"),
    AIStreamingAudioFormat(mediaType: "audio/pcm", sampleRate: 0)
])
func deepgramParityStreamingRejectsUnsupportedRawFormats(_ format: AIStreamingAudioFormat) async throws {
    let sockets = ParitySockets()
    await #expect(throws: AIError.invalidArgument(argument: "inputAudioFormat", message: "Deepgram streaming requires audio/pcm (16-bit little-endian), audio/pcmu, or audio/pcma and a positive integer sample rate.")) {
        _ = try await parityStream(sockets, format: format)
    }
    #expect(await sockets.requests.isEmpty)
}

@Test func deepgramParityStreamingAuthenticationSchemes() async throws {
    for scheme in ["Bearer", "bearer"] {
        let sockets = ParitySockets()
        let result = try await parityStream(sockets, headers: ["authorization": "\(scheme) temporary-jwt"])
        result.cancel()
        #expect(await sockets.requests.first?.protocols == ["bearer", "temporary-jwt"])
        #expect(!result.requestMetadata.body.debugDescription.contains("temporary-jwt"))
    }
    let sockets = ParitySockets()
    await #expect(throws: AIError.invalidArgument(argument: "headers", message: "Deepgram streaming authorization must use the Token or Bearer scheme.")) {
        _ = try await parityStream(sockets, headers: ["authorization": "Basic secret"])
    }
    #expect(await sockets.requests.isEmpty)
}

@Test func deepgramParityStreamingRejectsFluxModels() async throws {
    let sockets = ParitySockets()
    do {
        _ = try await parityStream(sockets, model: "flux-general-en")
        Issue.record("Expected Flux rejection")
    } catch {
        #expect(String(describing: error).contains("Flux"))
    }
    #expect(await sockets.requests.isEmpty)
}

@Test func deepgramParityStreamingPreservesCloseCodesAndProviderErrors() async throws {
    let closing = ParitySockets()
    let closed = parityCollect(try await parityStream(closing))
    closing.socket.open()
    closing.socket.serverClose(1008, reason: "DATA-0000")
    do { _ = try await closed.value; Issue.record("Expected close failure") } catch let error as AIStreamingTranscriptionError {
        #expect(error.message == "Deepgram streaming connection closed unexpectedly (1008): DATA-0000")
    }

    let failing = ParitySockets()
    let failed = parityCollect(try await parityStream(failing))
    failing.socket.open()
    failing.socket.message(#"{"type":"Error"}"#)
    do { _ = try await failed.value; Issue.record("Expected provider failure") } catch let error as AIStreamingTranscriptionError {
        #expect(error.message == "Deepgram streaming transcription failed.")
    }

    let missing = ParitySockets()
    let missingResult = parityCollect(try await parityStream(missing))
    missing.socket.open()
    missing.socket.message(#"{"type":"Results","is_final":true}"#)
    do { _ = try await missingResult.value; Issue.record("Expected missing alternative failure") } catch let error as AIStreamingTranscriptionError {
        #expect(error.message == "Deepgram Results event is missing a transcript alternative.")
    }
}
