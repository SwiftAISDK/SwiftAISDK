import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public struct AlibabaProviderSettings: Sendable {
    public var apiKey: String?
    /// Supplies a fresh API key immediately before each authenticated request.
    public var apiKeyProvider: (@Sendable () async throws -> String)?
    public var baseURL: String?
    public var headers: [String: String]
    public var queryParams: [String: String]
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public var transport: any AITransport

    public init(apiKey: String? = nil, apiKeyProvider: (@Sendable () async throws -> String)? = nil, baseURL: String? = nil, headers: [String: String] = [:],
                queryParams: [String: String] = [:], transport: any AITransport = URLSessionTransport.shared,
                transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil) {
        self.apiKey = apiKey; self.apiKeyProvider = apiKeyProvider; self.baseURL = baseURL; self.headers = headers
        self.queryParams = queryParams; self.transport = transport
        self.transformRequestBody = transformRequestBody
    }
}

public final class AlibabaProvider: AIProvider, Sendable {
    public let providerID = "alibaba"
    public let supportedCapabilities: Set<ModelCapability> = [.language, .embedding, .video]
    private let config: AlibabaModelConfiguration

    public init(configuration: AlibabaProviderSettings = .init()) throws {
        var resolvedSettings = configuration
        if let supplier = resolvedSettings.apiKeyProvider {
            let credential = AIAsyncCredential(supplier)
            resolvedSettings.apiKey = credential.placeholder
            resolvedSettings.transport = credential.resolvingTransport(resolvedSettings.transport)
        }
        let configuration = resolvedSettings
        let names = ["ALIBABA_API_KEY", "DASHSCOPE_API_KEY"]
        guard let key = configuration.apiKey ?? environmentValue(names) else {
            throw AIError.missingAPIKey(provider: "alibaba", environmentVariables: names)
        }
        var headers = normalizeHeaders(configuration.headers)
        headers["authorization"] = headers["authorization"] ?? "Bearer \(key)"
        headers = withUserAgentSuffix(headers, "ai-sdk-alibaba/2.0.80")
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? "https://dashscope-intl.aliyuncs.com/compatible-mode/v1")
        let http = AIProviderHTTPClient(providerID: "alibaba", headers: headers, transport: configuration.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: configuration.queryParams) })
        config = AlibabaModelConfiguration(http: http, baseURL: baseURL ,transformRequestBody: configuration.transformRequestBody)
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        AlibabaLanguageModel(modelID: modelID, config: config)
    }

    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        AlibabaEmbeddingModel(modelID: modelID, config: config)
    }

    public func imageModel(_ modelID: String) throws -> any ImageModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .image, modelID: modelID)
    }

    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .transcription, modelID: modelID)
    }

    public func speechModel(_ modelID: String) throws -> any SpeechModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .speech, modelID: modelID)
    }

    public func videoModel(_ modelID: String) throws -> any VideoModel {
        AlibabaVideoModel(modelID: modelID, config: config)
    }

    public func rerankingModel(_ modelID: String) throws -> any RerankingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID)
    }

    public func chatModel(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
}

public extension AIProviders {
    static func alibaba(configuration: AlibabaProviderSettings) throws -> AlibabaProvider {
        try AlibabaProvider(configuration: configuration)
    }
}

public struct AlibabaModelConfiguration: AIProviderHTTPConfiguration {
    public var http: AIProviderHTTPClient
    public var baseURL: String
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public init(http: AIProviderHTTPClient, baseURL: String ,transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil) {
        self.http = http; self.baseURL = withoutTrailingSlash(baseURL)
        self.transformRequestBody = transformRequestBody
    }
}
