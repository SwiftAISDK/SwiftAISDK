import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIOpenAI

@Suite struct Weekly20261108MediaTests {
    @Test func transcriptionSharedAndProviderTimingPrecedencePreservesWords() async throws {
        for providerGranularities: [JSONValue]? in [nil, [], [.string("segment")]] {
            let transport = RecordingTransport(response: jsonResponse(#"{"text":"hello","segments":[{"text":"hello","start":0,"end":1}],"words":[{"word":"hello","start":0.2,"end":0.8}]}"#))
            let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
            var options: [String: JSONValue] = ["languages": ["en", "fr"], "keywords": ["AC-42"]]
            if let providerGranularities { options["timestampGranularities"] = .array(providerGranularities) }
            let result = try await provider.transcriptionModel("whisper-1").transcribe(.init(audio: Data([1]), providerOptions: ["openai": .object(options)], timestampGranularities: [.word]))
            let body = String(decoding: try #require(await transport.requests().first?.body), as: UTF8.self)
            #expect(body.contains("languages[]")); #expect(body.contains("keywords[]"))
            #expect(result.words == [.init(text: "hello", startSecond: 0.2, endSecond: 0.8)])
            #expect(result.segments == [.init(text: "hello", startSecond: 0, endSecond: 1)])
            #expect(result.warnings.isEmpty == (providerGranularities == nil))
            #expect(body.contains("timestamp_granularities[]") == (providerGranularities?.isEmpty != true))
        }
    }

    @Test func unsupportedTranscriptionTimestampFormatWarnsAndOmitsWireControl() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"text":"hello"}"#))
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
        let result = try await provider.transcriptionModel("gpt-transcribe").transcribe(.init(audio: Data([1]), timestampGranularities: [.word]))
        #expect(result.warnings.count == 1)
        let body = String(decoding: try #require(await transport.requests().first?.body), as: UTF8.self)
        #expect(!body.contains("timestamp_granularities"))
    }

    @Test func imageGenerationGifOptionsAndEditMarkupUsePublishedWireNames() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"data":[{"b64_json":"aGk="}]}"#))
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
        let image = try provider.imageModel("gpt-image-2.6-flare")
        _ = try await image.generateImage(.init(prompt: "Hi", providerOptions: ["openai": ["outputFormat": "gif", "complexity": "low", "frameCount": 9, "frameDurationMs": 200, "safetyIdentifier": "safe"]]))
        let body = try decodeJSONBody(#require(await transport.requests().first?.body))
        #expect(body["output_format"] == "gif"); #expect(body["frame_count"] == 9); #expect(body["frame_duration_ms"] == 200); #expect(body["safety_identifier"] == "safe")
        _ = try await image.generateImage(.init(prompt: "Edit", files: [.init(data: Data([137,80,78,71]), mediaType: "image/png")], providerOptions: ["openai": ["markup": "data:image/png;base64,iVBORw==", "complexity": "high", "moderation": "low"]]))
        let multipart = String(decoding: try #require(await transport.requests().last?.body), as: UTF8.self)
        #expect(multipart.contains("name=\"markup\"; filename=\"markup.png\"")); #expect(multipart.contains("Content-Type: image/png"))
        #expect(multipart.contains("name=\"complexity\""))
        await #expect(throws: AIError.self) { _ = try await image.generateImage(.init(prompt: "Edit", files: [.init(data: Data([1]), mediaType: "image/png")], providerOptions: ["openai": ["outputFormat": "gif"]])) }
        #expect(await transport.requests().count == 2)
    }
}
