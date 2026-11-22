import Foundation
import SwiftAIProvider
import SwiftAITransport
import Testing
@testable import SwiftAIAssemblyAI

// Translated from assemblyai-transcription-model.test.ts at @ai-sdk/assemblyai 3.0.85.
@Suite("AssemblyAI transcription (upstream)")
struct AssemblyAIUpstreamParityTests {
    @Test func sendsFlagshipViaSpeechModels() async throws {
        let fixture = try TranscriptionFixture()
        let result = try await fixture.transcribe()
        let body = try await fixture.submission()
        #expect(body["audio_url"] == "https://storage.assemblyai.com/mock-upload-url")
        #expect(body["speech_models"] == ["assemblyai-stt-3-7"])
        #expect(body["speech_model"] == nil)
        #expect(result.warnings.isEmpty)

        let requests = await fixture.transport.requests()
        #expect(requests.map(\.method) == ["POST", "POST", "GET"])
        #expect(requests.map(\.url.absoluteString) == [
            "https://api.assemblyai.com/v2/upload",
            "https://api.assemblyai.com/v2/transcript",
            "https://api.assemblyai.com/v2/transcript/\(transcriptID)"
        ])
        #expect(requests.first?.body == fixture.audio)
    }

    @Test func routesUniversal35ProWithDeprecationWarning() async throws {
        let fixture = try TranscriptionFixture(modelID: "universal-3-5-pro")
        let result = try await fixture.transcribe()
        let body = try await fixture.submission()
        #expect(body["speech_models"] == ["universal-3-5-pro"])
        #expect(body["speech_model"] == nil)
        #expect(result.warnings == [
            .init(type: "deprecated", setting: "model 'universal-3-5-pro'",
                  message: "AssemblyAI has deprecated 'universal-3-5-pro'. Use 'assemblyai-stt-3-7' instead. See documentation: https://www.assemblyai.com/docs/pre-recorded-audio/select-the-speech-model")
        ])
    }

    @Test func recommendsFlagshipWithoutDeprecatingUniversal2() async throws {
        let fixture = try TranscriptionFixture(modelID: "universal-2")
        let result = try await fixture.transcribe()
        #expect(result.warnings == [
            .init(type: "other", message: "'assemblyai-stt-3-7' is AssemblyAI's latest flagship model; 'universal-2' remains available for languages it does not support. See https://www.assemblyai.com/docs/pre-recorded-audio/select-the-speech-model")
        ])
    }

    @Test(arguments: ["best", "slam-1", "nano", "universal-3-pro"])
    func routesRemovedIDsWithoutSpecialCases(_ modelID: String) async throws {
        let fixture = try TranscriptionFixture(modelID: modelID)
        let result = try await fixture.transcribe()
        let body = try await fixture.submission()
        #expect(body["speech_models"] == .array([.string(modelID)]))
        #expect(body["speech_model"] == nil)
        #expect(result.warnings.isEmpty)
    }

    @Test func sendsProviderOptionsAlongsideSpeechModels() async throws {
        let fixture = try TranscriptionFixture()
        _ = try await fixture.transcribe(options: ["languageDetection": true, "punctuate": false])
        let body = try await fixture.submission()
        #expect(body["speech_models"] == ["assemblyai-stt-3-7"])
        #expect(body["language_detection"] == true)
        #expect(body["punctuate"] == false)
    }

    @Test func surfacesDiarizationAndAudioIntelligenceMetadata() async throws {
        let fixture = try TranscriptionFixture()
        let result = try await fixture.transcribe()
        let metadata = try #require(result.providerMetadata["assemblyai"])
        #expect(metadata["utterances"]?[0]?["speaker"] == "A")
        #expect(metadata["utterances"]?[0]?["text"] == "Hello, world!")
        #expect(metadata["entities"]?[0]?["entity_type"] == "location")
        #expect(metadata["entities"]?[0]?["text"] == "Canada")
        #expect(metadata["sentimentAnalysisResults"]?[0]?["sentiment"] == "POSITIVE")
        #expect(metadata["sentimentAnalysisResults"]?[0]?["text"] == "Hello, world!")
        #expect(metadata["contentSafetyLabels"] != nil)
        #expect(metadata["iabCategoriesResult"] != nil)
        #expect(metadata["autoHighlightsResult"] != nil)
    }

    @Test func preservesFullRawResponseBody() async throws {
        let fixture = try TranscriptionFixture()
        let result = try await fixture.transcribe()
        let body = try #require(result.responseMetadata.body)
        #expect(body["words"]?[0]?["speaker"] == "speaker")
        #expect(body["chapters"] != nil)
        #expect(body["summary"] == "- Hello, world!")
        let expected = try decodeJSONBody(fixture.completedBody)
        #expect(body == expected)
    }

    @Test func passesPromptedModelParameters() async throws {
        let fixture = try TranscriptionFixture()
        _ = try await fixture.transcribe(options: [
            "prompt": "This is a conversation about the AI SDK.", "keytermsPrompt": ["Vercel", "AI SDK"],
            "temperature": 0.2, "removeAudioTags": "speaker", "domain": "medical-v1"
        ])
        let body = try await fixture.submission()
        #expect(body["speech_models"] == ["assemblyai-stt-3-7"])
        #expect(body["prompt"] == "This is a conversation about the AI SDK.")
        #expect(body["keyterms_prompt"] == ["Vercel", "AI SDK"])
        #expect(body["temperature"] == 0.2)
        #expect(body["remove_audio_tags"] == "speaker")
        #expect(body["domain"] == "medical-v1")
    }

    @Test func passesNestedInputParameters() async throws {
        let fixture = try TranscriptionFixture()
        _ = try await fixture.transcribe(options: [
            "redactPii": true,
            "speakerOptions": ["minSpeakersExpected": 1, "maxSpeakersExpected": 3],
            "languageDetectionOptions": [
                "expectedLanguages": ["en", "es"], "fallbackLanguage": "en", "codeSwitching": true, "codeSwitchingConfidenceThreshold": 0.5
            ],
            "redactPiiAudioOptions": ["returnRedactedNoSpeechAudio": true, "overrideAudioRedactionMethod": "silence"],
            "redactPiiReturnUnredacted": true,
            "redactStaticEntities": ["INTERNAL_TOOL": ["Bearclaw"]]
        ])
        let body = try await fixture.submission()
        #expect(body["speaker_options"] == ["min_speakers_expected": 1, "max_speakers_expected": 3])
        #expect(body["language_detection_options"] == [
            "expected_languages": ["en", "es"], "fallback_language": "en", "code_switching": true, "code_switching_confidence_threshold": 0.5
        ])
        #expect(body["redact_pii_audio_options"] == ["return_redacted_no_speech_audio": true, "override_audio_redaction_method": "silence"])
        #expect(body["redact_pii_return_unredacted"] == true)
        #expect(body["redact_static_entities"] == ["INTERNAL_TOOL": ["Bearclaw"]])
    }

    @Test func warnsWhenDeprecatedWordBoostAndBoostParamAreUsed() async throws {
        let result = try await TranscriptionFixture().transcribe(options: ["wordBoost": ["Vercel"], "boostParam": "high"])
        #expect(result.warnings.contains { warning in
            warning.type == "deprecated" && warning.setting == "wordBoost, boostParam" && warning.message?.contains("keytermsPrompt") == true
        })
    }

    @Test func attributesTheDeprecationWarningToBoostParamWhenOnlyBoostParamIsSet() async throws {
        let result = try await TranscriptionFixture().transcribe(options: ["boostParam": "high"])
        #expect(result.warnings.contains { warning in
            warning.type == "deprecated" && warning.setting == "boostParam" && warning.message?.contains("keytermsPrompt") == true
        })
    }

    @Test func warnsWhenRedactPiiDependentOptionsAreSetWithoutRedactPii() async throws {
        let result = try await TranscriptionFixture().transcribe(options: ["redactStaticEntities": ["TOOL": ["Vercel"]]])
        #expect(result.warnings.contains { $0.type == "other" && $0.message?.contains("redactPii") == true })
    }

    @Test func warnsWhenRedactPiiAudioOptionsIsSetWithoutRedactPiiAudio() async throws {
        let result = try await TranscriptionFixture().transcribe(options: [
            "redactPii": true,
            "redactPiiAudioOptions": ["overrideAudioRedactionMethod": "silence"]
        ])
        #expect(result.warnings.contains { $0.type == "other" && $0.message?.contains("redactPiiAudio") == true })
    }

    @Test func warnsWhenLanguageCodeAndLanguageDetectionAreCombined() async throws {
        let result = try await TranscriptionFixture().transcribe(options: ["languageCode": "en", "languageDetection": true])
        #expect(result.warnings.contains { $0.type == "other" && $0.message?.contains("languageDetection") == true })
    }

    @Test func reportsSegmentTimingsInSeconds() async throws {
        let result = try await TranscriptionFixture().transcribe()
        #expect(result.segments.first == TranscriptionSegment(text: "Hello,", startSecond: 0.25, endSecond: 0.65))
    }

    @Test func passesHeaders() async throws {
        let fixture = try TranscriptionFixture(providerHeaders: ["Custom-Provider-Header": "provider-header-value"])
        _ = try await fixture.transcribe(headers: ["Custom-Request-Header": "request-header-value"])
        let upload = normalizeHeaders(try #require(await fixture.transport.requests().first).headers)
        #expect(upload["authorization"] == "test-api-key")
        #expect(upload["content-type"] == "application/octet-stream")
        #expect(upload["custom-provider-header"] == "provider-header-value")
        #expect(upload["custom-request-header"] == "request-header-value")
        #expect(upload["user-agent"]?.contains("ai-sdk-assemblyai/3.0.85") == true)
    }

    @Test func extractsTranscriptionText() async throws {
        let result = try await TranscriptionFixture().transcribe()
        #expect(result.text == "Hello, world!")
    }

    @Test func surfacesAFlatErrorMessageFromTheSubmitCall() async throws {
        let submit = AIHTTPResponse(statusCode: 401, headers: ["content-type": "application/json"], body: Data(#"{"error":"Invalid API key"}"#.utf8))
        let fixture = try TranscriptionFixture(submit: submit)
        let error = try await #require(throws: AIError.self) {
            _ = try await fixture.transcribe()
        }
        let apiError = try #require(error.apiCallError)
        #expect(apiError.statusCode == 401)
        #expect(apiError.responseBody == "Invalid API key")
    }

    @Test func includesResponseDataWithTimestampModelIDAndHeaders() async throws {
        let testDate = Date(timeIntervalSince1970: 0)
        let fixture = try TranscriptionFixture(
            responseHeaders: ["x-request-id": "test-request-id", "x-ratelimit-remaining": "123"], currentDate: { testDate }
        )
        let result = try await fixture.transcribe()
        #expect(result.responseMetadata.modelID == "assemblyai-stt-3-7")
        #expect(result.responseMetadata.id == nil)
        #expect(result.responseMetadata.timestamp == testDate)
        #expect(result.responseMetadata.headers["content-type"] == "application/json")
        #expect(result.responseMetadata.headers["x-request-id"] == "test-request-id")
        #expect(result.responseMetadata.headers["x-ratelimit-remaining"] == "123")
        #expect(result.responseMetadata.body?["id"] == .string(transcriptID))
    }

    @Test func usesInjectedDateEvenWhenProviderUsesDefaultHeaders() async throws {
        // The upstream case also injects an epoch clock despite its test title.
        let testDate = Date(timeIntervalSince1970: 0)
        let result = try await TranscriptionFixture(currentDate: { testDate }).transcribe()
        #expect(result.responseMetadata.timestamp == testDate)
        #expect(result.responseMetadata.modelID == "assemblyai-stt-3-7")
    }

    @Test func usesClockWhenNoDateIsInjected() async throws {
        let before = Date()
        let result = try await TranscriptionFixture().transcribe()
        let timestamp = try #require(result.responseMetadata.timestamp)
        #expect((before...Date()).contains(timestamp))
    }

    @Test func keepsEmptyWordsAndDerivesDurationFromTheLastWord() async throws {
        let final = #"{"id":"t","status":"completed","text":"","words":[{"start":0,"end":3000,"text":"a"},{"start":1000,"end":2000,"text":""}]}"#
        let result = try await TranscriptionFixture(final: final).transcribe()
        #expect(result.segments == [
            TranscriptionSegment(text: "a", startSecond: 0, endSecond: 3),
            TranscriptionSegment(text: "", startSecond: 1, endSecond: 2)
        ])
        #expect(result.durationInSeconds == 2)
    }

    @Test(arguments: [
        (#"{"error":"format_text must be a Boolean","status":"error"}"#, 400, "format_text must be a Boolean"),
        (#"{"error":{"message":"Resource has been exhausted (e.g. check quota).","code":429}}"#, 429, "Resource has been exhausted (e.g. check quota).")
    ])
    func keepsSwiftFlatAndNestedTranscriptionErrorBodies(body: String, status: Int, message: String) async throws {
        let submit = AIHTTPResponse(statusCode: status, body: Data(body.utf8))
        await #expect(throws: AIError.apiCall(provider: "assemblyai.transcription", statusCode: status, body: message)) {
            _ = try await TranscriptionFixture(submit: submit).transcribe()
        }
    }
}

private let transcriptID = "9ea68fd3-f953-42c1-9742-976c447fb463"
private let uploadBody = #"{"id":"9ea68fd3-f953-42c1-9742-976c447fb463","upload_url":"https://storage.assemblyai.com/mock-upload-url"}"#
private let submitBody = #"{"id":"9ea68fd3-f953-42c1-9742-976c447fb463","status":"queued"}"#

private struct TranscriptionFixture {
    let audio: Data
    let completedBody: Data
    let transport: RecordingTransport
    let model: any TranscriptionModel

    init(modelID: String = "assemblyai-stt-3-7", final: String? = nil, submit: AIHTTPResponse? = nil,
         providerHeaders: [String: String] = [:], responseHeaders: [String: String] = [:], currentDate: (@Sendable () -> Date)? = nil) throws {
        audio = try Data(contentsOf: #require(Bundle.module.url(forResource: "transcript-test", withExtension: "mp3")))
        if let final {
            completedBody = Data(final.utf8)
        } else {
            completedBody = try Data(contentsOf: #require(Bundle.module.url(forResource: "transcript-completed", withExtension: "json")))
        }
        let completed = AIHTTPResponse(statusCode: 200, headers: ["content-type": "application/json"].merging(responseHeaders) { _, value in value }, body: completedBody)
        transport = RecordingTransport(responses: [jsonResponse(uploadBody), submit ?? jsonResponse(submitBody), completed])
        if let currentDate {
            let baseURL = "https://api.assemblyai.com"
            let http = AIProviderHTTPClient(providerID: "test-provider", transport: transport, url: { _, path in
                try requireURL("\(baseURL)\(path)")
            })
            model = AssemblyAITranscriptionModel(modelID: modelID, config: .init(http: http, baseURL: baseURL), currentDate: currentDate)
        } else {
            model = try AIProviders.assemblyAI(configuration: .init(apiKey: "test-api-key", headers: providerHeaders, transport: transport))
                .transcriptionModel(modelID)
        }
    }

    func transcribe(options: JSONValue? = nil, headers: [String: String] = [:]) async throws -> TranscriptionResult {
        try await model.transcribe(.init(audio: audio, mimeType: "audio/wav", providerOptions: options.map { ["assemblyai": $0] } ?? [:], headers: headers))
    }

    func submission() async throws -> JSONValue {
        let requests = await transport.requests()
        let request = try #require(requests.dropFirst().first)
        return try decodeJSONBody(#require(request.body))
    }
}
