@testable import SwiftAIFireworks
@testable import SwiftAIDeepInfra
@testable import SwiftAIBaseten
@testable import SwiftAIMoonshotAI
@testable import SwiftAITogetherAI
@testable import SwiftAIAnthropic
@testable import SwiftAIOpenAICompatible
@testable import SwiftAIOpenAI
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
private typealias AI = SwiftAISDK.AI
private typealias AIProviders = SwiftAISDK.AIProviders
private typealias AICustomProvider = SwiftAISDK.AICustomProvider
import Foundation
import Testing
@testable import SwiftAISDK

@Test func openAICompatibleNativeProviderSurfaceIDsMirrorUpstream() throws {
    let settings = ProviderSettings(apiKey: "key", baseURL: "https://api.example.com", transport: RecordingTransport(response: jsonResponse("{}")))

    let baseten = try AIProviders.baseten(settings: settings)
    #expect(try baseten.languageModel("chat").providerID == "baseten.chat")
    #expect(try baseten.chatModel("chat").providerID == "baseten.chat")

    let deepInfra = try AIProviders.deepInfra(settings: settings)
    #expect(try deepInfra.languageModel("chat").providerID == "deepinfra.chat")
    #expect(try deepInfra.chatModel("chat").providerID == "deepinfra.chat")
    #expect(try deepInfra.completionModel("completion").providerID == "deepinfra.completion")
    #expect(try deepInfra.embeddingModel("embedding").providerID == "deepinfra.embedding")
    #expect(try deepInfra.imageModel("image").providerID == "deepinfra.image")

    let fireworks = try AIProviders.fireworks(settings: settings)
    #expect(try fireworks.languageModel("chat").providerID == "fireworks.chat")
    #expect(try fireworks.chatModel("chat").providerID == "fireworks.chat")
    #expect(try fireworks.completionModel("completion").providerID == "fireworks.completion")
    #expect(try fireworks.embeddingModel("embedding").providerID == "fireworks.embedding")
    #expect(try fireworks.imageModel("image").providerID == "fireworks.image")

    let moonshot = try AIProviders.moonshotAI(settings: settings)
    #expect(try moonshot.languageModel("kimi-k2.5").providerID == "moonshotai.chat")
    #expect(try moonshot.chatModel("kimi-k2.5").providerID == "moonshotai.chat")

    let together = try AIProviders.togetherAI(settings: settings)
    #expect(try together.languageModel("chat").providerID == "togetherai.chat")
    #expect(try together.chatModel("chat").providerID == "togetherai.chat")
    #expect(try together.completionModel("completion").providerID == "togetherai.completion")
    #expect(try together.embeddingModel("embedding").providerID == "togetherai.embedding")
    #expect(try together.imageModel("image").providerID == "togetherai.image")
    #expect(try together.rerankingModel("rerank").providerID == "togetherai.reranking")
}

// Upstream togetherai-provider.test.ts `structuredOutputSupportCases`: the umbrella
// factory and the native provider must both follow the catalog's JSON-schema IDs.
@Test(arguments: [
    ("deepseek-ai/DeepSeek-V4-Flash-0731", true),
    ("deepseek-ai/DeepSeek-V4.1-Flash", true),
    ("deepseek-ai/DeepSeek-V4.1-Flash-1017", true),
    ("openai/gpt-oss-120b", true),
    ("zai-org/GLM-5.2", true),
    ("zai-org/GLM-5.3-Flash", true),
    ("moonshotai/Kimi-K3", true),
    ("MiniMaxAI/MiniMax-M3.1-Flash", true),
    ("zai-org/GLM-5.3", false),
    ("custom-model-id", false)
])
func togetherAIUmbrellaAndNativeStructuredOutputSupportMatchUpstream(_ fixture: (String, Bool)) async throws {
    let raw = #"{"choices":[{"message":{"content":"{}"},"finish_reason":"stop"}]}"#
    let request = LanguageModelRequest(messages: [.user("Return JSON")], extraBody: [
        "responseFormat": [
            "type": "json", "name": "answer",
            "schema": ["type": "object", "properties": ["value": ["type": "string", "enum": ["schema-only-value"]]]]
        ]
    ])
    let umbrellaTransport = RecordingTransport(response: jsonResponse(raw))
    let umbrella = try AIProviders.togetherAI(settings: ProviderSettings(apiKey: "together-key", transport: umbrellaTransport))
    _ = try await umbrella.chatModel(fixture.0).generate(request)
    let nativeTransport = RecordingTransport(response: jsonResponse(raw))
    let native = try TogetherAIProvider(configuration: TogetherAIProviderSettings(apiKey: "together-key", transport: nativeTransport))
    _ = try await native.chatModel(fixture.0).generate(request)

    let expected = JSONValue.string(fixture.1 ? "json_schema" : "json_object")
    for transport in [umbrellaTransport, nativeTransport] {
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["response_format"]?["type"] == expected)
        #expect((body["response_format"]?["json_schema"] != nil) == fixture.1)
    }
}
