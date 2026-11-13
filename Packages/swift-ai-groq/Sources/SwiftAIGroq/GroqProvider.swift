import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public struct GroqProviderSettings: Sendable {
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

public final class GroqProvider: AIProvider, Sendable {
    public let providerID = "groq"
    public let supportedCapabilities: Set<ModelCapability> = [.language, .transcription]
    private let http: AIProviderHTTPClient

    public init(configuration: GroqProviderSettings = .init()) throws {
        var resolvedSettings = configuration
        if let supplier = resolvedSettings.apiKeyProvider {
            let credential = AIAsyncCredential(supplier)
            resolvedSettings.apiKey = credential.placeholder
            resolvedSettings.transport = credential.resolvingTransport(resolvedSettings.transport)
        }
        let configuration = resolvedSettings
        let names = ["GROQ_API_KEY"]
        guard let key = configuration.apiKey ?? environmentValue(names) else {
            throw AIError.missingAPIKey(provider: "groq", environmentVariables: names)
        }
        var headers = normalizeHeaders(configuration.headers)
        headers["authorization"] = headers["authorization"] ?? "Bearer \(key)"
        headers = withUserAgentSuffix(headers, "ai-sdk-groq/4.0.83")
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? "https://api.groq.com/openai/v1")
        http = AIProviderHTTPClient(providerID: "groq", headers: headers, transport: configuration.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: configuration.queryParams) })
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        GroqLanguageModel(modelID: modelID, http: http)
    }

    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .embedding, modelID: modelID)
    }

    public func imageModel(_ modelID: String) throws -> any ImageModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .image, modelID: modelID)
    }

    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel {
        GroqTranscriptionModel(modelID: modelID, http: http)
    }

    public func speechModel(_ modelID: String) throws -> any SpeechModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .speech, modelID: modelID)
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
    static func groq(configuration: GroqProviderSettings) throws -> GroqProvider {
        try GroqProvider(configuration: configuration)
    }
}

struct GroqHTTPConfiguration: AIProviderHTTPConfiguration {
    var http: AIProviderHTTPClient
}
