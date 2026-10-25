import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIOpenAICompatible
import SwiftAIProviderUtilities

public struct FireworksProviderSettings: Sendable {
    public var apiKey: String?
    public var baseURL: String?
    public var headers: [String: String]
    public var queryParams: [String: String]
    public var includeUsage: Bool
    public var supportsStructuredOutputs: Bool
    public var supportsMultiPartToolContent: Bool
    public var maxEmbeddingsPerCall: Int?
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public var transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])?
    public var transport: any AITransport

    public init(apiKey: String? = nil, baseURL: String? = nil, headers: [String: String] = [:],
                queryParams: [String: String] = [:], transport: any AITransport = URLSessionTransport.shared,
                includeUsage: Bool = false, supportsStructuredOutputs: Bool = false, supportsMultiPartToolContent: Bool = false, maxEmbeddingsPerCall: Int? = nil, transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil, transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])? = nil) {
        self.apiKey = apiKey; self.baseURL = baseURL; self.headers = headers
        self.queryParams = queryParams; self.transport = transport
        self.includeUsage = includeUsage; self.supportsStructuredOutputs = supportsStructuredOutputs; self.supportsMultiPartToolContent = supportsMultiPartToolContent; self.maxEmbeddingsPerCall = maxEmbeddingsPerCall; self.transformRequestBody = transformRequestBody; self.transformRequestBodyWithWarnings = transformRequestBodyWithWarnings
    }
}

public final class FireworksProvider: AIProvider, Sendable {
    public let providerID = "fireworks"
    public let supportedCapabilities: Set<ModelCapability> = [.language, .embedding, .completion, .image]
    private let config: FireworksModelConfiguration

    public init(configuration: FireworksProviderSettings = .init()) throws {
        let names = ["FIREWORKS_API_KEY"]
        guard let key = configuration.apiKey ?? environmentValue(names) else {
            throw AIError.missingAPIKey(provider: "fireworks", environmentVariables: names)
        }
        var headers = configuration.headers
        headers["Authorization"] = headers["Authorization"] ?? "Bearer \(key)"
        headers = withUserAgentSuffix(headers, "ai-sdk-fireworks/3.0.81")
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? "https://api.fireworks.ai/inference/v1")
        let http = AIProviderHTTPClient(providerID: "fireworks", headers: headers, transport: configuration.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: configuration.queryParams) })
        config = FireworksModelConfiguration(http: http, baseURL: baseURL ,includeUsage: configuration.includeUsage, supportsStructuredOutputs: configuration.supportsStructuredOutputs, supportsMultiPartToolContent: configuration.supportsMultiPartToolContent, maxEmbeddingsPerCall: configuration.maxEmbeddingsPerCall, transformRequestBody: configuration.transformRequestBody, transformRequestBodyWithWarnings: configuration.transformRequestBodyWithWarnings)
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        OpenAICompatibleChatModel(modelID: modelID, config: compatibleConfiguration(surface: "chat"))
    }

    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        OpenAICompatibleEmbeddingModel(modelID: modelID, config: compatibleConfiguration(surface: "embedding"))
    }

    public func imageModel(_ modelID: String) throws -> any ImageModel {
        FireworksImageModel(modelID: modelID, config: config)
    }

    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .transcription, modelID: modelID)
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

    private func compatibleConfiguration(surface: String) -> OpenAICompatibleModelConfiguration {
        var http = config.http
        http.providerID = "fireworks.\(surface)"
        var wire = OpenAICompatibleModelConfiguration(http: http, baseURL: config.baseURL)
        wire.usesGenericOpenAICompatibleProviderOptions = false
        wire.allowsEmptyTextResponse = false
        wire.includeUsage = config.includeUsage
        wire.supportsStructuredOutputs = config.supportsStructuredOutputs
        wire.supportsMultiPartToolContent = config.supportsMultiPartToolContent
        wire.maxEmbeddingsPerCall = config.maxEmbeddingsPerCall
        wire.transformRequestBody = config.transformRequestBody
        wire.transformRequestBodyWithWarnings = config.transformRequestBodyWithWarnings
        wire.supportsStructuredOutputs = true
        wire.includeUsage = true
        wire.prepareBody = { body, _, _, warnings in fireworksChatBody(from: body, warnings: &warnings) }
        return wire
    }

    public func completionModel(_ modelID: String) throws -> any LanguageModel { OpenAICompatibleCompletionModel(modelID: modelID, config: compatibleConfiguration(surface: "completion")) }
    public func completion(_ modelID: String) throws -> any LanguageModel { try completionModel(modelID) }

    public func chatModel(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
}

public extension AIProviders {
    static func fireworks(configuration: FireworksProviderSettings) throws -> FireworksProvider {
        try FireworksProvider(configuration: configuration)
    }
}

public struct FireworksModelConfiguration: AIProviderHTTPConfiguration {
    public var http: AIProviderHTTPClient
    public var baseURL: String
    public var includeUsage: Bool
    public var supportsStructuredOutputs: Bool
    public var supportsMultiPartToolContent: Bool
    public var maxEmbeddingsPerCall: Int?
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public var transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])?
    public init(http: AIProviderHTTPClient, baseURL: String ,includeUsage: Bool = false, supportsStructuredOutputs: Bool = false, supportsMultiPartToolContent: Bool = false, maxEmbeddingsPerCall: Int? = nil, transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil, transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])? = nil) {
        self.http = http; self.baseURL = withoutTrailingSlash(baseURL)
        self.includeUsage = includeUsage
        self.supportsStructuredOutputs = supportsStructuredOutputs
        self.supportsMultiPartToolContent = supportsMultiPartToolContent
        self.maxEmbeddingsPerCall = maxEmbeddingsPerCall
        self.transformRequestBody = transformRequestBody
        self.transformRequestBodyWithWarnings = transformRequestBodyWithWarnings
    }
}
