@testable import SwiftAILMNT
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// @ai-sdk/lmnt ships no upstream tests at the reviewed ref; these cases are
// derived from packages/lmnt/src/lmnt-speech-model.ts and lmnt-provider.ts.

private func lmntModel(_ transport: RecordingTransport, headers: [String: String] = [:]) throws -> any SpeechModel {
    try AIProviders.lmnt(configuration: LMNTProviderSettings(apiKey: "test-api-key", headers: headers, transport: transport))
        .speechModel("aurora")
}

private func lmntAudio() -> AIHTTPResponse {
    AIHTTPResponse(statusCode: 200, headers: ["content-type": "audio/mp3"], body: Data(repeating: 0, count: 8))
}

@Suite("LMNT speech source parity")
struct LMNTSourceParityTests {
    @Test func defaultBodyUsesAvaVoiceMP3AndOmitsUnsetSpeed() async throws {
        let transport = RecordingTransport(response: lmntAudio())
        let result = try await lmntModel(transport).speak(SpeechRequest(text: "Hello"))

        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body == .object([
            "model": .string("aurora"),
            "text": .string("Hello"),
            "voice": .string("ava"),
            "response_format": .string("mp3")
        ]))
        #expect(result.warnings == [])
    }

    @Test func emptyLanguageIsNotSent() async throws {
        // `if (language)` skips an empty string.
        let transport = RecordingTransport(response: lmntAudio())
        _ = try await lmntModel(transport).speak(SpeechRequest(text: "Hello", language: ""))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["language"] == nil)
    }

    @Test func emptyOutputFormatUsesMP3WithoutWarning() async throws {
        // `if (outputFormat)` skips an empty string.
        let transport = RecordingTransport(response: lmntAudio())
        let result = try await lmntModel(transport).speak(SpeechRequest(text: "Hello", format: ""))
        #expect(result.warnings == [])
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["response_format"]?.stringValue == "mp3")
    }

    @Test func emptyProviderOptionsApplySchemaDefaultsIncludingSpeed() async throws {
        // zod defaults fill sampleRate/speed/conversational/topP/temperature and
        // override the call-level speed once `providerOptions.lmnt` is present.
        let transport = RecordingTransport(response: lmntAudio())
        _ = try await lmntModel(transport).speak(SpeechRequest(text: "Hello", speed: 1.5, providerOptions: ["lmnt": .object([:])]))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body == .object([
            "model": .string("aurora"),
            "text": .string("Hello"),
            "voice": .string("ava"),
            "response_format": .string("mp3"),
            "speed": .number(1),
            "conversational": .bool(false),
            "sample_rate": .number(24_000),
            "temperature": .number(1),
            "top_p": .number(1)
        ]))
    }

    @Test func settingsAPIKeyHeaderOverridesKeyInAnyCase() async throws {
        let transport = RecordingTransport(response: lmntAudio())
        _ = try await lmntModel(transport, headers: ["X-Api-Key": "override-key"]).speak(SpeechRequest(text: "Hello"))
        let headers = try #require(await transport.requests().first).headers
        #expect(headers.filter { $0.key.caseInsensitiveCompare("x-api-key") == .orderedSame }.map(\.value) == ["override-key"])
        #expect(normalizeHeaders(headers)["user-agent"]?.contains("ai-sdk/lmnt/3.0.36") == true)
    }
}
