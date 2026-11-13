import Foundation
import Testing
@testable import SwiftAISDK

private struct CompatibilityExtractionModel: AIExtractionModelV4 {
    let providerID = "fixture.extraction"
    let modelID = "extract"
    let supportedFieldTypes: [AIExtractionFieldType] = [.text]
    func doExtract(_ options: AIExtractionModelV4CallOptions) async throws -> AIExtractionModelV4Result {
        .init(answers: ["name": .init(type: .text, value: "Ada", pNull: 0, confidence: 1)])
    }
}
private struct CompatibilityExtractionProvider: AIProvider, AIExtractionProvider {
    let providerID = "fixture"
    let supportedCapabilities: Set<ModelCapability> = [.extraction]
    func extractionModel(_ modelID: String) throws -> any AIExtractionModelV4 { CompatibilityExtractionModel() }
    func languageModel(_ id: String) throws -> any LanguageModel { throw unsupported(id) }
    func embeddingModel(_ id: String) throws -> any EmbeddingModel { throw unsupported(id) }
    func imageModel(_ id: String) throws -> any ImageModel { throw unsupported(id) }
    func transcriptionModel(_ id: String) throws -> any TranscriptionModel { throw unsupported(id) }
    func speechModel(_ id: String) throws -> any SpeechModel { throw unsupported(id) }
    func videoModel(_ id: String) throws -> any VideoModel { throw unsupported(id) }
    func rerankingModel(_ id: String) throws -> any RerankingModel { throw unsupported(id) }
    private func unsupported(_ id: String) -> AIError { .unsupportedModel(provider: providerID, capability: .language, modelID: id) }
}

@Suite(.serialized) struct Weekly20261114ExtractionCompatibilityTests {
    @Test func legacyOpenAISettingsFactoryResolvesExtractionAndGenericProviderRejectsIt() async throws {
        let provider = try AIProviders.openAI(settings: ProviderSettings(apiKey: "fixture", environment: [:]))
        #expect(provider.supportedCapabilities.contains(.extraction))
        let model = try await AIDefaultProvider.withProvider(provider) {
            try AIDefaultProvider.resolveExtractionModel("gpt-6-sol")
        }
        #expect(model.providerID == "openai.extraction")
        #expect(model.modelID == "gpt-6-sol")
        let generic = try OpenAICompatibleProvider(
            providerID: "fixture", defaultBaseURL: "https://example.com/v1", authorization: .none,
            settings: ProviderSettings(environment: [:])
        )
        #expect(!generic.supportedCapabilities.contains(.extraction))
        #expect(throws: AIError.unsupportedModel(provider: "fixture", capability: .extraction, modelID: "extract")) {
            _ = try generic.extractionModel("extract")
        }
    }

    @Test func umbrellaDefaultProviderResolvesExtractionWithoutGatewayInitialization() async throws {
        let result = try await AIDefaultProvider.withProvider(CompatibilityExtractionProvider()) {
            try await AI.experimentalExtract(model: "extract", state: .text("Ada"), fields: ["name": .init(type: .text)])
        }
        #expect(result.answers["name"]?.value == "Ada")
    }

    @Test func customFallbackAndRegistryRetainExtractionProtocolConformance() async throws {
        let custom = AICustomProvider(fallbackProvider: CompatibilityExtractionProvider())
        let model = try (custom as any AIExtractionProvider).extractionModel("extract")
        let result = try await AI.experimentalExtract(model: model, state: .text("Ada"), fields: ["name": .init(type: .text)])
        #expect(result.answers["name"]?.value == "Ada")
        #expect(custom.supportedCapabilities.contains(.extraction))
    }
}
