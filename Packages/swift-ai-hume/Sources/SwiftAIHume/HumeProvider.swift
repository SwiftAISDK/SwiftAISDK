import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public struct HumeProviderSettings: Sendable {
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

public final class HumeProvider: AIProvider, Sendable {
    public let providerID = "hume"
    public let supportedCapabilities: Set<ModelCapability> = [.speech]
    private let http: AIProviderHTTPClient

    public init(configuration: HumeProviderSettings = .init()) throws {
        let names = ["HUME_API_KEY"]
        guard let key = configuration.apiKey ?? environmentValue(names) else {
            throw AIError.missingAPIKey(provider: "hume", environmentVariables: names)
        }
        var headers = configuration.headers
        headers["X-Hume-Api-Key"] = headers["X-Hume-Api-Key"] ?? "\(key)"
        headers = withUserAgentSuffix(headers, "ai-sdk-hume/3.0.68")
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? "https://api.hume.ai")
        http = AIProviderHTTPClient(providerID: "hume", headers: headers, transport: configuration.transport,
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
        HumeSpeechModel(modelID: "", http: http)
    }

    public func videoModel(_ modelID: String) throws -> any VideoModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .video, modelID: modelID)
    }

    public func rerankingModel(_ modelID: String) throws -> any RerankingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID)
    }

    public func speechModel() throws -> any SpeechModel { try speechModel("") }
    public func speech() throws -> any SpeechModel { try speechModel() }

    public func chatModel(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
    public func reranking(_ modelID: String) throws -> any RerankingModel { try rerankingModel(modelID) }
}

public extension AIProviders {
    static func hume(configuration: HumeProviderSettings) throws -> HumeProvider {
        try HumeProvider(configuration: configuration)
    }
}

struct HumeHTTPConfiguration: AIProviderHTTPConfiguration {
    var http: AIProviderHTTPClient
}
