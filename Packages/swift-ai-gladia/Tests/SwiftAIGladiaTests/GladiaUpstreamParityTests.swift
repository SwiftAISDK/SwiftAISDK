@testable import SwiftAIGladia
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translated from packages/gladia/src/gladia-transcription-model.test.ts and
// gladia-error.test.ts, using the fixtures in GladiaUpstreamFixtures.swift.

private let resultURL = "https://api.gladia.io/v2/pre-recorded/7b0137fd-5fd6-4d08-b9bf-4cdf9876797d"
private let uploadedAudioURL = "https://api.gladia.io/file/7403f025-be30-4335-ae29-20131e0adbd6"

private func fixtureJSON(_ text: String) -> JSONValue { try! decodeJSONBody(Data(text.utf8)) }

private func gladiaTransport(result: String = gladiaResultFixture, initiate: String = gladiaInitiateFixture, headers: [String: String] = [:]) -> RecordingTransport {
    RecordingTransport(responses: [
        jsonResponse(gladiaUploadFixture),
        jsonResponse(initiate, headers: headers),
        jsonResponse(result, headers: headers)
    ])
}

private func gladiaModel(_ transport: RecordingTransport, modelID: String = "default", headers: [String: String] = [:], pollIntervalMs: Int? = nil, pollTimeoutMs: Int? = nil) throws -> any TranscriptionModel {
    try AIProviders.gladia(configuration: GladiaProviderSettings(
        apiKey: "test-api-key", headers: headers, transport: transport, pollIntervalMs: pollIntervalMs, pollTimeoutMs: pollTimeoutMs
    )).transcriptionModel(modelID)
}

private func transcribe(_ model: any TranscriptionModel, gladia: JSONValue? = nil, headers: [String: String] = [:]) async throws -> TranscriptionResult {
    try await model.transcribe(AudioTranscriptionRequest(
        audio: Data([1, 2, 3]),
        mimeType: "audio/wav",
        providerOptions: gladia.map { ["gladia": $0] } ?? [:],
        headers: headers
    ))
}

private func initiateBody(_ transport: RecordingTransport) async throws -> JSONValue {
    try decodeJSONBody(try #require(await transport.requests().dropFirst().first?.body))
}

@Suite("Gladia doGenerate (upstream)")
struct GladiaUpstreamTranscriptionTests {
    @Test func passesAudioURLToPreRecordedEndpoint() async throws {
        let transport = gladiaTransport()
        _ = try await transcribe(try gladiaModel(transport))
        #expect(try await initiateBody(transport)["audio_url"]?.stringValue == uploadedAudioURL)
    }

    @Test func passesProviderOptionsToPreRecordedEndpoint() async throws {
        let transport = gladiaTransport()
        _ = try await transcribe(try gladiaModel(transport), gladia: [
            "languageConfig": ["languages": ["en"], "codeSwitching": true],
            "piiRedaction": true,
            "piiRedactionConfig": ["entityTypes": ["EMAIL_ADDRESS", "NAME"], "processedTextType": "MARKER"]
        ])
        let body = try await initiateBody(transport)
        #expect(body["language_config"] == ["languages": ["en"], "code_switching": true])
        #expect(body["pii_redaction"] == true)
        #expect(body["pii_redaction_config"] == ["entity_types": ["EMAIL_ADDRESS", "NAME"], "processed_text_type": "MARKER"])
    }

    @Test func mapsDeprecatedLanguageOptionsToLanguageConfig() async throws {
        let transport = gladiaTransport()
        _ = try await transcribe(try gladiaModel(transport), gladia: ["language": "en", "enableCodeSwitching": true])
        #expect(try await initiateBody(transport)["language_config"] == ["languages": ["en"], "code_switching": true])
    }

    @Test func mapsDeprecatedCustomVocabularyArraysToCustomVocabularyConfig() async throws {
        let transport = gladiaTransport()
        _ = try await transcribe(try gladiaModel(transport), gladia: ["customVocabulary": ["Gladia", "AI SDK"]])
        let body = try await initiateBody(transport)
        #expect(body["custom_vocabulary"] == true)
        #expect(body["custom_vocabulary_config"] == ["vocabulary": ["Gladia", "AI SDK"]])
    }

    @Test func passesTheModelIDAndOmitsItForDefault() async throws {
        let solaria = gladiaTransport()
        _ = try await transcribe(try gladiaModel(solaria, modelID: "solaria-3"), gladia: ["languageConfig": ["languages": ["fr"]]])
        let body = try await initiateBody(solaria)
        #expect(body["model"] == "solaria-3")
        #expect(body["language_config"] == ["languages": ["fr"]])

        let defaultTransport = gladiaTransport()
        _ = try await transcribe(try gladiaModel(defaultTransport))
        #expect(try await initiateBody(defaultTransport)["model"] == nil)
    }

    @Test func warnsWhenSolaria3IsCombinedWithMultipleLanguagesOrCodeSwitching() async throws {
        let result = try await transcribe(try gladiaModel(gladiaTransport(), modelID: "solaria-3"), gladia: [
            "languageConfig": ["languages": ["fr", "en"], "codeSwitching": true]
        ])
        #expect(result.warnings.map(\.type) == ["other", "other"])
        #expect(result.warnings[0].message?.contains("single language") == true)
        #expect(result.warnings[1].message?.contains("code switching") == true)
    }

    @Test func doesNotWarnWhenSolaria3IsUsedWithASingleLanguage() async throws {
        let result = try await transcribe(try gladiaModel(gladiaTransport(), modelID: "solaria-3"), gladia: ["languageConfig": ["languages": ["fr"]]])
        #expect(result.warnings == [])
    }

    @Test func doesNotSendTheAPIKeyWhenTheResultURLIsOnAForeignOrigin() async throws {
        let foreign = "https://cdn.evil.example/v2/pre-recorded/result"
        let transport = gladiaTransport(initiate: #"{"id":"7b0137fd","result_url":"\#(foreign)"}"#)
        _ = try await transcribe(try gladiaModel(transport))
        let poll = try #require(await transport.requests().first { $0.url.absoluteString == foreign })
        #expect(normalizeHeaders(poll.headers)["x-gladia-key"] == nil)
    }

    @Test func passesHeaders() async throws {
        let transport = gladiaTransport()
        _ = try await transcribe(
            try gladiaModel(transport, headers: ["Custom-Provider-Header": "provider-header-value"]),
            headers: ["Custom-Request-Header": "request-header-value"]
        )
        let requests = await transport.requests()
        let initiate = normalizeHeaders(requests[1].headers)
        #expect(initiate["x-gladia-key"] == "test-api-key")
        #expect(initiate["x-gladia-version"] == "ai-sdk/3.0.84")
        #expect(initiate["content-type"] == "application/json")
        #expect(initiate["custom-provider-header"] == "provider-header-value")
        #expect(initiate["custom-request-header"] == "request-header-value")
        #expect(normalizeHeaders(requests[0].headers)["user-agent"]?.contains("ai-sdk-gladia/3.0.84") == true)
    }

    @Test func extractsTheTranscriptionTextAndGeneratesTheFullResponse() async throws {
        // Snapshot `should generate full response`, minus the injected timestamp.
        let result = try await transcribe(try gladiaModel(gladiaTransport()))
        let fixture = fixtureJSON(gladiaResultFixture)
        #expect(result.text == fixture["result"]?["transcription"]?["full_transcript"]?.stringValue)
        #expect(result.durationInSeconds == 36.74)
        #expect(result.language == "en")
        #expect(result.warnings == [])
        #expect(result.responseMetadata.modelID == "default")
        #expect(result.responseMetadata.id == nil)
        #expect(result.responseMetadata.timestamp != nil)
        #expect(result.segments.count == 11)
        #expect(result.segments.first == TranscriptionSegment(text: "Galileo was an American robotic space program that studied the planet Jupiter and its moons,", startSecond: 0.14, endSecond: 5.341))
        #expect(result.segments.last == TranscriptionSegment(text: "and became the first spacecraft to orbit Jupiter.", startSecond: 33.132, endSecond: 35.816))
        #expect(result.providerMetadata["gladia"] == fixture)
    }

    @Test func keepsUtterancesWithEmptyText() async throws {
        // The upstream schema accepts any string, and every utterance becomes a segment.
        let result = #"{"status":"done","result":{"metadata":{"audio_duration":1},"transcription":{"full_transcript":"","languages":[],"utterances":[{"start":0,"end":0.5,"text":""}]}}}"#
        let transcription = try await transcribe(try gladiaModel(gladiaTransport(result: result)))
        #expect(transcription.segments == [TranscriptionSegment(text: "", startSecond: 0, endSecond: 0.5)])
        #expect(transcription.language == nil)
    }

    @Test func includesTheGladiaErrorCodeInTheErrorMessage() async throws {
        var failed = try #require(fixtureJSON(gladiaResultFixture).objectValue)
        failed["status"] = "error"
        failed["error_code"] = 400
        failed["result"] = .null
        let body = String(decoding: try encodeJSONBody(.object(failed)), as: UTF8.self)
        await #expect(throws: AIError.invalidResponse(provider: "gladia.transcription", message: "Transcription job failed with error code 400")) {
            _ = try await transcribe(try gladiaModel(gladiaTransport(result: body)))
        }
    }

    @Test func includesResponseHeadersAndModelID() async throws {
        let result = try await transcribe(try gladiaModel(gladiaTransport(headers: ["x-request-id": "test-request-id", "x-ratelimit-remaining": "123"])))
        #expect(result.responseMetadata.modelID == "default")
        #expect(result.responseMetadata.headers["content-type"] == "application/json")
        #expect(result.responseMetadata.headers["x-request-id"] == "test-request-id")
        #expect(result.responseMetadata.headers["x-ratelimit-remaining"] == "123")
    }

    @Test(arguments: ["default", "solaria-1", "future-gladia-model"])
    func forwardsTranscriptionModelAliasID(modelID: String) async throws {
        let transport = gladiaTransport()
        let model = try gladiaModel(transport, modelID: modelID)
        let result = try await transcribe(model)
        #expect(model.modelID == modelID)
        #expect(result.responseMetadata.modelID == modelID)
        #expect(try await initiateBody(transport)["model"] == (modelID == "default" ? nil : .string(modelID)))
    }

    @Test func warnsAboutMissingSolaria3LanguageWithoutChangingTheRequest() async throws {
        let transport = gladiaTransport()
        let result = try await transcribe(try gladiaModel(transport, modelID: "solaria-3"))
        #expect(try await initiateBody(transport) == ["audio_url": .string(uploadedAudioURL), "model": "solaria-3"])
        #expect(result.warnings == [AIWarning(type: "other", message: "The \"solaria-3\" model supports a single language only. Pass exactly one language in languageConfig.languages; Gladia may reject the request.")])
    }

    @Test func warnsWhenPIIConfigurationIsSetWithoutEnablingRedaction() async throws {
        let transport = gladiaTransport()
        let result = try await transcribe(try gladiaModel(transport), gladia: ["piiRedactionConfig": ["processedTextType": "MASK"]])
        #expect(result.warnings == [AIWarning(type: "other", message: "piiRedactionConfig has no effect unless piiRedaction is true.")])
        #expect(try await initiateBody(transport)["pii_redaction_config"] == ["processed_text_type": "MASK"])
    }

    @Test func validatesPIIConfigurationBeforeUploadingAudio() async throws {
        let transport = gladiaTransport()
        await #expect(throws: AIError.self) {
            _ = try await transcribe(try gladiaModel(transport), gladia: ["piiRedactionConfig": ["processedTextType": "invalid"]])
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func forwardsCurrentTranslationAndAudioToLLMOptions() async throws {
        let transport = gladiaTransport()
        _ = try await transcribe(try gladiaModel(transport), gladia: [
            "translation": true,
            "translationConfig": ["targetLanguages": ["fr"], "model": "batch", "lipsync": false, "contextAdaptation": true, "context": "Science", "informal": false],
            "audioToLlm": true,
            "audioToLlmConfig": ["prompts": ["Summarize"], "model": "openai/gpt-5.4-nano"]
        ])
        let body = try await initiateBody(transport)
        #expect(body["translation_config"] == ["target_languages": ["fr"], "model": "batch", "lipsync": false, "context_adaptation": true, "context": "Science", "informal": false])
        #expect(body["audio_to_llm_config"] == ["prompts": ["Summarize"], "model": "openai/gpt-5.4-nano"])
    }

    @Test func parsesGladiaErrorMessage() async throws {
        // gladia-error.test.ts fixture shape; the message becomes the error text.
        let transport = RecordingTransport(response: AIHTTPResponse(
            statusCode: 429,
            headers: ["content-type": "application/json"],
            body: Data(#"{"error":{"message":"Resource has been exhausted (e.g. check quota).","code":429}}"#.utf8)
        ))
        await #expect(throws: AIError.apiCall(provider: "gladia.transcription", statusCode: 429, body: "Resource has been exhausted (e.g. check quota).", headers: ["content-type": "application/json"])) {
            _ = try await transcribe(try gladiaModel(transport))
        }
    }
}

@Suite("Gladia polling and legacy options (upstream)")
struct GladiaUpstreamPollingAndLegacyTests {
    @Test func pollsQueuedAndProcessingJobsUntilTheJobIsDone() async throws {
        let transport = RecordingTransport(responses: [
            jsonResponse(gladiaUploadFixture),
            jsonResponse(gladiaInitiateFixture),
            jsonResponse(#"{"status":"queued"}"#),
            jsonResponse(#"{"status":"processing"}"#),
            jsonResponse(gladiaResultFixture)
        ])
        let result = try await transcribe(try gladiaModel(transport, pollIntervalMs: 10))
        #expect(result.text == fixtureJSON(gladiaResultFixture)["result"]?["transcription"]?["full_transcript"]?.stringValue)
        #expect(await transport.requests().filter { $0.url.absoluteString == resultURL }.count == 3)
    }

    @Test func doesNotSendPollingSettingsToTheGladiaAPI() async throws {
        let transport = gladiaTransport()
        _ = try await transcribe(try gladiaModel(transport), gladia: ["pollIntervalMs": 1, "pollTimeoutMs": 1000])
        let body = try await initiateBody(transport)
        #expect(body["pollIntervalMs"] == nil)
        #expect(body["pollTimeoutMs"] == nil)
    }

    @Test func throwsForInvalidPerCallPollingSettings() async throws {
        let transport = gladiaTransport()
        await #expect(throws: AIError.self) {
            _ = try await transcribe(try gladiaModel(transport), gladia: ["pollTimeoutMs": 0])
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func stopsBeforeTheFirstRequestWhenTheSignalIsAlreadyAborted() async throws {
        let transport = gladiaTransport()
        let controller = AIAbortController()
        controller.abort(reason: "The operation timed out.", reasonName: "TimeoutError")
        await #expect(throws: AIAbortError(reason: "The operation timed out.", reasonName: "TimeoutError")) {
            _ = try await gladiaModel(transport).transcribe(AudioTranscriptionRequest(audio: Data([1]), mimeType: "audio/mp3", abortSignal: controller.signal))
        }
        #expect(await transport.requests().filter { $0.url.absoluteString == resultURL }.isEmpty)
    }

    @Test(arguments: [0.0, -1, 1.5, .nan, .infinity])
    func rejectsInvalidProviderPollingSettings(value: Double) async throws {
        // Swift settings are `Int?`; non-integers are covered through provider options.
        if let integer = Int(exactly: value) {
            #expect(throws: AIError.self) { _ = try GladiaProvider(configuration: .init(apiKey: "key", pollIntervalMs: integer)) }
            #expect(throws: AIError.self) { _ = try GladiaProvider(configuration: .init(apiKey: "key", pollTimeoutMs: integer)) }
        }
        let transport = gladiaTransport()
        let number: JSONValue = value.isFinite ? .number(value) : .string("\(value)")
        for key in ["pollIntervalMs", "pollTimeoutMs"] {
            await #expect(throws: AIError.self) {
                _ = try await transcribe(try gladiaModel(transport), gladia: .object([key: number]))
            }
        }
    }

    @Test(arguments: [
        ("contextPrompt", JSONValue.object(["contextPrompt": "context"])),
        ("moderation", ["moderation": true]),
        ("chapterization", ["chapterization": true]),
        ("nameConsistency", ["nameConsistency": true]),
        ("structuredDataExtraction", ["structuredDataExtraction": true]),
        ("structuredDataExtractionConfig", ["structuredDataExtractionConfig": ["classes": ["test"]]]),
        ("displayMode", ["displayMode": false]),
        ("diarizationConfig.enhanced", ["diarizationConfig": ["enhanced": true]])
    ] as [(String, JSONValue)])
    func warnsWhenUnsupportedOptionIsIgnored(feature: String, options: JSONValue) async throws {
        let transport = gladiaTransport()
        let result = try await transcribe(try gladiaModel(transport), gladia: options)
        #expect(result.warnings == [AIWarning(type: "unsupported", feature: feature, message: "No longer supported by the Gladia v2 pre-recorded API; ignored.")])
        let expected: JSONValue = feature == "diarizationConfig.enhanced"
            ? ["audio_url": .string(uploadedAudioURL), "diarization_config": [:]]
            : ["audio_url": .string(uploadedAudioURL)]
        #expect(try await initiateBody(transport) == expected)
    }

    @Test(arguments: [
        ("language", JSONValue.object(["language": "en"])),
        ("detectLanguage", ["detectLanguage": true]),
        ("enableCodeSwitching", ["enableCodeSwitching": false]),
        ("codeSwitchingConfig", ["codeSwitchingConfig": ["languages": ["en"]]])
    ] as [(String, JSONValue)])
    func warnsWhenTranslatingDeprecatedSetting(setting: String, options: JSONValue) async throws {
        let result = try await transcribe(try gladiaModel(gladiaTransport()), gladia: options)
        #expect(result.warnings.contains(AIWarning(type: "deprecated", setting: setting, message: "Use languageConfig instead.")))
    }

    @Test func warnsWhenExplicitLanguageConfigurationOverridesLegacyFields() async throws {
        let transport = gladiaTransport()
        let result = try await transcribe(try gladiaModel(transport), gladia: ["languageConfig": ["codeSwitching": false], "language": "en"])
        #expect(try await initiateBody(transport)["language_config"] == ["code_switching": false])
        #expect(result.warnings.contains(AIWarning(type: "deprecated", setting: "language", message: "Ignored because languageConfig is provided; remove this deprecated option.")))
    }

    @Test func filtersInvalidLegacyVocabularyEntriesWithoutCrashing() async throws {
        let transport = gladiaTransport()
        let result = try await transcribe(try gladiaModel(transport), gladia: ["customVocabulary": [
            "Gladia",
            ["value": "AI SDK", "intensity": 0.5],
            .null,
            42,
            [:],
            ["value": 3],
            ["value": "Invalid intensity", "intensity": "high"],
            ["value": "Invalid pronunciations", "pronunciations": [3]],
            ["value": "Invalid language", "language": 42]
        ]])
        #expect(try await initiateBody(transport)["custom_vocabulary_config"]?["vocabulary"] == ["Gladia", ["value": "AI SDK", "intensity": 0.5]])
        #expect(result.warnings == [
            AIWarning(type: "deprecated", setting: "customVocabulary", message: "Use customVocabulary: true with customVocabularyConfig instead of an array."),
            AIWarning(type: "other", message: "Invalid customVocabulary entries were ignored; use strings or objects with a string value and correctly typed optional fields.")
        ])
    }

    @Test(arguments: [JSONValue.array([JSONValue]()), [.null, ["value": "Invalid", "intensity": "high"]]] as [JSONValue])
    func omitsVocabularyConfigurationWhenNoValidLegacyEntriesRemain(customVocabulary: JSONValue) async throws {
        let transport = gladiaTransport()
        _ = try await transcribe(try gladiaModel(transport), gladia: ["customVocabulary": customVocabulary])
        let body = try await initiateBody(transport)
        #expect(body["custom_vocabulary"] == nil)
        #expect(body["custom_vocabulary_config"] == nil)
    }

    @Test func warnsWhenAnExplicitVocabularyOverridesTheLegacyArray() async throws {
        let transport = gladiaTransport()
        let result = try await transcribe(try gladiaModel(transport), gladia: [
            "customVocabulary": ["Legacy"],
            "customVocabularyConfig": ["vocabulary": ["Modern"], "defaultIntensity": 0.4]
        ])
        #expect(try await initiateBody(transport)["custom_vocabulary_config"] == ["vocabulary": ["Modern"], "default_intensity": 0.4])
        #expect(result.warnings.contains(AIWarning(type: "other", message: "customVocabularyConfig.vocabulary overrides the deprecated customVocabulary array.")))
    }
}
