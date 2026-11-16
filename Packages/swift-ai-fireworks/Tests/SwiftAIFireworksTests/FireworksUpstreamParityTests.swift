@testable import SwiftAIFireworks
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

@Suite("Fireworks upstream parity")
struct FireworksUpstreamParityTests {
    private func provider(_ transport: RecordingTransport) throws -> FireworksProvider {
        try AIProviders.fireworks(configuration: FireworksProviderSettings(apiKey: "fireworks-key", transport: transport))
    }

    // fireworks-image-model.test.ts "should reject invalid provider options"
    @Test func imageRejectsInvalidProviderOptionsBeforeRequest() async throws {
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 200, headers: ["content-type": "image/png"], body: Data("png".utf8)))
        let model = try provider(transport).imageModel("accounts/fireworks/models/flux-1-dev-fp8")

        await #expect {
            _ = try await model.generateImage(ImageGenerationRequest(
                prompt: "A cute baby sea otter",
                count: 1,
                providerOptions: ["fireworks": ["output_format": "webp"]]
            ))
        } throws: { error in
            String(describing: error).contains("invalid fireworks provider options")
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test(arguments: [
        ["safety_tolerance": JSONValue.number(7)],
        ["num_inference_steps": JSONValue.number(2.5)],
        ["prompt_upsampling": JSONValue.string("yes")]
    ])
    func imageRejectsOutOfSchemaValues(_ options: [String: JSONValue]) async throws {
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 200, headers: ["content-type": "image/png"], body: Data("png".utf8)))
        let model = try provider(transport).imageModel("accounts/fireworks/models/flux-1-dev-fp8")
        await #expect(throws: AIError.self) {
            _ = try await model.generateImage(ImageGenerationRequest(prompt: "x", providerOptions: ["fireworks": .object(options)]))
        }
    }

    // fireworks-image-model.test.ts "should pass typed workflow provider options to the API"
    @Test func imagePassesTypedAndLooseProviderOptions() async throws {
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 200, headers: ["content-type": "image/png"], body: Data("png".utf8)))
        let model = try provider(transport).imageModel("accounts/fireworks/models/flux-1-dev-fp8")
        _ = try await model.generateImage(ImageGenerationRequest(
            prompt: "x",
            count: 1,
            providerOptions: ["fireworks": [
                "guidance_scale": 3.5, "num_inference_steps": 30, "output_format": "png",
                "safety_tolerance": 2, "prompt_upsampling": true, "custom_flag": "kept"
            ]]
        ))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["guidance_scale"]?.doubleValue == 3.5)
        #expect(body["num_inference_steps"]?.intValue == 30)
        #expect(body["output_format"]?.stringValue == "png")
        #expect(body["safety_tolerance"]?.intValue == 2)
        #expect(body["prompt_upsampling"]?.boolValue == true)
        #expect(body["custom_flag"]?.stringValue == "kept")
    }

    // fireworks-image-model.test.ts "capabilities"
    @Test func imageAdvertisesFileAndMaskSupport() async throws {
        let provider = try provider(RecordingTransport(responses: []))
        let kontext = try #require(try provider.imageModel("accounts/fireworks/models/flux-kontext-pro") as? FireworksImageModel)
        let playground = try #require(try provider.imageModel("accounts/fireworks/models/playground-v2-5-1024px-aesthetic") as? FireworksImageModel)
        let custom = try #require(try provider.imageModel("accounts/fireworks/models/custom-image-model") as? FireworksImageModel)
        #expect(kontext.supportsFileInputs == true)
        #expect(kontext.supportsMaskInputs == false)
        #expect(playground.supportsFileInputs == false)
        #expect(playground.supportsMaskInputs == false)
        #expect(custom.supportsFileInputs == nil)
        #expect(custom.supportsMaskInputs == nil)
    }

    // Upstream OpenAICompatibleChatLanguageModel returns empty content, not an error,
    // when the choice carries no text (for example reasoning cut off by the limit).
    @Test func chatAcceptsReasoningOnlyResponseWithoutText() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"role":"assistant","content":null,"reasoning_content":"thinking"},"finish_reason":"length"}]}"#))
        let result = try await provider(transport).languageModel("accounts/fireworks/models/kimi-k2p6").generate(LanguageModelRequest(messages: [.user("Hi")]))
        #expect(result.text == "")
        #expect(result.reasoning == "thinking")
        #expect(result.finishReason == "length")
    }
}
