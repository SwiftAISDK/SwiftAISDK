import Foundation
import Testing
@testable import SwiftAIMiniMax
import SwiftAIProvider
import SwiftAITransport

@Suite("Weekly20261114 MiniMax H3 images")
struct Weekly20261114ImageTests {
    private let usage: JSONValue = ["input_tokens": 30, "output_tokens": 40, "total_tokens": 70, "input_tokens_details": ["text_tokens": 10, "image_tokens": 20]]
    @Test func generationsDownloadWithoutCredentialLeakAndPreserveUsageOnce() async throws {
        let images: JSONValue = [["url": "https://cdn.example.com/a", "size": "1024x1024", "revised_prompt": "revised"],
                                ["error": ["message": "Safety failed"]], ["url": "https://cdn.example.com/b"]]
        let transport = RecordingTransport(responses: [.init(statusCode: 200, body: try encodeJSONBody(["data": images, "usage": usage, "output_format": "png", "request_id": "r"])),
            .init(statusCode: 200, body: Data([1,2,3])), .init(statusCode: 200, body: Data([4]))])
        let provider = try MiniMaxProvider(configuration: .init(apiKey: "key", imageBaseURL: "https://api.example.com/v1", headers: ["x-private": "secret"], transport: transport))
        let model = provider.image("MiniMax-H3-Image")
        #expect(model.maxImagesPerCall == 10); #expect(model.supportsFileInputs == true); #expect(model.supportsMaskInputs == false)
        let result = try await model.generateImage(.init(prompt: "red", size: "1024x1024", seed: 1, count: 3,
            providerOptions: MiniMaxImageModelOptions(disablePromptEnhanced: true, outputCompression: 90, outputFormat: .png).providerOptions))
        let requests = await transport.requests()
        #expect(requests[0].url.path == "/v1/images/generations")
        #expect(requests[0].headers["authorization"] == "Bearer key")
        #expect(requests[1].headers["authorization"] == nil); #expect(requests[1].headers["x-private"] == nil)
        #expect(requests[2].headers["authorization"] == nil)
        let body = try decodeJSONBody(#require(requests[0].body))
        #expect(body["response_format"] == "url"); #expect(body["output_compression"] == 90); #expect(body["disable_prompt_enhanced"] == true)
        #expect(result.base64Images == ["AQID", "BA=="])
        #expect(result.usage?.totalTokens == 70)
        #expect(result.providerMetadata["minimax"]?["images"]?[0]?["usage"] == usage)
        #expect(result.providerMetadata["minimax"]?["images"]?[1]?["usage"] == nil)
        #expect(result.warnings.contains { $0.message == "Image 2 failed: Safety failed" })
    }
    @Test func editUsesReferenceImagesAndDropsGenerationOnlyEnhancement() async throws {
        let transport = RecordingTransport(responses: [jsonResponse(#"{"data":[{"url":"https://example.com/image"}]}"#), .init(statusCode: 200, body: Data([1]))])
        let provider = try MiniMaxProvider(configuration: .init(apiKey: "key", transport: transport))
        let result = try await provider.image("MiniMax-H3-Image-Highspeed").generateImage(.init(prompt: "edit", aspectRatio: "16:9", files: [.init(data: Data([1,2,3]), mediaType: "image/png"), .init(url: "https://example.com/input")],
            providerOptions: MiniMaxImageModelOptions(area: .twoK, disablePromptEnhanced: false).providerOptions))
        let request = try #require(await transport.requests().first)
        let body = try decodeJSONBody(#require(request.body))
        #expect(request.url.path == "/v1/images/edits"); #expect(body["area"] == "2K")
        #expect(body["disable_prompt_enhanced"] == nil)
        #expect(body["images"] == [["image_url": "data:image/png;base64,AQID"], ["image_url": "https://example.com/input"]])
        #expect(result.warnings.contains { $0.feature == "disablePromptEnhanced" })
    }
    @Test func preabortedImageRequestDoesNotSend() async throws {
        let transport = RecordingTransport(response: jsonResponse("{}"))
        let model = try MiniMaxProvider(configuration: .init(apiKey: "key", transport: transport)).image("MiniMax-H3-Image")
        let controller = AIAbortController(); controller.abort()
        await #expect(throws: AIAbortError.self) { try await model.generateImage(.init(prompt: "red", abortSignal: controller.signal)) }
        #expect(await transport.requests().isEmpty)
    }

    @Test func masksAndInvalidOptionsRejectBeforeSending() async throws {
        let transport = RecordingTransport(response: jsonResponse("{}"))
        let model = try MiniMaxProvider(configuration: .init(apiKey: "key", transport: transport)).image("MiniMax-H3-Image")
        await #expect(throws: AIError.self) { try await model.generateImage(.init(prompt: "edit", mask: .init(data: Data([1]), mediaType: "image/png"))) }
        for option: JSONValue in [["area": "3K"], ["outputCompression": -1], ["outputCompression": 0.5], ["outputFormat": "gif"]] {
            await #expect(throws: AIError.self) { try await model.generateImage(.init(prompt: "red", providerOptions: ["minimax": option])) }
        }
        #expect(await transport.requests().isEmpty)
    }
}
