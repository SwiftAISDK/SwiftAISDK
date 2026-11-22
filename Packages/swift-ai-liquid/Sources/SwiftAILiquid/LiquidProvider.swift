import Foundation
import SwiftAIProvider
import SwiftAITransport

/// Published upstream release used by the Liquid wire adapter.
public let liquidProviderVersion = "3.0.1"

/// Accepts the published `d1.2` and `d1.2-ultra` IDs and custom IDs.
public typealias LiquidDecisionModelID = String

public struct LiquidProviderSettings: Sendable {
    public var apiKey: String?
    public var apiKeyProvider: (@Sendable () async throws -> String)?
    public var baseURL: String?
    public var headers: [String: String]
    public var environment: [String: String]?
    public var transport: any AITransport

    public init(
        apiKey: String? = nil,
        apiKeyProvider: (@Sendable () async throws -> String)? = nil,
        baseURL: String? = nil,
        headers: [String: String] = [:],
        environment: [String: String]? = nil,
        transport: any AITransport = URLSessionTransport.shared
    ) {
        self.apiKey = apiKey
        self.apiKeyProvider = apiKeyProvider
        self.baseURL = baseURL
        self.headers = headers
        self.environment = environment
        self.transport = transport
    }

    func resolveAPIKey() async throws -> String {
        if let apiKeyProvider { return try await apiKeyProvider() }
        if let apiKey { return apiKey }
        let variables = ["LIQUID_API_KEY"]
        if let key = environment.map({ $0["LIQUID_API_KEY"] }) ?? environmentValue(variables) {
            return key
        }
        throw AIError.missingAPIKey(provider: "liquid", environmentVariables: variables)
    }
}

public func createLiquid(configuration: LiquidProviderSettings = .init()) -> LiquidProvider {
    LiquidProvider(configuration: configuration)
}

/// Default Liquid provider. Credentials are resolved when making a request.
public let liquid = createLiquid()

/// Liquid's native Decision V4 provider for text, JSON, image and audio evidence.
public final class LiquidProvider: AIProvider, AIDecisionProvider, Sendable {
    public let providerID = "liquid"
    public let specificationVersion = "v4"
    public let supportedCapabilities: Set<ModelCapability> = [.decision]
    private let configuration: LiquidProviderSettings

    public init(configuration: LiquidProviderSettings = .init()) {
        self.configuration = configuration
    }

    public func decisionModel(_ modelID: LiquidDecisionModelID) -> any AIDecisionModelV4 {
        DecisionLiquidModel(modelID: modelID, configuration: configuration)
    }

    public func decision(_ modelID: LiquidDecisionModelID) -> any AIDecisionModelV4 {
        decisionModel(modelID)
    }

    public func languageModel(_ id: String) throws -> any LanguageModel { throw unsupported(.language, id) }
    public func embeddingModel(_ id: String) throws -> any EmbeddingModel { throw unsupported(.embedding, id) }
    public func imageModel(_ id: String) throws -> any ImageModel { throw unsupported(.image, id) }
    public func transcriptionModel(_ id: String) throws -> any TranscriptionModel { throw unsupported(.transcription, id) }
    public func speechModel(_ id: String) throws -> any SpeechModel { throw unsupported(.speech, id) }
    public func videoModel(_ id: String) throws -> any VideoModel { throw unsupported(.video, id) }
    public func rerankingModel(_ id: String) throws -> any RerankingModel { throw unsupported(.reranking, id) }

    private func unsupported(_ capability: ModelCapability, _ id: String) -> AIError {
        .unsupportedModel(provider: providerID, capability: capability, modelID: id)
    }
}

public extension AIProviders {
    static func liquid(configuration: LiquidProviderSettings = .init()) -> LiquidProvider {
        createLiquid(configuration: configuration)
    }
}
