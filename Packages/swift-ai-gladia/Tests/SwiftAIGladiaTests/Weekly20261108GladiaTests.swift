@testable import SwiftAIGladia
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Foundation
import Testing

private let weeklyGladiaDone = #"{"status":"done","result":{"metadata":{"audio_duration":2},"transcription":{"full_transcript":"Hi","languages":["en"],"utterances":[{"start":0,"end":2,"text":"Hi","words":"future-shape","speaker":false}]},"audio_to_llm":{"future":true},"translation":17}}"#
private func weeklyGladiaTransport(_ done: String = weeklyGladiaDone) -> RecordingTransport { .init(responses: [jsonResponse(#"{"result_url":"https://api.gladia.io/v2/pre-recorded/job"}"#), jsonResponse(done)]) }
private func weeklyGladiaURL(_ options: [String: JSONValue], modelID: String = "solaria-3", done: String = weeklyGladiaDone) async throws -> (TranscriptionResult, JSONValue, [AIHTTPRequest]) {
    let transport = weeklyGladiaTransport(done)
    let provider = try GladiaProvider(configuration: .init(apiKey: "key", transport: transport, pollIntervalMs: 2))
    let result = try #require(try await provider.transcription(modelID).transcribeFromURL(.init(audio: URL(string: "https://audio.test/input.wav")!, providerOptions: ["gladia": .object(options)], headers: ["X-Gladia-Version": "custom-version"])))
    let requests = await transport.requests()
    return (result, try decodeJSONBody(requests[0].body!), requests)
}

@Test func weekly20261108GladiaCurrentOptionsURLModelHeadersAndLooseMetadata() async throws {
    let (result, body, requests) = try await weeklyGladiaURL([
        "languageConfig": .object(["languages": .array(["en"]), "codeSwitching": false]),
        "piiRedaction": true, "piiRedactionConfig": .object(["entityTypes": .array(["EMAIL"]), "processedTextType": "MASK"]),
        "translationConfig": .object(["targetLanguages": .array(["fr"]), "model": "batch", "lipsync": true, "contextAdaptation": true, "context": "Context", "informal": false]),
        "audioToLlmConfig": .object(["prompts": .array(["Summary"]), "model": "custom-model"]),
        "pollIntervalMs": 1, "pollTimeoutMs": 1000
    ])
    #expect(requests.count == 2); #expect(requests[0].url.path == "/v2/pre-recorded")
    #expect(body["audio_url"] == "https://audio.test/input.wav"); #expect(body["model"] == "solaria-3")
    #expect(body["language_config"] == .object(["languages": .array(["en"]), "code_switching": false]))
    #expect(body["pii_redaction"] == true); #expect(body["pii_redaction_config"]?["processed_text_type"] == "MASK")
    #expect(body["translation_config"]?["model"] == "batch"); #expect(body["translation_config"]?["context_adaptation"] == true)
    #expect(body["audio_to_llm_config"]?["model"] == "custom-model")
    #expect(body["pollIntervalMs"] == nil); #expect(body["poll_interval_ms"] == nil); #expect(body["pollTimeoutMs"] == nil)
    #expect(requests[0].headers["X-Gladia-Version"] == "custom-version")
    #expect(result.text == "Hi"); #expect(result.warnings.isEmpty)
    #expect(result.providerMetadata["gladia"]?["result"]?["translation"] == 17)
    #expect(result.providerMetadata["gladia"]?["result"]?["transcription"]?["utterances"]?[0]?["words"] == "future-shape")
}

@Test(arguments: [
    (JSONValue.object(["language": "en"]), JSONValue.object(["languages": .array(["en"])])),
    (.object(["detectLanguage": true]), .object(["languages": .array([JSONValue]())])),
    (.object(["language": "en", "enableCodeSwitching": true, "codeSwitchingConfig": .object(["languages": .array(["fr", "en"])])]), .object(["languages": .array(["fr", "en"]), "code_switching": true])),
    (.object(["language": "en", "languageConfig": .object([:])]), .object([:])),
    (.object(["enableCodeSwitching": false, "codeSwitchingConfig": .object(["languages": .array(["fr"])])]), .object(["code_switching": false]))
])
func weekly20261108GladiaLegacyLanguageResolution(_ input: (JSONValue, JSONValue)) async throws {
    let (result, body, _) = try await weeklyGladiaURL(input.0.objectValue!, modelID: "default")
    #expect(body["model"] == nil); #expect(body["language_config"] == input.1)
    #expect(body["language"] == nil); #expect(body["enable_code_switching"] == nil)
    #expect(result.warnings.contains { $0.type == "deprecated" })
}

@Test func weekly20261108GladiaDeprecatedVocabularyAndUnsupportedWarnings() async throws {
    let (result, body, _) = try await weeklyGladiaURL([
        "customVocabulary": .array(["Gladia", .number(1), .null, .object(["value": "invalid", "intensity": .number(.infinity)]), .object(["value": "Swift", "pronunciations": .array(["swift"])])]),
        "contextPrompt": "legacy", "moderation": false, "chapterization": true, "nameConsistency": true,
        "structuredDataExtraction": true, "structuredDataExtractionConfig": .object(["classes": .array(["x"])]), "displayMode": true,
        "diarizationConfig": .object(["enhanced": true, "numberOfSpeakers": 2]),
        "languageConfig": .object(["languages": .array(["en", "fr"]), "codeSwitching": true]),
        "piiRedactionConfig": .object([:])
    ])
    #expect(body["custom_vocabulary"] == true); #expect(body["custom_vocabulary_config"]?["vocabulary"]?.arrayValue?.count == 2)
    #expect(body["diarization_config"]?["enhanced"] == nil)
    #expect(body["context_prompt"] == nil); #expect(body["moderation"] == nil)
    #expect(result.warnings.filter { $0.type == "unsupported" }.count == 8)
    #expect(result.warnings.contains { $0.setting == "customVocabulary" })
    #expect(result.warnings.contains { $0.message?.contains("Invalid customVocabulary") == true })
    #expect(result.warnings.contains { $0.message?.contains("no effect") == true })
    #expect(result.warnings.filter { $0.message?.contains("solaria-3") == true }.count == 2)
    let (_, overridden, _) = try await weeklyGladiaURL(["customVocabulary": .array(["old"]), "customVocabularyConfig": .object(["vocabulary": .array(["new"])])], modelID: "default")
    #expect(overridden["custom_vocabulary_config"]?["vocabulary"] == .array(["new"]))
}

@Test(arguments: [JSONValue.object(["piiRedactionConfig": .object(["processedTextType": "INVALID"])]), .object(["languageConfig": .null]), .object(["pollIntervalMs": 0]), .object(["pollIntervalMs": .number(.infinity)]), .object(["pollTimeoutMs": 1.5]), .object(["piiRedactionConfig": .object(["entityTypes": .array([1])])])])
func weekly20261108GladiaValidationBeforeUpload(_ input: JSONValue) async throws {
    let transport = RecordingTransport(response: jsonResponse("{}")); let provider = try GladiaProvider(configuration: .init(apiKey: "key", transport: transport))
    await #expect(throws: AIError.self) { _ = try await provider.transcriptionModel().transcribe(.init(audio: Data([0]), providerOptions: ["gladia": input])) }
    #expect(await transport.requests().isEmpty)
}

@Test func weekly20261108GladiaPollingPrecedenceTimeoutAbortAndErrors() async throws {
    let transport = RecordingTransport(responses: [jsonResponse(#"{"result_url":"https://api.gladia.io/job"}"#), jsonResponse(#"{"status":"queued"}"#), jsonResponse(#"{"status":"processing"}"#), jsonResponse(weeklyGladiaDone)])
    let provider = try GladiaProvider(configuration: .init(apiKey: "key", transport: transport, pollIntervalMs: 10000, pollTimeoutMs: 1))
    _ = try await provider.transcriptionModel().transcribeFromURL(.init(audio: URL(string: "https://audio.test/audio.wav")!, providerOptions: ["gladia": .object(["pollIntervalMs": 1, "pollTimeoutMs": 1000])]))
    #expect(await transport.requests().count == 4)
    let timeout = RecordingTransport(responses: [jsonResponse(#"{"result_url":"https://api.gladia.io/job"}"#), jsonResponse(#"{"status":"queued"}"#)])
    let timed = try GladiaProvider(configuration: .init(apiKey: "key", transport: timeout, pollIntervalMs: 2, pollTimeoutMs: 1))
    await #expect(throws: AIError.self) { _ = try await timed.transcriptionModel().transcribeFromURL(.init(audio: URL(string: "https://audio.test/audio.wav")!)) }
    #expect(await timeout.requests().count == 2)
    let (failed, _, _) = try await weeklyGladiaURL([:], modelID: "default")
    #expect(failed.text == "Hi")
    await #expect(throws: AIError.invalidResponse(provider: "gladia.transcription", message: "Transcription job failed with error code 503")) { _ = try await weeklyGladiaURL([:], done: #"{"status":"error","error_code":503}"#) }
    let abort = AIAbortController(); abort.abort(reason: "stop")
    await #expect(throws: AIAbortError.self) { _ = try await provider.transcriptionModel().transcribeFromURL(.init(audio: URL(string: "https://audio.test/a")!, abortSignal: abort.signal)) }
    #expect(await transport.requests().count == 4) // pre-abort performs no initiation or poll
    #expect(throws: AIError.self) { _ = try GladiaProvider(configuration: .init(apiKey: "key", pollTimeoutMs: 0)) }
    let directTransport = RecordingTransport(response: jsonResponse("{}"))
    let http = AIProviderHTTPClient(providerID: "gladia", transport: directTransport, url: { _, path in URL(string: "https://api.gladia.io\(path)")! })
    let direct = GladiaTranscriptionModel(modelID: "default", config: .init(http: http, baseURL: "https://api.gladia.io", pollIntervalMs: -1))
    await #expect(throws: AIError.self) { _ = try await direct.transcribe(.init(audio: Data([0]))) }
    #expect(await directTransport.requests().isEmpty)
}

@Test func weekly20261108GladiaAbortsPollingWaitAndRejectsNonHTTPSource() async throws {
    let transport = RecordingTransport(responses: [jsonResponse(#"{"result_url":"https://api.gladia.io/job"}"#), jsonResponse(#"{"status":"queued"}"#)])
    let provider = try GladiaProvider(configuration: .init(apiKey: "key", transport: transport, pollIntervalMs: 1000))
    let abort = AIAbortController()
    let operation = Task { try await provider.transcriptionModel().transcribeFromURL(.init(audio: URL(string: "https://audio.test/a.wav")!, abortSignal: abort.signal)) }
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while await transport.requests().count < 2 { guard ContinuousClock.now < deadline else { throw AIError.timeout(durationNanoseconds: 3_000_000_000) }; try await Task.sleep(nanoseconds: 1_000_000) }
    abort.abort(reason: "custom stop", reasonName: "TimeoutError")
    await #expect(throws: AIAbortError(reason: "custom stop", reasonName: "TimeoutError")) { _ = try await operation.value }
    #expect(await transport.requests().count == 2)
    #expect(await transport.requests().first?.headers["x-gladia-version"] == "ai-sdk/3.0.77")
    await #expect(throws: AIError.self) { _ = try await provider.transcriptionModel().transcribeFromURL(.init(audio: URL(string: "file:///audio.wav")!)) }
}
