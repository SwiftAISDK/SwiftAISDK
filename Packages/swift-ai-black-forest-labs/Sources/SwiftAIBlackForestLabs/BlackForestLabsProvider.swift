import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public struct BlackForestLabsProviderSettings: Sendable {
    public var apiKey: String?
    public var baseURL: String?
    public var headers: [String: String]
    public var queryParams: [String: String]
    public var transport: any AITransport

    public init(apiKey: String? = nil, baseURL: String? = nil, headers: [String: String] = [:],
                queryParams: [String: String] = [:], transport: any AITransport = URLSessionTransport.shared) {
        self.apiKey = apiKey; self.baseURL = baseURL; self.headers = headers
        self.queryParams = queryParams; self.transport = transport
    }
}

public final class BlackForestLabsProvider: AIProvider, Sendable {
    public let providerID = "black-forest-labs"
    public let supportedCapabilities: Set<ModelCapability> = [.image, .video]
    private let config: BlackForestLabsModelConfiguration

    public init(configuration: BlackForestLabsProviderSettings = .init()) throws {
        let names = ["BFL_API_KEY", "BLACK_FOREST_LABS_API_KEY"]
        guard let key = configuration.apiKey ?? environmentValue(names) else {
            throw AIError.missingAPIKey(provider: "black-forest-labs", environmentVariables: names)
        }
        var headers = configuration.headers
        headers["x-key"] = headers["x-key"] ?? "\(key)"
        headers = withUserAgentSuffix(headers, "ai-sdk-black-forest-labs/2.0.70")
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? "https://api.bfl.ai/v1")
        let http = AIProviderHTTPClient(providerID: "black-forest-labs", headers: headers, transport: configuration.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: configuration.queryParams) })
        config = BlackForestLabsModelConfiguration(http: http, baseURL: baseURL)
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .language, modelID: modelID)
    }

    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .embedding, modelID: modelID)
    }

    public func imageModel(_ modelID: String) throws -> any ImageModel {
        BlackForestLabsImageModel(modelID: modelID, config: config)
    }

    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .transcription, modelID: modelID)
    }

    public func speechModel(_ modelID: String) throws -> any SpeechModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .speech, modelID: modelID)
    }

    public func videoModel(_ modelID: String) throws -> any VideoModel {
        BlackForestLabsVideoModel(modelID: modelID, config: config)
    }

    public func rerankingModel(_ modelID: String) throws -> any RerankingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID)
    }

    public func chatModel(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
}

public extension AIProviders {
    static func blackForestLabs(configuration: BlackForestLabsProviderSettings) throws -> BlackForestLabsProvider {
        try BlackForestLabsProvider(configuration: configuration)
    }
}

public struct BlackForestLabsModelConfiguration: AIProviderHTTPConfiguration {
    public var http: AIProviderHTTPClient
    public var baseURL: String
    public init(http: AIProviderHTTPClient, baseURL: String) {
        self.http = http; self.baseURL = withoutTrailingSlash(baseURL)
    }
}
