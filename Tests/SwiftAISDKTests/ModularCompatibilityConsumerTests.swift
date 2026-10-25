@testable import SwiftAIGateway
import Testing
import SwiftAISDK

// Deliberately no @testable import or direct core import: this is the legacy
// consumer boundary, including module-qualified names after re-export.
@Suite("Modular compatibility consumer", .serialized)
struct ModularCompatibilityConsumerTests {
    @Test func oldNamespaceAndDefaultProviderRemainUsable() async throws {
        let provider: SwiftAISDK.AICustomProvider = customProvider(languageModels: ["echo": CompatibilityEchoModel()])
        let result: SwiftAISDK.TextGenerationResult = try await AIDefaultProvider.withProvider(provider) {
            try await AI.generateText(model: "echo", request: .init(messages: [.user("legacy")]), retryPolicy: .none)
        }
        #expect(result.text == "legacy")
        #expect(result.responseMessages.count == 1)
        #expect(try AIProviders.gateway(settings: ProviderSettings(apiKey: "fixture-only")).providerID == "gateway")
    }

    @Test func legacyFactoryAndRegistryShareCoreContracts() async throws {
        let provider = SwiftAISDK.AIProviders.customProvider(languageModels: ["echo": CompatibilityEchoModel()])
        let registry: SwiftAISDK.AIProviderRegistry = createProviderRegistry(["local": provider])
        let model: any SwiftAISDK.LanguageModel = try registry.languageModel("local:echo")
        let result = try await SwiftAISDK.AI.generateText(model: model, request: .init(messages: [.user("registry")]), retryPolicy: .none)
        #expect(result.text == "registry")
    }
}

private struct CompatibilityEchoModel: LanguageModel {
    let providerID = "local"
    let modelID = "echo"
    func generate(_ request: LanguageModelRequest) async throws -> TextGenerationResult {
        TextGenerationResult(text: request.messages.last?.combinedText ?? "", finishReason: "stop", rawValue: [:])
    }
}
