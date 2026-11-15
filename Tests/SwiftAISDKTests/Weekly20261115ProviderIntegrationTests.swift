import Foundation
import Testing
@testable import SwiftAISDK

@Suite struct Weekly20261115ProviderIntegrationTests {
    @Test func newProvidersResolveThroughCompatibilityNamespaceAndCatalog() throws {
        let parallel = SwiftAISDK.AIProviders.parallel(configuration: .init(environment: [:]))
        let scaleDown = SwiftAISDK.AIProviders.scaleDown(configuration: .init(environment: [:]))
        let tencent = SwiftAISDK.AIProviders.tencent(configuration: .init(environment: [:]))
        let heyGen = try SwiftAISDK.AIProviders.heyGen(configuration: .init(environment: [:]))
        let providers: [any AIProvider] = [parallel, scaleDown, tencent, heyGen]
        for provider in providers {
            let row = try #require(AIProviderCapabilities.row(providerID: provider.providerID))
            #expect(row.supportedCapabilities == provider.supportedCapabilities)
        }
        #expect(try parallel.decisionModel("fast").providerID == "parallel.decision")
        #expect(try scaleDown.decisionModel("scaledown-classify-1").providerID == "scaledown.decision")
        #expect(try scaleDown.extractionModel("scaledown-extract-1").providerID == "scaledown.extraction")
        #expect(try heyGen.decisionModel("heygen-decision-1").providerID == "heygen.decision")
        #expect(try tencent.languageModel("hunyuan-turbos-latest").providerID == "tencent.chat")
    }

    @Test func legacyHeyGenFactoryForwardsNativeDecisionRequests() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"data":{"id":"decision-1","answers":{"blocked":{"type":"noul","noul":0.96}}}}"#))
        let provider = try SwiftAISDK.AIProviders.heyGen(settings: .init(apiKey: "key", baseURL: "https://example.com", transport: transport))
        #expect(provider.supportedCapabilities == [.video, .decision])
        let model = try provider.decisionModel("heygen-decision-1")
        let result = try await model.doDecide(.init(state: [.text("Video export fails for everyone.")], questions: ["blocked": .boolean(instructions: "Is the customer unable to work?")]))
        #expect(result.answers["blocked"] == .boolean(probability: 0.96))
        let requests = await transport.requests()
        #expect(requests.count == 1)
        #expect(requests.first?.url.absoluteString == "https://example.com/v3/models/decisions")
        #expect(requests.first?.headers["x-api-key"] == "key")
    }
}
