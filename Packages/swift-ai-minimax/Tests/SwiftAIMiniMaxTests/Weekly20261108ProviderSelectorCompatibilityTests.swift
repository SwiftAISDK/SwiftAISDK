import Testing
import SwiftAIMiniMax
import SwiftAIProvider

@Test func weeklyProviderSelectorCompatibilityMiniMaxInitializerReference() {
    let old: (MiniMaxLanguageModelOptions.Effort?, MiniMaxLanguageModelOptions.Thinking?) -> MiniMaxLanguageModelOptions = MiniMaxLanguageModelOptions.init(effort:thinking:)
    let current: (MiniMaxLanguageModelOptions.Effort?, MiniMaxLanguageModelOptions.Thinking?, MiniMaxLanguageModelOptions.ServiceTier?) -> MiniMaxLanguageModelOptions = MiniMaxLanguageModelOptions.init(effort:thinking:serviceTier:)
    let actual = old(.max, .adaptive)
    #expect(actual == current(.max, .adaptive, nil))
    #expect(actual.providerOptions["minimax"]?["effort"] == "max")
    #expect(actual.providerOptions["minimax"]?["thinking"]?["type"] == "adaptive")
    #expect(actual.providerOptions["minimax"]?["serviceTier"] == nil)
    #expect(MiniMaxLanguageModelOptions() == current(nil, nil, nil))
    #expect(current(.high, .disabled, .priority).providerOptions["minimax"]?["serviceTier"] == "priority")
}
