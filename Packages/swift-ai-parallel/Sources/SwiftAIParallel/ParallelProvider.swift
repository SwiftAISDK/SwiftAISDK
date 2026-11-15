import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

/// The published `@ai-sdk/parallel` baseline used for the wire contract.
public let parallelProviderVersion = "3.0.9"

public struct ParallelProviderSettings: Sendable {
    public var apiKey: String?
    public var apiKeyProvider: (@Sendable () async throws -> String)?
    public var baseURL: String?
    public var headers: [String: String]
    public var environment: [String: String]?
    public var transport: any AITransport

    public init(apiKey: String? = nil,
                apiKeyProvider: (@Sendable () async throws -> String)? = nil,
                baseURL: String? = nil, headers: [String: String] = [:],
                environment: [String: String]? = nil,
                transport: any AITransport = URLSessionTransport.shared) {
        self.apiKey = apiKey
        self.apiKeyProvider = apiKeyProvider
        self.baseURL = baseURL
        self.headers = headers
        self.environment = environment
        self.transport = transport
    }
}

public func createParallel(configuration: ParallelProviderSettings = .init()) -> ParallelProvider {
    ParallelProvider(configuration: configuration)
}

/// Default provider; environment authentication is resolved when a request is made.
public let parallel = createParallel()

/// Parallel's web-grounded Decision V4 provider. It does not expose text generation.
public final class ParallelProvider: AIProvider, AIDecisionProvider, Sendable {
    public let providerID = "parallel"
    public let specificationVersion = "v4"
    public let supportedCapabilities: Set<ModelCapability> = [.decision]
    private let configuration: ParallelProviderSettings

    public init(configuration: ParallelProviderSettings = .init()) {
        var resolved = configuration
        if let supplier = configuration.apiKeyProvider {
            let credential = AIAsyncCredential(supplier)
            resolved.apiKey = credential.placeholder
            resolved.transport = credential.resolvingTransport(configuration.transport)
        }
        self.configuration = resolved
    }

    public func decisionModel(_ modelID: String) throws -> any AIDecisionModelV4 {
        guard !modelID.isEmpty else { throw AIDecisionModelResolutionError.noSuchModel(modelID: modelID) }
        return DecisionParallelModel(modelID: modelID, configuration: configuration)
    }

    public func decision(_ modelID: String) throws -> any AIDecisionModelV4 { try decisionModel(modelID) }
    public func languageModel(_ modelID: String) throws -> any LanguageModel { throw unsupported(.language, modelID) }
    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel { throw unsupported(.embedding, modelID) }
    public func imageModel(_ modelID: String) throws -> any ImageModel { throw unsupported(.image, modelID) }
    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel { throw unsupported(.transcription, modelID) }
    public func speechModel(_ modelID: String) throws -> any SpeechModel { throw unsupported(.speech, modelID) }
    public func videoModel(_ modelID: String) throws -> any VideoModel { throw unsupported(.video, modelID) }
    public func rerankingModel(_ modelID: String) throws -> any RerankingModel { throw unsupported(.reranking, modelID) }

    private func unsupported(_ capability: ModelCapability, _ modelID: String) -> AIError {
        .unsupportedModel(provider: providerID, capability: capability, modelID: modelID)
    }
}

public extension AIProviders {
    static func parallel(configuration: ParallelProviderSettings = .init()) -> ParallelProvider {
        ParallelProvider(configuration: configuration)
    }
}
