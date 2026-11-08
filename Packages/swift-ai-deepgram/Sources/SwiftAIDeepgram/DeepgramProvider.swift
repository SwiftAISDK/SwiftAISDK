import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public struct DeepgramProviderSettings: Sendable {
    public var apiKey: String?
    /// Supplies a fresh API key immediately before each authenticated request.
    public var apiKeyProvider: (@Sendable () async throws -> String)?
    public var baseURL: String?
    public var headers: [String: String]
    public var queryParams: [String: String]
    public var webSocketTransport: any AIDuplexWebSocketTransport
    public var transport: any AITransport

    /// Preserves the original initializer function-reference signature.
    public init(apiKey: String? = nil, apiKeyProvider: (@Sendable () async throws -> String)? = nil, baseURL: String? = nil, headers: [String: String] = [:],
                queryParams: [String: String] = [:], transport: any AITransport = URLSessionTransport.shared) {
        self.init(apiKey: apiKey, apiKeyProvider: apiKeyProvider, baseURL: baseURL, headers: headers,
                  queryParams: queryParams, transport: transport, webSocketTransport: URLSessionDuplexWebSocketTransport.shared)
    }

    public init(apiKey: String? = nil, apiKeyProvider: (@Sendable () async throws -> String)? = nil, baseURL: String? = nil, headers: [String: String] = [:],
                queryParams: [String: String] = [:], transport: any AITransport = URLSessionTransport.shared, webSocketTransport: any AIDuplexWebSocketTransport = URLSessionDuplexWebSocketTransport.shared) {
        self.apiKey = apiKey; self.apiKeyProvider = apiKeyProvider; self.baseURL = baseURL; self.headers = headers
        self.queryParams = queryParams; self.transport = transport; self.webSocketTransport = webSocketTransport
    }
}

public final class DeepgramProvider: AIProvider, Sendable {
    public let providerID = "deepgram"
    public let supportedCapabilities: Set<ModelCapability> = [.transcription, .speech]
    private let http: AIProviderHTTPClient
    private let webSocketTransport: any AIDuplexWebSocketTransport

    public init(configuration: DeepgramProviderSettings = .init()) throws {
        let credential = configuration.apiKeyProvider.map(AIAsyncCredential.init)
        webSocketTransport = configuration.webSocketTransport
        let names = ["DEEPGRAM_API_KEY"]
        guard let key = credential?.placeholder ?? configuration.apiKey ?? environmentValue(names) else {
            throw AIError.missingAPIKey(provider: "deepgram", environmentVariables: names)
        }
        var headers = normalizeHeaders(configuration.headers)
        headers["authorization"] = headers["authorization"] ?? "Token \(key)"
        headers = withUserAgentSuffix(headers, "ai-sdk-deepgram/3.1.48")
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? "https://api.deepgram.com")
        http = AIProviderHTTPClient(providerID: "deepgram", headers: headers, transport: configuration.transport, credentialResolver: credential,
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
        DeepgramTranscriptionModel(modelID: modelID, http: http)
    }

    public func streamingTranscriptionModel(_ modelID: String) throws -> any StreamingTranscriptionModel {
        DeepgramStreamingTranscriptionModel(modelID: modelID, http: http, webSocketTransport: webSocketTransport)
    }

    public func streamingTranscription(_ modelID: String) throws -> any StreamingTranscriptionModel { try streamingTranscriptionModel(modelID) }

    public func speechModel(_ modelID: String) throws -> any SpeechModel {
        DeepgramSpeechModel(modelID: modelID, http: http)
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
    static func deepgram(configuration: DeepgramProviderSettings) throws -> DeepgramProvider {
        try DeepgramProvider(configuration: configuration)
    }
}

struct DeepgramHTTPConfiguration: AIProviderHTTPConfiguration {
    var http: AIProviderHTTPClient
}
