import Foundation
import Testing
import SwiftAIProvider
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible
@testable import SwiftAIFireworks

@Suite struct Weekly20261114PrepareRequestTests {
    @Test func requestPreparationAppliesProviderTransformsWithoutNetworkCalls() async throws {
        let transport = RecordingTransport(response: jsonResponse("{}"))
        let provider = try FireworksProvider(configuration: .init(apiKey: "test-key", transport: transport))
        let model = try #require(provider.chatModel("accounts/fireworks/models/gpt-oss-120b") as? OpenAICompatibleChatModel)
        let prepared = try model.prepareRequest(.init(messages: [.user("Hi")], providerOptions: [
            "fireworks": ["promptCacheKey": "cache-key", "serviceTier": "priority",
                          "thinking": ["type": "enabled", "budgetTokens": 1024], "reasoningHistory": "interleaved"]
        ]))
        #expect(prepared.body["prompt_cache_key"] == "cache-key")
        #expect(prepared.body["service_tier"] == "priority")
        #expect(prepared.body["thinking"]?["budget_tokens"] == 1024)
        #expect(prepared.body["reasoning_history"] == "interleaved")
        #expect(prepared.body["promptCacheKey"] == nil)
        #expect(prepared.body["serviceTier"] == nil)
        #expect(prepared.body["reasoningHistory"] == nil)
        #expect(await transport.requests().isEmpty)
    }

    @Test func preparationReturnsModelSpecificCompatibilityWarningWithoutNetworkCalls() async throws {
        let transport = RecordingTransport(response: jsonResponse("{}"))
        let provider = try FireworksProvider(configuration: .init(apiKey: "test-key", transport: transport))
        let model = try #require(provider.chatModel("accounts/fireworks/models/gpt-oss-120b") as? OpenAICompatibleChatModel)
        let prepared = try model.prepareRequest(.init(messages: [.user("Hi")], reasoning: "none"))
        #expect(prepared.body["reasoning_effort"] == "minimal")
        #expect(prepared.warnings.count == 1)
        #expect(prepared.warnings.first?.type == "compatibility")
        #expect(prepared.warnings.first?.feature == "reasoning")
        #expect(await transport.requests().isEmpty)
    }
}
