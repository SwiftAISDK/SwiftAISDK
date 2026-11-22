import SwiftAILiquid
import SwiftAIProvider
import Testing

@Suite struct LiquidProviderUpstreamTests {
    private let call = AIDecisionModelV4CallOptions(state: [.text("Refund me.")],
        questions: ["refund": .boolean(instructions: "Refund request?")])

    @Test func rejectsUnsupportedModelTypes() {
        let provider = createLiquid()
        #expect(provider.specificationVersion == "v4")
        #expect(throws: AIError.unsupportedModel(provider: "liquid", capability: .language, modelID: "other")) {
            _ = try provider.languageModel("other")
        }
        #expect(throws: AIError.unsupportedModel(provider: "liquid", capability: .embedding, modelID: "other")) {
            _ = try provider.embeddingModel("other")
        }
        #expect(throws: AIError.unsupportedModel(provider: "liquid", capability: .image, modelID: "other")) {
            _ = try provider.imageModel("other")
        }
    }

    @Test(arguments: [true, false])
    func usesExplicitOrEnvironmentKeyWithDefaultEndpoint(explicit: Bool) async throws {
        let transport = try LiquidTestTransport(["answers": ["refund": ["type": "noul", "noul": 0.9]]])
        let model = createLiquid(configuration: .init(apiKey: explicit ? "explicit-key" : nil,
            environment: ["LIQUID_API_KEY": "env-key"], transport: transport)).decisionModel("d1.2-ultra")
        let result = try await model.doDecide(call)
        #expect(result.usage == nil)
        #expect(result.response?.modelID == "d1.2-ultra")
        let request = try await transport.request()
        #expect(request.url.absoluteString == "https://api.liquid.ai/decisions/v1/systemone")
        #expect(request.headers["authorization"] == (explicit ? "Bearer explicit-key" : "Bearer env-key"))
        #expect(request.headers["user-agent"]?.contains("ai-sdk-liquid/\(liquidProviderVersion)") == true)
        #expect(try await transport.requestBody()["model"] == "d1.2-ultra")
    }

    @Test func loadsCredentialsLazilyAndReportsMissingKey() async throws {
        let transport = try LiquidTestTransport()
        let model = createLiquid(configuration: .init(environment: [:], transport: transport)).decisionModel("d1.2")
        await #expect(throws: AIError.missingAPIKey(provider: "liquid", environmentVariables: ["LIQUID_API_KEY"])) {
            _ = try await model.doDecide(call)
        }
        #expect(await transport.requests.isEmpty)
    }
}
