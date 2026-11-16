@testable import SwiftAICartesia
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translated from @ai-sdk/cartesia cartesia-realtime-model.test.ts and the
// batch cases of cartesia-transcription-model.test.ts at the pinned release ref.

private let cartesiaTranscriptionFixture = """
{"text":"Hello from the Vercel AI SDK.","language":"en","duration":2.479,"words":[{"word":"Hello","start":0.199,"end":0.479},{"word":"from","start":0.5,"end":0.639},{"word":"the","start":0.66,"end":0.759},{"word":"Vercel","start":0.759,"end":1.12},{"word":"AI","start":1.2,"end":1.519},{"word":"SDK.","start":1.58,"end":2.479}]}
"""

// MARK: - Batch transcription

@Test func cartesiaParityBatchTranscriptionParsesFixture() async throws {
    let transport = RecordingTransport(response: jsonResponse(cartesiaTranscriptionFixture))
    let provider = try CartesiaProvider(settings: .init(apiKey: "test-api-key", environment: [:], transport: transport))
    let result = try await provider.transcriptionModel("ink-whisper").transcribe(AudioTranscriptionRequest(audio: Data("audio".utf8), mimeType: "audio/wav"))

    #expect(result.text == "Hello from the Vercel AI SDK.")
    #expect(result.language == "en")
    #expect(result.durationInSeconds == 2.479)
    #expect(result.segments.first == TranscriptionSegment(text: "Hello", startSecond: 0.199, endSecond: 0.479))
    #expect(result.segments.count == 6)
    #expect(result.responseMetadata.modelID == "ink-whisper")
}

@Test func cartesiaParityRoutesDatedInkWhisperSnapshotsToBatchEndpoint() async throws {
    let transport = RecordingTransport(response: jsonResponse(cartesiaTranscriptionFixture))
    let provider = try CartesiaProvider(settings: .init(apiKey: "test-api-key", environment: [:], transport: transport))
    _ = try await provider.transcriptionModel("ink-whisper-2025-06-04").transcribe(AudioTranscriptionRequest(audio: Data("audio".utf8), mimeType: "audio/wav"))

    let request = try #require(await transport.requests().first)
    #expect(request.url.absoluteString == "https://api.cartesia.ai/stt")
    let body = String(data: try #require(request.body), encoding: .utf8) ?? ""
    #expect(body.contains("name=\"model\"\r\n\r\nink-whisper-2025-06-04\r\n"))
}

// MARK: - Speech

@Test func cartesiaParitySpeechParsesOutputFormatSuffixWithJavaScriptNumberSemantics() async throws {
    let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 200, headers: ["content-type": "audio/wav"], body: Data([1])))
    let provider = try CartesiaProvider(settings: .init(apiKey: "test-api-key", environment: [:], transport: transport))
    let result = try await provider.speechModel("sonic-3").speak(SpeechRequest(text: "Hi", voice: "voice", format: "wav_16000.0"))

    #expect(result.warnings.isEmpty)
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["output_format"] == ["container": "wav", "encoding": "pcm_s16le", "sample_rate": 16000])
}

// MARK: - Realtime

private let realtimeDate = ISO8601DateFormatter().date(from: "2026-07-08T12:00:00Z")!

private func realtimeModel(_ transport: RecordingTransport = RecordingTransport(responses: [])) -> CartesiaRealtimeModel {
    CartesiaRealtimeModel(
        modelID: "ink-2",
        config: CartesiaHTTPConfiguration(
            providerID: "cartesia.realtime",
            baseURL: "https://api.cartesia.ai",
            headers: ["authorization": "Bearer test-key", "cartesia-version": "2026-03-01"],
            transport: transport
        ),
        version: "2026-03-01",
        currentDate: { realtimeDate }
    )
}

@Test func cartesiaRealtimeCreatesAutoFinalizeClientSecret() async throws {
    let transport = RecordingTransport(response: jsonResponse(#"{"token":"access-token"}"#))
    let model = realtimeModel(transport)

    let result = try await model.doCreateClientSecret(AIRealtimeClientSecretOptions(
        expiresAfterSeconds: 60,
        sessionConfig: AIRealtimeSessionConfiguration(
            inputAudioFormat: AIRealtimeAudioFormat(type: "audio/pcm", rate: 16000),
            inputAudioTranscription: AIRealtimeAudioTranscriptionConfiguration(language: "en"),
            turnDetection: AIRealtimeTurnDetectionConfiguration(type: .serverVAD)
        )
    ))

    let request = try #require(await transport.requests().first)
    #expect(request.method == "POST")
    #expect(request.url.absoluteString == "https://api.cartesia.ai/access-token")
    let headers = normalizeHeaders(request.headers)
    #expect(headers["authorization"] == "Bearer test-key")
    #expect(headers["cartesia-version"] == "2026-03-01")
    #expect(headers["content-type"] == "application/json")
    #expect(try decodeJSONBody(try #require(request.body)) == ["grants": ["stt": true], "expires_in": 60])
    #expect(result == AIRealtimeClientSecretResult(
        token: "access-token",
        url: "wss://api.cartesia.ai/stt/turns/websocket?model=ink-2&encoding=pcm_s16le&sample_rate=16000&cartesia_version=2026-03-01",
        expiresAt: 1_783_512_060
    ))
}

@Test func cartesiaRealtimeUsesManualFinalizeEndpointWhenTurnDetectionIsDisabled() async throws {
    // Upstream passes `turnDetection: null`; Swift expresses it as `.disabled`.
    let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 200, headers: [:], body: Data(#"{"token":"access-token"}"#.utf8)))
    let result = try await realtimeModel(transport).doCreateClientSecret(AIRealtimeClientSecretOptions(
        sessionConfig: AIRealtimeSessionConfiguration(
            inputAudioFormat: AIRealtimeAudioFormat(type: "audio/pcmu", rate: 8000),
            inputAudioTranscription: AIRealtimeAudioTranscriptionConfiguration(language: "en"),
            turnDetection: AIRealtimeTurnDetectionConfiguration(type: .disabled)
        )
    ))
    #expect(result.url == "wss://api.cartesia.ai/stt/websocket?model=ink-2&encoding=pcm_mulaw&sample_rate=8000&cartesia_version=2026-03-01&language=en")
    #expect(result.expiresAt == nil)
    #expect(try decodeJSONBody(try #require(await transport.requests().first?.body)) == ["grants": ["stt": true]])
}

@Test func cartesiaRealtimeRejectsUnsupportedLanguagesAndTokenLifetimes() async throws {
    let transport = RecordingTransport(responses: [])
    let model = realtimeModel(transport)
    do {
        _ = try await model.doCreateClientSecret(AIRealtimeClientSecretOptions(sessionConfig: AIRealtimeSessionConfiguration(
            inputAudioTranscription: AIRealtimeAudioTranscriptionConfiguration(language: "es")
        )))
        Issue.record("Expected language rejection")
    } catch {
        #expect(String(describing: error).contains("currently supports English only"))
    }
    do {
        _ = try await model.doCreateClientSecret(AIRealtimeClientSecretOptions(expiresAfterSeconds: 3601))
        Issue.record("Expected lifetime rejection")
    } catch {
        #expect(String(describing: error).contains("between 1 and 3600 seconds"))
    }
    #expect(await transport.requests().isEmpty)
}

@Test func cartesiaRealtimeAddsAccessTokenToWebSocketURL() {
    #expect(realtimeModel().getWebSocketConfig(token: "access-token", url: "wss://api.cartesia.ai/stt/turns/websocket?model=ink-2")
        == AIRealtimeWebSocketConfiguration(url: "wss://api.cartesia.ai/stt/turns/websocket?model=ink-2&access_token=access-token"))
}

@Test func cartesiaRealtimeSendsBinaryAudioAndLetsAutoFinalizeDetectTurns() async throws {
    let model = realtimeModel()
    _ = model.getWebSocketConfig(token: "token", url: "wss://api.cartesia.ai/stt/turns/websocket?model=ink-2")
    #expect(try await model.serializeClientEvent(.inputAudioAppend(audio: "AQID")) == .binary(Data([1, 2, 3])))
    #expect(try await model.serializeClientEvent(.inputAudioCommit) == nil)
    #expect(try await model.serializeClientEvent(.sessionUpdate(AIRealtimeSessionConfiguration())) == nil)
    #expect(model.buildSessionConfig(AIRealtimeSessionConfiguration()) == .null)
    await #expect(throws: AIError.self) { _ = try await model.serializeClientEvent(.responseCancel) }
}

@Test func cartesiaRealtimeSendsFinalizeForManualTurnDetection() async throws {
    let model = realtimeModel()
    _ = model.getWebSocketConfig(token: "token", url: "wss://api.cartesia.ai/stt/websocket?model=ink-2")
    #expect(try await model.serializeClientEvent(.inputAudioCommit) == .text("finalize"))
}

@Test func cartesiaRealtimeMapsInk2TurnEvents() {
    let model = realtimeModel()
    let connected: JSONValue = ["type": "connected", "request_id": "request-1"]
    let turnStart: JSONValue = ["type": "turn.start", "request_id": "request-1"]
    let turnEnd: JSONValue = ["type": "turn.end", "request_id": "request-1", "transcript": "Hello world"]

    #expect(model.parseServerEvent(connected) == [.sessionCreated(sessionID: "request-1", raw: connected)])
    #expect(model.parseServerEvent(turnStart) == [.speechStarted(itemID: "request-1", raw: turnStart)])
    #expect(model.parseServerEvent(turnEnd) == [
        .speechStopped(itemID: "request-1", raw: turnEnd),
        .inputTranscriptionCompleted(itemID: "request-1", transcript: "Hello world", raw: turnEnd)
    ])
}

@Test func cartesiaRealtimeAssemblesManualTranscriptChunksWhenFlushCompletes() {
    let model = realtimeModel()
    let first: JSONValue = ["type": "transcript", "request_id": "request-1", "text": "Hello ", "is_final": true, "duration": 0.5]
    let second: JSONValue = ["type": "transcript", "request_id": "request-1", "text": "world", "is_final": true, "duration": 0.4]
    let flush: JSONValue = ["type": "flush_done", "request_id": "request-1"]

    #expect(model.parseServerEvent(first) == [
        .sessionCreated(sessionID: "request-1", raw: first),
        .custom(rawType: "transcript", raw: first)
    ])
    _ = model.parseServerEvent(second)
    let events = model.parseServerEvent(flush)
    #expect(events.count == 2)
    #expect(events.first == .audioCommitted(itemID: "request-1", previousItemID: nil, raw: flush))
    guard case let .inputTranscriptionCompleted(itemID, transcript, raw) = events.last else {
        Issue.record("Expected input transcription completion")
        return
    }
    #expect(itemID == "request-1")
    #expect(transcript == "Hello world")
    #expect(raw["event"] == flush)
    #expect(raw["transcriptEvents"] == .array([first, second]))
    #expect(abs((raw["duration"]?.doubleValue ?? 0) - 0.9) < 1e-12)
}

@Test func cartesiaRealtimeEmitsOneCustomEventWhenManualStreamClosesWithoutText() {
    let model = realtimeModel()
    let done: JSONValue = ["type": "done", "request_id": "request-1"]
    #expect(model.parseServerEvent(done) == [
        .sessionCreated(sessionID: "request-1", raw: done),
        .custom(rawType: "done", raw: done)
    ])
}

@Test func cartesiaRealtimeMapsStructuredErrors() {
    let model = realtimeModel()
    let error: JSONValue = ["type": "error", "message": "Invalid model", "error_code": "model_not_found", "request_id": "request-1"]
    #expect(model.parseServerEvent(error) == [
        .sessionCreated(sessionID: "request-1", raw: error),
        .error(message: "Invalid model", code: "model_not_found", raw: error)
    ])
}

@Test func cartesiaProviderCreatesRealtimeModels() throws {
    let provider = try CartesiaProvider(settings: .init(apiKey: "test-api-key", environment: [:]))
    let model = try provider.realtimeModel("ink-2")
    #expect(model.providerID == "cartesia.realtime")
    #expect(model.modelID == "ink-2")
    #expect(try provider.experimentalRealtime("ink-2").modelID == "ink-2")
}
