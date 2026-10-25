import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public struct TopazProviderSettings: Sendable {
    public var apiKey: String?
    public var baseURL: String?
    public var headers: [String: String]
    public var queryParams: [String: String]
    public var environment: [String: String]?
    public var transport: any AITransport

    public init(apiKey: String? = nil, baseURL: String? = nil, headers: [String: String] = [:],
                queryParams: [String: String] = [:], environment: [String: String]? = nil, transport: any AITransport = URLSessionTransport.shared) {
        self.apiKey = apiKey; self.baseURL = baseURL; self.headers = headers
        self.queryParams = queryParams; self.environment = environment; self.transport = transport
    }
}

public final class TopazProvider: AIProvider, Sendable {
    public let providerID = "topaz"
    public let supportedCapabilities: Set<ModelCapability> = [.image, .video]
    private let config: TopazModelConfiguration

    public init(configuration: TopazProviderSettings = .init()) throws {
        let names = ["TOPAZ_API_KEY"]
        guard let key = configuration.apiKey ?? (configuration.environment ?? ProcessInfo.processInfo.environment)["TOPAZ_API_KEY"] else {
            throw AIError.missingAPIKey(provider: "topaz", environmentVariables: names)
        }
        var headers = ["accept": "application/json"].mergingHeaders(normalizeHeaders(configuration.headers))
        headers["x-api-key"] = headers["x-api-key"] ?? "\(key)"
        headers = withUserAgentSuffix(headers, "ai-sdk-topaz/3.0.15")
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? "https://api.topazlabs.com")
        let http = AIProviderHTTPClient(providerID: "topaz", headers: headers, transport: configuration.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: configuration.queryParams) })
        config = TopazModelConfiguration(http: http, baseURL: baseURL)
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .language, modelID: modelID)
    }

    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .embedding, modelID: modelID)
    }

    public func imageModel(_ modelID: String) throws -> any ImageModel {
        TopazImageModel(modelID: modelID, config: config)
    }

    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .transcription, modelID: modelID)
    }

    public func speechModel(_ modelID: String) throws -> any SpeechModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .speech, modelID: modelID)
    }

    public func videoModel(_ modelID: String) throws -> any VideoModel {
        TopazVideoModel(modelID: modelID, config: config)
    }

    public func rerankingModel(_ modelID: String) throws -> any RerankingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID)
    }

    public func chatModel(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
}

public extension AIProviders {
    static func topaz(configuration: TopazProviderSettings) throws -> TopazProvider {
        try TopazProvider(configuration: configuration)
    }
}

public struct TopazModelConfiguration: AIProviderHTTPConfiguration {
    public var http: AIProviderHTTPClient
    public var baseURL: String
    public init(http: AIProviderHTTPClient, baseURL: String) {
        self.http = http; self.baseURL = withoutTrailingSlash(baseURL)
    }
}
