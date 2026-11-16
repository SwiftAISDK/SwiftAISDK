@testable import SwiftAIHume
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translated from packages/hume/src/hume-speech-model.test.ts and hume-error.test.ts.

private func humeAudioResponse(format: String = "mp3", headers: [String: String] = [:]) -> AIHTTPResponse {
    AIHTTPResponse(
        statusCode: 200,
        headers: ["content-type": "audio/\(format)"].mergingHeaders(headers),
        body: Data(repeating: 0, count: 100)
    )
}

private func humeModel(_ transport: RecordingTransport, headers: [String: String] = [:]) throws -> any SpeechModel {
    try AIProviders.hume(configuration: HumeProviderSettings(apiKey: "test-api-key", headers: headers, transport: transport)).speech()
}

@Suite("Hume speech doGenerate (upstream)")
struct HumeUpstreamSpeechTests {
    @Test func passesTheModelAndText() async throws {
        let transport = RecordingTransport(response: humeAudioResponse())
        _ = try await humeModel(transport).speak(SpeechRequest(text: "Hello from the AI SDK!"))

        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body == .object([
            "utterances": .array([.object([
                "text": .string("Hello from the AI SDK!"),
                "voice": .object([
                    "id": .string("d8ab67c6-953d-4bd8-9370-8fa53a0f1453"),
                    "provider": .string("HUME_AI")
                ])
            ])]),
            "format": .object(["type": .string("mp3")])
        ]))
    }

    @Test func passesHeaders() async throws {
        let transport = RecordingTransport(response: humeAudioResponse())
        _ = try await humeModel(transport, headers: ["Custom-Provider-Header": "provider-header-value"]).speak(SpeechRequest(
            text: "Hello from the AI SDK!",
            headers: ["Custom-Request-Header": "request-header-value"]
        ))

        let headers = normalizeHeaders(try #require(await transport.requests().first).headers)
        #expect(headers["x-hume-api-key"] == "test-api-key")
        #expect(headers["content-type"] == "application/json")
        #expect(headers["custom-provider-header"] == "provider-header-value")
        #expect(headers["custom-request-header"] == "request-header-value")
        #expect(headers["user-agent"]?.contains("ai-sdk-hume/3.0.81") == true)
    }

    @Test func settingsHeaderOverridesTheAPIKeyHeaderInAnyCase() async throws {
        // Upstream spreads `options.headers` after `X-Hume-Api-Key`, so a caller value wins.
        let transport = RecordingTransport(response: humeAudioResponse())
        _ = try await humeModel(transport, headers: ["X-Hume-Api-Key": "override-key"]).speak(SpeechRequest(text: "Hello"))

        let headers = try #require(await transport.requests().first).headers
        #expect(headers.filter { $0.key.caseInsensitiveCompare("x-hume-api-key") == .orderedSame }.map(\.value) == ["override-key"])
    }

    @Test func passesOptions() async throws {
        let transport = RecordingTransport(response: humeAudioResponse())
        _ = try await humeModel(transport).speak(SpeechRequest(
            text: "Hello from the AI SDK!",
            voice: "test-voice",
            format: "mp3",
            speed: 1.5
        ))

        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body == .object([
            "utterances": .array([.object([
                "text": .string("Hello from the AI SDK!"),
                "voice": .object(["id": .string("test-voice"), "provider": .string("HUME_AI")]),
                "speed": .number(1.5)
            ])]),
            "format": .object(["type": .string("mp3")])
        ]))
    }

    @Test func returnsAudioDataWithCorrectContentType() async throws {
        let transport = RecordingTransport(response: humeAudioResponse(headers: [
            "x-request-id": "test-request-id",
            "x-ratelimit-remaining": "123"
        ]))
        let result = try await humeModel(transport).speak(SpeechRequest(text: "Hello from the AI SDK!", format: "mp3"))
        #expect(result.audio == Data(repeating: 0, count: 100))
    }

    @Test func includesResponseDataWithTimestampModelIDAndHeaders() async throws {
        // Swift cannot inject `currentDate`; assert a fresh timestamp instead of `new Date(0)`.
        let transport = RecordingTransport(response: humeAudioResponse(headers: [
            "x-request-id": "test-request-id",
            "x-ratelimit-remaining": "123"
        ]))
        let before = Date()
        let result = try await humeModel(transport).speak(SpeechRequest(text: "Hello from the AI SDK!"))

        #expect(result.responseMetadata.modelID == "")
        #expect(try #require(result.responseMetadata.timestamp) >= before.addingTimeInterval(-1))
        #expect(result.responseMetadata.headers["content-type"] == "audio/mp3")
        #expect(result.responseMetadata.headers["x-request-id"] == "test-request-id")
        #expect(result.responseMetadata.headers["x-ratelimit-remaining"] == "123")
    }

    @Test func handlesDifferentAudioFormats() async throws {
        for format in ["mp3", "pcm", "wav"] {
            let transport = RecordingTransport(response: humeAudioResponse(format: format))
            let result = try await humeModel(transport).speak(SpeechRequest(text: "Hello from the AI SDK!"))
            #expect(result.audio == Data(repeating: 0, count: 100))
        }
    }

    @Test func includesWarningsIfAnyAreGenerated() async throws {
        let transport = RecordingTransport(response: humeAudioResponse())
        let result = try await humeModel(transport).speak(SpeechRequest(text: "Hello from the AI SDK!"))
        #expect(result.warnings == [])
    }

    @Test func emptyOutputFormatFallsBackToMP3WithoutWarning() async throws {
        // Upstream guards the format check with `if (outputFormat)`.
        let transport = RecordingTransport(response: humeAudioResponse())
        let result = try await humeModel(transport).speak(SpeechRequest(text: "Hello", format: ""))
        #expect(result.warnings == [])
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["format"] == .object(["type": .string("mp3")]))
    }

    @Test func parsesHumeResourceExhaustedError() async throws {
        let message = "{\n  \"error\": {\n    \"code\": 429,\n    \"message\": \"Resource has been exhausted (e.g. check quota).\",\n    \"status\": \"RESOURCE_EXHAUSTED\"\n  }\n}\n"
        let payload = try JSONSerialization.data(withJSONObject: ["error": ["message": message, "code": 429]])
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 429, headers: ["content-type": "application/json"], body: payload))

        await #expect(throws: AIError.apiCall(
            provider: "hume.speech",
            statusCode: 429,
            body: message,
            headers: ["content-type": "application/json"]
        )) {
            _ = try await humeModel(transport).speak(SpeechRequest(text: "Hello"))
        }
    }
}
