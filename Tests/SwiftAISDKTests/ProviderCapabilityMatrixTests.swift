@testable import SwiftAIAnthropic
@testable import SwiftAIOpenAICompatible
@testable import SwiftAIOpenAI
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAITransport
private typealias AI = SwiftAISDK.AI
private typealias AIProviders = SwiftAISDK.AIProviders
private typealias AICustomProvider = SwiftAISDK.AICustomProvider
import Foundation
import Testing
@testable import SwiftAISDK

@Test func providerCapabilityMatrixDocumentationMatchesGeneratedMarkdown() throws {
    let documentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Docs/ProviderCapabilityMatrix.md")
    let document = try String(contentsOf: documentURL, encoding: .utf8)

    #expect(document == AIProviderCapabilities.markdownDocument())
}

@Test func providerCapabilityMatrixCoversDiscoveredProviderPackages() throws {
    // Read the same registration catalog as CLI/docs, then compare the compiled API.
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Porting/packages.json")
    let data = try Data(contentsOf: url)
    let catalog = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let packages = try #require(catalog["packages"] as? [[String: Any]])
    let rows = packages.flatMap { $0["capabilityRows"] as? [[String: Any]] ?? [] }
    let expectedPackages = Set(rows.compactMap { $0["upstreamPackage"] as? String })
    #expect(!expectedPackages.isEmpty)

    let actualPackages = Set(AIProviderCapabilities.all.map(\.upstreamPackage))
    #expect(actualPackages == expectedPackages)
}

@Test func providerCapabilityMatrixHasUniqueProviderIDsAndFactories() {
    let rows = AIProviderCapabilities.all
    #expect(Set(rows.map(\.providerID)).count == rows.count)
    #expect(rows.allSatisfy { !$0.factoryNames.isEmpty })
    #expect(rows.allSatisfy { !$0.supportedCapabilities.isEmpty })
}

@Test func providerCapabilityMatrixMatchesRepresentativeRegistryCapabilities() throws {
    let openAI = try AIProviders.openAI(settings: ProviderSettings(apiKey: "test-key"))
    let openAIRow = try #require(AIProviderCapabilities.row(providerID: "openai"))
    #expect(openAIRow.supportedCapabilities == openAI.supportedCapabilities)
    #expect(openAIRow.supportsFileUpload)
    #expect(openAIRow.supportsSkillUpload)

    let anthropicRow = try #require(AIProviderCapabilities.row(providerID: "anthropic"))
    #expect(anthropicRow.supports(.language))
    #expect(anthropicRow.supports(.evaluation))
    #expect(!anthropicRow.supports(.embedding))
    #expect(anthropicRow.supportsFileUpload)
    #expect(anthropicRow.supportsSkillUpload)

    let miniMax = try AIProviders.miniMax(settings: MiniMaxProviderSettings(apiKey: "minimax-key"))
    let miniMaxRow = try #require(AIProviderCapabilities.row(providerID: "minimax"))
    #expect(miniMaxRow.supportedCapabilities == miniMax.supportedCapabilities)
    #expect(miniMaxRow.supports(.language))
    #expect(miniMaxRow.supports(.video))
    #expect(!miniMaxRow.supports(.embedding))

    let topaz = try AIProviders.topaz(settings: ProviderSettings(apiKey: "topaz-key"))
    let topazRow = try #require(AIProviderCapabilities.row(providerID: "topaz"))
    #expect(topazRow.supportedCapabilities == topaz.supportedCapabilities)
    #expect(topazRow.supportedCapabilities == [.image, .video])
    let heyGen = try AIProviders.heyGen(settings: ProviderSettings(apiKey: "heygen-key"))
    let heyGenRow = try #require(AIProviderCapabilities.row(providerID: "heygen"))
    #expect(heyGenRow.supportedCapabilities == heyGen.supportedCapabilities)
    #expect(heyGenRow.supportedCapabilities == [.video])

    let voyage = try AIProviders.voyage(settings: ProviderSettings(apiKey: "voyage-key"))
    let voyageRow = try #require(AIProviderCapabilities.row(providerID: "voyage"))
    #expect(voyageRow.supportedCapabilities == voyage.supportedCapabilities)
    #expect(voyageRow.supports(.embedding))
    #expect(voyageRow.supports(.reranking))

    let gateway = try AIProviders.gateway(settings: ProviderSettings(apiKey: "gateway-key"))
    let gatewayRow = try #require(AIProviderCapabilities.row(providerID: "gateway"))
    #expect(gatewayRow.supportedCapabilities == gateway.supportedCapabilities)
    #expect(gatewayRow.supports(.evaluation))
    #expect(!gatewayRow.supports(.audioGeneration))
    #expect(!gatewayRow.supports(.audioTransformation))
    #expect(!gatewayRow.supports(.dubbing))

    let google = try AIProviders.google(settings: ProviderSettings(apiKey: "google-key"))
    let googleRow = try #require(AIProviderCapabilities.row(providerID: "google.generative-ai"))
    #expect(googleRow.supportedCapabilities == google.supportedCapabilities)
    #expect(googleRow.supports(.evaluation))

    let cartesia = try AIProviders.cartesia(settings: CartesiaProviderSettings(
        apiKey: "cartesia-key",
        environment: [:]
    ))
    let cartesiaRow = try #require(AIProviderCapabilities.row(providerID: "cartesia"))
    #expect(cartesiaRow.supportedCapabilities == cartesia.supportedCapabilities)
    #expect(cartesiaRow.supports(.speech))
    #expect(cartesiaRow.supports(.transcription))

    let fishAudio = try AIProviders.fishAudio(settings: ProviderSettings(
        apiKey: "fish-key",
        environment: [:]
    ))
    let fishAudioRow = try #require(AIProviderCapabilities.row(providerID: "fish-audio"))
    #expect(fishAudioRow.supportedCapabilities == fishAudio.supportedCapabilities)
    #expect(fishAudioRow.supports(.speech))
    #expect(fishAudioRow.supports(.transcription))

    let gmiCloud = try AIProviders.gmiCloud(settings: ProviderSettings(
        apiKey: "gmi-key",
        environment: [:]
    ))
    let gmiCloudRow = try #require(AIProviderCapabilities.row(providerID: "gmicloud"))
    #expect(gmiCloudRow.supportedCapabilities == gmiCloud.supportedCapabilities)
    #expect(gmiCloudRow.supports(.language))

    let typeSafeAI = AIProviders.typeSafeAI(settings: ProviderSettings(environment: [:]))
    let typeSafeAIRow = try #require(AIProviderCapabilities.row(providerID: "typesafe"))
    #expect(typeSafeAIRow.supportedCapabilities == typeSafeAI.supportedCapabilities)
    #expect(typeSafeAIRow.supports(.evaluation))
    #expect(!typeSafeAIRow.supports(.language))

    let zai = AIProviders.zai(settings: ProviderSettings(apiKey: "zai-key"))
    let zaiRow = try #require(AIProviderCapabilities.row(providerID: "zai"))
    #expect(zaiRow.supportedCapabilities == zai.supportedCapabilities)
    #expect(zaiRow.supports(.language))
    #expect(!zaiRow.supports(.embedding))
}
