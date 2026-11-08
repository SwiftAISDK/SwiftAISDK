import Foundation
import Testing
@testable import SwiftAICartesia
import SwiftAIProvider
import SwiftAITransport

@Suite("Weekly20261108 Cartesia speech options")
struct Weekly20261108SpeechTests {
    @Test(arguments: [0.5, 2.0])
    func volumeBoundsAndOtherGenerationSettingsSurviveInvalidGenericSpeed(_ volume: Double) async throws {
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 200, body: Data("audio".utf8)))
        let provider = try CartesiaProvider(settings: .init(apiKey: "key", transport: transport))
        let result = try await provider.speechModel("sonic-3.6").speak(.init(
            text: "Hello", voice: "voice", speed: 2,
            providerOptions: ["cartesia": ["volume": .number(volume), "emotion": "determined"]]
        ))
        let request = try #require(await transport.requests().first)
        let body = try JSONDecoder().decode(JSONValue.self, from: #require(request.body))
        #expect(body["generation_config"] == ["volume": .number(volume), "emotion": "determined"])
        #expect(result.warnings.contains { $0.feature == "speed" })
    }

    @Test(arguments: [
        JSONValue.object(["volume": 0.49]), ["volume": 2.01], ["volume": .null],
        ["emotion": "unknown"], ["emotion": .null], ["locale": .null],
        ["normalization": 1], ["pronunciationDictionaryId": false]
    ])
    func invalidNewSpeechOptionsStopBeforeHTTP(_ options: JSONValue) async throws {
        let transport = RecordingTransport(responses: [])
        let provider = try CartesiaProvider(settings: .init(apiKey: "key", transport: transport))
        await #expect(throws: AIError.self) {
            try await provider.speechModel("sonic-3.6").speak(.init(text: "Hi", voice: "voice", providerOptions: ["cartesia": options]))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func localeOverridesGenericLanguageAndGenerationOptionsMerge() async throws {
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 200, body: Data("audio".utf8)))
        let provider = try CartesiaProvider(settings: .init(apiKey: "key", transport: transport))
        let result = try await provider.speechModel("sonic-3.6").speak(.init(text: "Hello", voice: "voice", speed: 1.1, language: "en", providerOptions: ["cartesia": ["locale": "en-GB", "volume": 1.5, "emotion": "happy", "normalization": "auto", "pronunciationDictionaryId": "dictionary"]]))
        let request = try #require(await transport.requests().first)
        let body = try JSONDecoder().decode(JSONValue.self, from: #require(request.body))
        #expect(body["locale"] == "en-GB")
        #expect(body["language"] == nil)
        #expect(body["normalization"] == "auto")
        #expect(body["pronunciation_dict_id"] == "dictionary")
        #expect(body["generation_config"] == ["speed": 1.1, "volume": 1.5, "emotion": "happy"])
        #expect(result.warnings.contains { $0.feature == "language" })
    }
    @Test func providerLocaleAndLanguageConflictBeforeHTTP() async throws {
        let transport = RecordingTransport(responses: [])
        let provider = try CartesiaProvider(settings: .init(apiKey: "key", transport: transport))
        await #expect(throws: AIError.self) { try await provider.speechModel("sonic-3.6").speak(.init(text: "Hi", voice: "voice", providerOptions: ["cartesia": ["locale": "en-GB", "language": "en"]])) }
        #expect(await transport.requests().isEmpty)
    }
}
