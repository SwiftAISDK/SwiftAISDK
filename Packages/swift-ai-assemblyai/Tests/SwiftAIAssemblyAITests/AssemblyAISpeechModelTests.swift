import Foundation
import SwiftAI
import SwiftAIProvider
import SwiftAITransport
import Testing
@testable import SwiftAIAssemblyAI

// Translated from assemblyai-speech-model.test.ts at @ai-sdk/assemblyai 3.0.85.
@Suite("AssemblyAI speech (upstream)")
struct AssemblyAISpeechModelTests {
    @Test func sendsABufferedMP3RequestByDefault() async throws {
        let fixture = try SpeechFixture()
        let result = try await fixture.model.speak(.init(text: "Hello, world!"))
        let requests = await fixture.transport.sendRequests()
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.url.absoluteString == "https://tts.us.assemblyai.com/v1/speech")
        #expect(request.method == "POST")
        #expect(await fixture.transport.streamRequests().isEmpty)
        let expected: JSONValue = ["text": "Hello, world!", "model_id": "assemblyai-tts-1", "encoding": "mp3", "stream": false]
        #expect(try await fixture.body() == expected)
        #expect(result.requestMetadata.body == expected)
        #expect(result.warnings.isEmpty)
        #expect(result.usage == nil)
    }

    @Test func passesAPIKeyHeadersAndUserAgent() async throws {
        let fixture = try SpeechFixture(providerHeaders: ["Custom-Provider-Header": "provider-header-value"])
        _ = try await fixture.model.speak(.init(text: "Hello, world!", headers: ["Custom-Request-Header": "request-header-value"]))

        let request = try #require(await fixture.transport.requests().first)
        let headers = normalizeHeaders(request.headers)
        #expect(headers["authorization"] == "test-api-key")
        #expect(headers["content-type"] == "application/json")
        #expect(headers["custom-provider-header"] == "provider-header-value")
        #expect(headers["custom-request-header"] == "request-header-value")
        #expect(headers["user-agent"]?.contains("ai-sdk-assemblyai/3.0.85") == true)
    }

    @Test func sendsVoiceAndTranslatesLanguageCode() async throws {
        let fixture = try SpeechFixture()
        _ = try await fixture.model.speak(.init(text: "Hola, mundo!", voice: "aai-kyla", language: "es"))
        let body = try await fixture.body()
        #expect(body["voice_id"] == "aai-kyla")
        #expect(body["language"] == "spanish")
    }

    @Test func acceptsFullLanguageName() async throws {
        let fixture = try SpeechFixture()
        _ = try await fixture.model.speak(.init(text: "Bonjour", language: "French"))
        #expect(try await fixture.body()["language"] == "french")
    }

    @Test(arguments: [
        ("wav", "pcm_s16le", "wav", nil as Int?),
        ("pcm", "pcm_s16le", "raw", nil),
        ("mulaw", "pcm_mulaw", "raw", 8000),
        ("alaw", "pcm_alaw", "raw", 8000)
    ])
    func mapsOutputFormat(_ format: String, _ encoding: String, _ container: String, _ sampleRate: Int?) async throws {
        let fixture = try SpeechFixture()
        _ = try await fixture.model.speak(.init(text: "Hello, world!", format: format))

        var expected: [String: JSONValue] = [
            "text": "Hello, world!", "model_id": "assemblyai-tts-1",
            "encoding": .string(encoding), "container": .string(container), "stream": false
        ]
        expected["sample_rate"] = sampleRate.map { .number(Double($0)) }
        #expect(try await fixture.body() == .object(expected))
    }

    @Test func fallsBackToMP3ForUnknownOutputFormat() async throws {
        let fixture = try SpeechFixture()
        let result = try await fixture.model.speak(.init(text: "Hello, world!", format: "opus"))
        #expect(try await fixture.body()["encoding"] == "mp3")
        #expect(result.warnings == [
            .init(type: "unsupported", feature: "outputFormat", message: "Unknown output format \"opus\". Falling back to mp3. Use providerOptions.assemblyai to configure encoding, container, and sampleRate directly.")
        ])
    }

    @Test func appliesProviderOptionsOverOutputFormat() async throws {
        let fixture = try SpeechFixture()
        _ = try await fixture.model.speak(.init(text: "Hello, world!", format: "mulaw", providerOptions: [
            "assemblyai": ["encoding": "pcm_s16le", "sampleRate": 16000]
        ]))
        #expect(try await fixture.body() == [
            "text": "Hello, world!", "model_id": "assemblyai-tts-1", "encoding": "pcm_s16le", "sample_rate": 16000, "stream": false
        ])
    }

    @Test func sendsMP3BitRate() async throws {
        let fixture = try SpeechFixture()
        _ = try await fixture.model.speak(.init(text: "Hello, world!", providerOptions: ["assemblyai": ["bitRate": 128000]]))
        let body = try await fixture.body()
        #expect(body["encoding"] == "mp3")
        #expect(body["bit_rate"] == 128000)
    }

    @Test func ignoresOptionsThatDoNotFitTheEncoding() async throws {
        let fixture = try SpeechFixture()
        let mp3 = try await fixture.model.speak(.init(text: "Hello, world!", providerOptions: ["assemblyai": ["container": "wav"]]))
        let wav = try await fixture.model.speak(.init(text: "Hello, world!", format: "wav", providerOptions: ["assemblyai": ["bitRate": 64000]]))
        #expect(try await fixture.body(at: 0)["container"] == nil)
        #expect(try await fixture.body(at: 1)["bit_rate"] == nil)
        #expect(mp3.warnings + wav.warnings == [
            .init(type: "unsupported", feature: "providerOptions.assemblyai.container", message: "AssemblyAI MP3 output has no container. The container option was ignored."),
            .init(type: "unsupported", feature: "providerOptions.assemblyai.bitRate", message: "AssemblyAI only accepts a bit rate for MP3 output. The bitRate option was ignored.")
        ])
    }

    @Test func warnsOnUnsupportedLanguageSpeedAndInstructions() async throws {
        let fixture = try SpeechFixture()
        let result = try await fixture.model.speak(.init(text: "Hello, world!", speed: 1.2, language: "ja", instructions: "Speak slowly"))
        let body = try await fixture.body()
        #expect(body["language"] == nil)
        #expect(body["speed"] == nil)
        #expect(body["instructions"] == nil)
        #expect(result.warnings == [
            .init(type: "unsupported", feature: "language", message: "AssemblyAI text-to-speech does not support language \"ja\" (supported: de, en, es, fr, it, pt). The language option was ignored."),
            .init(type: "unsupported", feature: "speed", message: "AssemblyAI text-to-speech only supports the default speed. The speed option was ignored."),
            .init(type: "unsupported", feature: "instructions", message: "AssemblyAI text-to-speech does not support instructions. Instructions parameter was ignored.")
        ])
    }

    @Test func omitsAutomaticLanguageDetectionWithWarning() async throws {
        let fixture = try SpeechFixture()
        let result = try await fixture.model.speak(.init(text: "Hello, world!", language: "auto"))
        #expect(try await fixture.body()["language"] == nil)
        #expect(result.warnings == [
            .init(type: "unsupported", feature: "language", message: "AssemblyAI text-to-speech does not detect the language. The voice speaks its own language.")
        ])
    }

    @Test func doesNotWarnForDefaultSpeed() async throws {
        let fixture = try SpeechFixture()
        let result = try await fixture.model.speak(.init(text: "Hello, world!", speed: 1))
        #expect(result.warnings.isEmpty)
    }

    @Test func returnsAudioUsageAndResponseMetadata() async throws {
        let testDate = Date(timeIntervalSince1970: 0)
        let headers = [
            "x-request-id": "test-request-id", "x-tts-model": "assemblyai-tts-1", "x-tts-voice-id": "aai-kyla",
            "x-tts-language": "english", "x-tts-encoding": "mp3", "x-tts-sample-rate": "24000",
            "x-tts-audio-duration-ms": "3200", "x-tts-billed-characters": "13"
        ]
        let response = speechAudioResponse(headers: headers)
        let transport = RecordingTransport(response: response)
        let http = AIProviderHTTPClient(providerID: "test-provider", transport: transport, url: { _, _ in
            try requireURL("https://tts.us.assemblyai.com/v1/speech")
        })
        let model = AssemblyAISpeechModel(modelID: "assemblyai-tts-1", http: http, currentDate: { testDate })
        let result = try await model.speak(.init(text: "Hello, world!"))

        #expect(result.audio == Data(repeating: 0, count: 100))
        #expect(result.contentType == "audio/mpeg")
        #expect(result.usage == ["characters": 13])
        #expect(result.providerMetadata == [
            "assemblyai": ["requestId": "test-request-id", "model": "assemblyai-tts-1", "voiceId": "aai-kyla",
                           "language": "english", "encoding": "mp3", "sampleRate": 24000,
                           "audioDurationMs": 3200, "billedCharacters": 13]
        ])
        #expect(result.responseMetadata.timestamp == testDate)
        #expect(result.responseMetadata.modelID == "assemblyai-tts-1")
        #expect(result.responseMetadata.headers == response.headers)
    }

    @Test func surfacesAPIErrors() async throws {
        let body = #"{"code":"voice_not_found","message":"voice_id: no voice with this ID or slug","param":"voice_id","request_id":"test-request-id","errors":null,"retryable":false,"retry_after_seconds":null,"error":"voice_id: no voice with this ID or slug"}"#
        let fixture = try SpeechFixture(response: AIHTTPResponse(statusCode: 422, body: Data(body.utf8)))
        let error = try await #require(throws: AIError.self) {
            _ = try await fixture.model.speak(.init(text: "Hello, world!", voice: "missing"))
        }
        let apiError = try #require(error.apiCallError)
        #expect(apiError.message == "voice_id: no voice with this ID or slug")
        #expect(apiError.statusCode == 422)
        #expect(apiError.responseBody == body)
        #expect(apiError.isRetryable == false)
    }

    // Swift-specific coverage for the typed API and supported transport.
    @Test func facadeUsesTypedOptionsAndCustomSpeechOrigin() async throws {
        let transport = RecordingTransport(response: speechAudioResponse(headers: ["X-TTS-Billed-Characters": "0"]))
        let provider = try AIProviders.assemblyAI(configuration: AssemblyAIProviderSettings(
            apiKey: "test-api-key", baseURL: "https://transcript.example.test", speechBaseURL: "https://speech.example.test/",
            queryParams: ["client": "swift"], transport: transport
        ))
        let model = try provider.speechModel("assemblyai-tts-1")
        #expect(provider.supportedCapabilities == [.speech, .transcription])
        let options = AssemblyAISpeechModelOptions(encoding: .pcmS16LE, container: .wav, sampleRate: 24000)
        let signal = AIAbortController().signal
        let result = try await AI.generateSpeech(model: model, request: .init(text: "hello", providerOptions: options.providerOptions, abortSignal: signal))
        let request = try #require(await transport.requests().first)
        #expect(request.url.absoluteString == "https://speech.example.test/v1/speech?client=swift")
        #expect(request.abortSignal === signal)
        #expect(try decodeJSONBody(#require(request.body)) == [
            "text": "hello", "model_id": "assemblyai-tts-1", "encoding": "pcm_s16le", "container": "wav", "sample_rate": 24000, "stream": false
        ])
        #expect(result.usage == ["characters": 0])
    }

    @Test(arguments: [
        ("encoding", JSONValue.string("opus")), ("container", .string("ogg")), ("sampleRate", .number(12345)),
        ("bitRate", .string("128000")), ("bitRate", .number(32000.5)), ("sampleRate", .null)
    ])
    func validatesProviderOptionsBeforeTransport(_ key: String, _ value: JSONValue) async throws {
        let fixture = try SpeechFixture()
        let error = try await #require(throws: AIError.self) {
            _ = try await fixture.model.speak(.init(text: "Hello, world!", providerOptions: ["assemblyai": .object([key: value])]))
        }
        guard case let .invalidArgument(argument, _) = error else {
            Issue.record("Expected provider option validation error, received \(error)")
            return
        }
        #expect(argument == "providerOptions.assemblyai.\(key)")
        #expect(await fixture.transport.requests().isEmpty)
    }
}

private func speechAudioResponse(headers: [String: String] = [:]) -> AIHTTPResponse {
    AIHTTPResponse(statusCode: 200, headers: ["content-type": "audio/mpeg"].merging(headers) { _, value in value },
                   body: Data(repeating: 0, count: 100))
}

private struct SpeechFixture {
    let transport: RecordingTransport
    let model: AssemblyAISpeechModel

    init(response: AIHTTPResponse = speechAudioResponse(), providerHeaders: [String: String] = [:]) throws {
        transport = RecordingTransport(response: response)
        model = try AssemblyAIProvider(configuration: .init(apiKey: "test-api-key", headers: providerHeaders, transport: transport))
            .speech("assemblyai-tts-1")
    }

    func body(at index: Int = 0) async throws -> JSONValue {
        let requests = await transport.requests()
        let request = try #require(requests.indices.contains(index) ? requests[index] : nil)
        return try decodeJSONBody(#require(request.body))
    }
}
