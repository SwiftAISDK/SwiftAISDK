@testable import SwiftAIDeepInfra
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Upstream: DeepInfraChatLanguageModel extends OpenAICompatibleChatLanguageModel
// (packages/deepinfra/src/deepinfra-chat-language-model.ts), so providerOptions
// under `deepinfra`, portable reasoning and the `deepinfra` metadata key follow
// the shared OpenAI-compatible chat behavior.
@Suite("DeepInfra upstream parity")
struct DeepInfraUpstreamParityTests {
    private func provider(_ transport: RecordingTransport) throws -> DeepInfraProvider {
        try AIProviders.deepInfra(configuration: DeepInfraProviderSettings(apiKey: "deepinfra-key", transport: transport))
    }

    @Test func chatPassesDeepInfraProviderOptionsAndPortableReasoning() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"ok"},"finish_reason":"stop"}]}"#))
        _ = try await provider(transport).chatModel("deepseek-ai/DeepSeek-R1").generate(LanguageModelRequest(
            messages: [.user("Hi")],
            reasoning: "high",
            providerOptions: ["deepinfra": ["user": "user-1", "custom_field": "x"]]
        ))

        let body = try decodeJSONBody(try #require((await transport.requests()).first?.body))
        #expect(body["user"]?.stringValue == "user-1")
        #expect(body["custom_field"]?.stringValue == "x")
        #expect(body["reasoning_effort"]?.stringValue == "high")
    }

    @Test func chatProviderReasoningEffortWinsOverPortableReasoning() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"ok"},"finish_reason":"stop"}]}"#))
        _ = try await provider(transport).chatModel("deepseek-ai/DeepSeek-R1").generate(LanguageModelRequest(
            messages: [.user("Hi")],
            reasoning: "high",
            providerOptions: ["deepinfra": ["reasoningEffort": "low"]]
        ))

        let body = try decodeJSONBody(try #require((await transport.requests()).first?.body))
        #expect(body["reasoning_effort"]?.stringValue == "low")
        #expect(body["reasoningEffort"] == nil)
    }

    // Upstream returns an empty content list (no error) when the message has no
    // text, for example a reasoning-only answer cut off by the token limit.
    @Test func chatAcceptsReasoningOnlyResponseWithoutText() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"role":"assistant","content":null,"reasoning_content":"thinking"},"finish_reason":"length"}],"usage":{"prompt_tokens":1,"completion_tokens":2,"total_tokens":3}}"#))
        let result = try await provider(transport).chatModel("deepseek-ai/DeepSeek-R1").generate(LanguageModelRequest(messages: [.user("Hi")]))

        #expect(result.text == "")
        #expect(result.reasoning == "thinking")
        #expect(result.finishReason == "length")
    }

    // deepinfra-image-model.test.ts "should handle API errors"
    @Test func imageGenerationSurfacesProviderErrorMessage() async throws {
        let transport = RecordingTransport(response: AIHTTPResponse(
            statusCode: 400,
            headers: ["content-type": "application/json"],
            body: Data(#"{"detail":{"error":"Invalid prompt"}}"#.utf8)
        ))
        let model = try provider(transport).imageModel("stability-ai/sdxl")

        await #expect {
            _ = try await model.generateImage(ImageGenerationRequest(prompt: "A cute baby sea otter", count: 1))
        } throws: { error in
            guard case let AIError.apiCall(apiError) = error else { return false }
            return apiError.statusCode == 400 && apiError.responseBody == "Invalid prompt"
        }
    }

    @Test func imageEditSurfacesOpenAICompatibleErrorMessage() async throws {
        let transport = RecordingTransport(response: AIHTTPResponse(
            statusCode: 400,
            headers: ["content-type": "application/json"],
            body: Data(#"{"error":{"message":"Bad Request"}}"#.utf8)
        ))
        let model = try provider(transport).imageModel("black-forest-labs/FLUX.1-Kontext-dev")

        await #expect {
            _ = try await model.generateImage(ImageGenerationRequest(
                prompt: "Edit",
                files: [ImageInputFile(data: Data([1, 2, 3]), mediaType: "image/png")]
            ))
        } throws: { error in
            guard case let AIError.apiCall(apiError) = error else { return false }
            return apiError.statusCode == 400 && apiError.responseBody == "Bad Request"
        }
    }
}
