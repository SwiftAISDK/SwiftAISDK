import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public struct MistralProviderSettings: Sendable {
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

public final class MistralProvider: AIProvider, Sendable {
    public let providerID = "mistral"
    public let supportedCapabilities: Set<ModelCapability> = [.language, .embedding, .transcription, .speech]
    private let http: AIProviderHTTPClient

    public init(configuration: MistralProviderSettings = .init()) throws {
        let names = ["MISTRAL_API_KEY"]
        guard let key = configuration.apiKey ?? environmentValue(names) else {
            throw AIError.missingAPIKey(provider: "mistral", environmentVariables: names)
        }
        var headers = configuration.headers
        headers["Authorization"] = headers["Authorization"] ?? "Bearer \(key)"
        headers = withUserAgentSuffix(headers, "ai-sdk-mistral/4.0.72")
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? "https://api.mistral.ai/v1")
        http = AIProviderHTTPClient(providerID: "mistral", headers: headers, transport: configuration.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: configuration.queryParams) })
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        MistralLanguageModel(modelID: modelID, http: http)
    }

    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        MistralEmbeddingModel(modelID: modelID, http: http)
    }

    public func imageModel(_ modelID: String) throws -> any ImageModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .image, modelID: modelID)
    }

    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel {
        MistralTranscriptionModel(modelID: modelID, http: http)
    }

    public func speechModel(_ modelID: String) throws -> any SpeechModel {
        MistralSpeechModel(modelID: modelID, http: http)
    }

    public func videoModel(_ modelID: String) throws -> any VideoModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .video, modelID: modelID)
    }

    public func rerankingModel(_ modelID: String) throws -> any RerankingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID)
    }

    public func conversation(_ modelID: String) throws -> any LanguageModel { var configured = http; configured.providerID = "mistral.conversation"; return MistralConversationLanguageModel(modelID: modelID, http: configured) }
    public func chatModel(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
    public func reranking(_ modelID: String) throws -> any RerankingModel { try rerankingModel(modelID) }
}

public extension AIProviders {
    static func mistral(configuration: MistralProviderSettings) throws -> MistralProvider {
        try MistralProvider(configuration: configuration)
    }
}

struct MistralHTTPConfiguration: AIProviderHTTPConfiguration {
    var http: AIProviderHTTPClient
}
