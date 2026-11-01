import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public struct ReplicateProviderSettings: Sendable {
    public var apiKey: String?
    /// Supplies a fresh API key immediately before each authenticated request.
    public var apiKeyProvider: (@Sendable () async throws -> String)?
    public var baseURL: String?
    public var headers: [String: String]
    public var queryParams: [String: String]
    public var transport: any AITransport

    public init(apiKey: String? = nil, apiKeyProvider: (@Sendable () async throws -> String)? = nil, baseURL: String? = nil, headers: [String: String] = [:],
                queryParams: [String: String] = [:], transport: any AITransport = URLSessionTransport.shared) {
        self.apiKey = apiKey; self.apiKeyProvider = apiKeyProvider; self.baseURL = baseURL; self.headers = headers
        self.queryParams = queryParams; self.transport = transport
    }
}

public final class ReplicateProvider: AIProvider, Sendable {
    public let providerID = "replicate"
    public let supportedCapabilities: Set<ModelCapability> = [.image, .video]
    private let config: ReplicateModelConfiguration

    public init(configuration: ReplicateProviderSettings = .init()) throws {
        var resolvedSettings = configuration
        if let supplier = resolvedSettings.apiKeyProvider {
            let credential = AIAsyncCredential(supplier)
            resolvedSettings.apiKey = credential.placeholder
            resolvedSettings.transport = credential.resolvingTransport(resolvedSettings.transport)
        }
        let configuration = resolvedSettings
        let names = ["REPLICATE_API_TOKEN"]
        guard let key = configuration.apiKey ?? environmentValue(names) else {
            throw AIError.missingAPIKey(provider: "replicate", environmentVariables: names)
        }
        var headers = normalizeHeaders(configuration.headers)
        headers["authorization"] = headers["authorization"] ?? "Bearer \(key)"
        headers = withUserAgentSuffix(headers, "ai-sdk-replicate/3.0.73")
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? "https://api.replicate.com/v1")
        let http = AIProviderHTTPClient(providerID: "replicate", headers: headers, transport: configuration.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: configuration.queryParams) })
        config = ReplicateModelConfiguration(http: http, baseURL: baseURL)
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .language, modelID: modelID)
    }

    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .embedding, modelID: modelID)
    }

    public func imageModel(_ modelID: String) throws -> any ImageModel {
        ReplicateImageModel(modelID: modelID, config: config)
    }

    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .transcription, modelID: modelID)
    }

    public func speechModel(_ modelID: String) throws -> any SpeechModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .speech, modelID: modelID)
    }

    public func videoModel(_ modelID: String) throws -> any VideoModel {
        ReplicateVideoModel(modelID: modelID, config: config)
    }

    public func rerankingModel(_ modelID: String) throws -> any RerankingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID)
    }

    public func chatModel(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
}

public extension AIProviders {
    static func replicate(configuration: ReplicateProviderSettings) throws -> ReplicateProvider {
        try ReplicateProvider(configuration: configuration)
    }
}

public struct ReplicateModelConfiguration: AIProviderHTTPConfiguration {
    public var http: AIProviderHTTPClient
    public var baseURL: String
    public init(http: AIProviderHTTPClient, baseURL: String) {
        self.http = http; self.baseURL = withoutTrailingSlash(baseURL)
    }
}
