import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public struct LMNTProviderSettings: Sendable {
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

public final class LMNTProvider: AIProvider, Sendable {
    public let providerID = "lmnt"
    public let supportedCapabilities: Set<ModelCapability> = [.speech]
    private let http: AIProviderHTTPClient

    public init(configuration: LMNTProviderSettings = .init()) throws {
        let names = ["LMNT_API_KEY"]
        guard let key = configuration.apiKey ?? environmentValue(names) else {
            throw AIError.missingAPIKey(provider: "lmnt", environmentVariables: names)
        }
        var headers = configuration.headers
        headers["x-api-key"] = headers["x-api-key"] ?? "\(key)"
        headers = withUserAgentSuffix(headers, "ai-sdk/lmnt/3.0.36")
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? "https://api.lmnt.com")
        http = AIProviderHTTPClient(providerID: "lmnt", headers: headers, transport: configuration.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: configuration.queryParams) })
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .language, modelID: modelID)
    }

    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .embedding, modelID: modelID)
    }

    public func imageModel(_ modelID: String) throws -> any ImageModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .image, modelID: modelID)
    }

    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .transcription, modelID: modelID)
    }

    public func speechModel(_ modelID: String) throws -> any SpeechModel {
        LMNTSpeechModel(modelID: modelID, http: http)
    }

    public func videoModel(_ modelID: String) throws -> any VideoModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .video, modelID: modelID)
    }

    public func rerankingModel(_ modelID: String) throws -> any RerankingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID)
    }

    public func chatModel(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
    public func reranking(_ modelID: String) throws -> any RerankingModel { try rerankingModel(modelID) }
}

public extension AIProviders {
    static func lmnt(configuration: LMNTProviderSettings) throws -> LMNTProvider {
        try LMNTProvider(configuration: configuration)
    }
}

struct LMNTHTTPConfiguration: AIProviderHTTPConfiguration {
    var http: AIProviderHTTPClient
}
