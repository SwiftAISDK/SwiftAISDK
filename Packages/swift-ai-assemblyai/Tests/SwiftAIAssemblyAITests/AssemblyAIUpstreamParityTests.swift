@testable import SwiftAIAssemblyAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translated from packages/assemblyai/src/assemblyai-transcription-model.test.ts
// and assemblyai-error.test.ts (cases not already covered by AssemblyAIProviderTests).

private let transcriptID = "9ea68fd3-f953-42c1-9742-976c447fb463"
private let uploadBody = #"{"id":"9ea68fd3-f953-42c1-9742-976c447fb463","upload_url":"https://storage.assemblyai.com/mock-upload-url"}"#
private let submitBody = #"{"id":"9ea68fd3-f953-42c1-9742-976c447fb463","status":"queued"}"#
private let completedBody = """
{"id":"9ea68fd3-f953-42c1-9742-976c447fb463","status":"completed","language_code":"en_us","text":"Hello, world!",
 "words":[{"confidence":0.97465,"start":250,"end":650,"text":"Hello,","channel":"channel","speaker":"speaker"},
          {"confidence":0.99999,"start":730,"end":1022,"text":"world","channel":"channel","speaker":"speaker"}],
 "audio_duration":281,"error":"error"}
"""

private func assemblyTransport(final: String = completedBody, submit: AIHTTPResponse? = nil, headers: [String: String] = [:]) -> RecordingTransport {
    RecordingTransport(responses: [jsonResponse(uploadBody), submit ?? jsonResponse(submitBody), jsonResponse(final, headers: headers)])
}

private func assemblyModel(_ transport: RecordingTransport, _ modelID: String = "best", headers: [String: String] = [:]) throws -> any TranscriptionModel {
    try AIProviders.assemblyAI(configuration: AssemblyAIProviderSettings(apiKey: "test-api-key", headers: headers, transport: transport)).transcriptionModel(modelID)
}

private func transcribe(_ model: any TranscriptionModel, options: JSONValue? = nil, headers: [String: String] = [:]) async throws -> TranscriptionResult {
    try await model.transcribe(AudioTranscriptionRequest(
        audio: Data([1, 2, 3]),
        mimeType: "audio/wav",
        providerOptions: options.map { ["assemblyai": $0] } ?? [:],
        headers: headers
    ))
}

@Suite("AssemblyAI doGenerate (upstream)")
struct AssemblyAIUpstreamParityTests {
    @Test func warnsWhenDeprecatedWordBoostAndBoostParamAreUsed() async throws {
        let result = try await transcribe(try assemblyModel(assemblyTransport(), "universal-3-5-pro"), options: ["wordBoost": ["Vercel"], "boostParam": "high"])
        let warning = try #require(result.warnings.first { $0.type == "deprecated" })
        #expect(warning.setting == "wordBoost, boostParam")
        #expect(warning.message?.contains("keytermsPrompt") == true)
    }

    @Test func attributesTheDeprecationWarningToBoostParamWhenOnlyBoostParamIsSet() async throws {
        let result = try await transcribe(try assemblyModel(assemblyTransport(), "universal-3-5-pro"), options: ["boostParam": "high"])
        #expect(result.warnings.first { $0.type == "deprecated" }?.setting == "boostParam")
    }

    @Test func warnsWhenRedactPiiDependentOptionsAreSetWithoutRedactPii() async throws {
        let result = try await transcribe(try assemblyModel(assemblyTransport(), "universal-3-5-pro"), options: ["redactStaticEntities": ["TOOL": ["Vercel"]]])
        #expect(result.warnings.contains { $0.type == "other" && $0.message?.contains("redactPii") == true })
    }

    @Test func warnsWhenRedactPiiAudioOptionsIsSetWithoutRedactPiiAudio() async throws {
        let result = try await transcribe(try assemblyModel(assemblyTransport(), "universal-3-5-pro"), options: [
            "redactPii": true,
            "redactPiiAudioOptions": ["overrideAudioRedactionMethod": "silence"]
        ])
        #expect(result.warnings.contains { $0.type == "other" && $0.message?.contains("redactPiiAudio") == true })
    }

    @Test func warnsWhenLanguageCodeAndLanguageDetectionAreCombined() async throws {
        let result = try await transcribe(try assemblyModel(assemblyTransport(), "universal-3-5-pro"), options: ["languageCode": "en", "languageDetection": true])
        #expect(result.warnings.contains { $0.type == "other" && $0.message?.contains("languageDetection") == true })
    }

    @Test func reportsSegmentTimingsInSeconds() async throws {
        let result = try await transcribe(try assemblyModel(assemblyTransport()))
        #expect(result.segments.first == TranscriptionSegment(text: "Hello,", startSecond: 0.25, endSecond: 0.65))
        #expect(result.text == "Hello, world!")
    }

    @Test func keepsEmptyWordsAndDerivesDurationFromTheLastWord() async throws {
        // Upstream maps every word and uses `words.at(-1).end / 1000` when audio_duration is absent.
        let final = #"{"id":"t","status":"completed","text":"","words":[{"start":0,"end":3000,"text":"a"},{"start":1000,"end":2000,"text":""}]}"#
        let result = try await transcribe(try assemblyModel(assemblyTransport(final: final)))
        #expect(result.segments == [
            TranscriptionSegment(text: "a", startSecond: 0, endSecond: 3),
            TranscriptionSegment(text: "", startSecond: 1, endSecond: 2)
        ])
        #expect(result.durationInSeconds == 2)
    }

    @Test func passesHeaders() async throws {
        let transport = assemblyTransport()
        _ = try await transcribe(
            try assemblyModel(transport, headers: ["Custom-Provider-Header": "provider-header-value"]),
            headers: ["Custom-Request-Header": "request-header-value"]
        )
        let upload = normalizeHeaders(try #require(await transport.requests().first).headers)
        #expect(upload["authorization"] == "test-api-key")
        #expect(upload["content-type"] == "application/octet-stream")
        #expect(upload["custom-provider-header"] == "provider-header-value")
        #expect(upload["custom-request-header"] == "request-header-value")
        #expect(upload["user-agent"]?.contains("ai-sdk-assemblyai/3.0.82") == true)
    }

    @Test func surfacesAFlatErrorMessageFromTheSubmitCall() async throws {
        let submit = AIHTTPResponse(statusCode: 401, headers: ["content-type": "application/json"], body: Data(#"{"error":"Invalid API key"}"#.utf8))
        await #expect(throws: AIError.apiCall(provider: "assemblyai.transcription", statusCode: 401, body: "Invalid API key", headers: ["content-type": "application/json"])) {
            _ = try await transcribe(try assemblyModel(assemblyTransport(submit: submit)))
        }
    }

    @Test(arguments: [
        (#"{"error":"format_text must be a Boolean","status":"error"}"#, 400, "format_text must be a Boolean"),
        (#"{"error":{"message":"Resource has been exhausted (e.g. check quota).","code":429}}"#, 429, "Resource has been exhausted (e.g. check quota).")
    ])
    func usesFlatAndNestedErrorMessages(body: String, status: Int, message: String) async throws {
        let submit = AIHTTPResponse(statusCode: status, body: Data(body.utf8))
        await #expect(throws: AIError.apiCall(provider: "assemblyai.transcription", statusCode: status, body: message)) {
            _ = try await transcribe(try assemblyModel(assemblyTransport(submit: submit)))
        }
    }

    @Test func includesResponseDataWithTimestampModelIDAndHeaders() async throws {
        let before = Date()
        let result = try await transcribe(try assemblyModel(assemblyTransport(headers: ["x-request-id": "test-request-id", "x-ratelimit-remaining": "123"])))
        #expect(result.responseMetadata.modelID == "best")
        #expect(result.responseMetadata.id == nil)
        #expect(try #require(result.responseMetadata.timestamp) >= before.addingTimeInterval(-1))
        #expect(result.responseMetadata.headers["content-type"] == "application/json")
        #expect(result.responseMetadata.headers["x-request-id"] == "test-request-id")
        #expect(result.responseMetadata.headers["x-ratelimit-remaining"] == "123")
        #expect(result.responseMetadata.body?["id"]?.stringValue == transcriptID)
    }
}
