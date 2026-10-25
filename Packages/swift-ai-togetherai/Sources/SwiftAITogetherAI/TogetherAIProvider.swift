import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIOpenAICompatible
import SwiftAIProviderUtilities

public struct TogetherAIProviderSettings: Sendable {
    public var apiKey: String?
    public var baseURL: String?
    public var headers: [String: String]
    public var queryParams: [String: String]
    public var supportsStructuredOutputs: Bool
    public var supportsMultiPartToolContent: Bool
    public var maxEmbeddingsPerCall: Int?
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public var transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])?
    public var transport: any AITransport

    public init(apiKey: String? = nil, baseURL: String? = nil, headers: [String: String] = [:],
                queryParams: [String: String] = [:], transport: any AITransport = URLSessionTransport.shared,
                supportsStructuredOutputs: Bool = false, supportsMultiPartToolContent: Bool = false, maxEmbeddingsPerCall: Int? = nil, transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil, transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])? = nil) {
        self.apiKey = apiKey; self.baseURL = baseURL; self.headers = headers
        self.queryParams = queryParams; self.transport = transport
        self.supportsStructuredOutputs = supportsStructuredOutputs; self.supportsMultiPartToolContent = supportsMultiPartToolContent; self.maxEmbeddingsPerCall = maxEmbeddingsPerCall; self.transformRequestBody = transformRequestBody; self.transformRequestBodyWithWarnings = transformRequestBodyWithWarnings
    }
}

public final class TogetherAIProvider: AIProvider, Sendable {
    public let providerID = "togetherai"
    public let supportedCapabilities: Set<ModelCapability> = [.language, .completion, .embedding, .image, .reranking]
    private let config: TogetherAIModelConfiguration

    public init(configuration: TogetherAIProviderSettings = .init()) throws {
        let names = ["TOGETHER_API_KEY", "TOGETHER_AI_API_KEY"]
        guard let key = configuration.apiKey ?? environmentValue(names) else {
            throw AIError.missingAPIKey(provider: "togetherai", environmentVariables: names)
        }
        var headers = configuration.headers
        headers["Authorization"] = headers["Authorization"] ?? "Bearer \(key)"
        headers = withUserAgentSuffix(headers, "ai-sdk-togetherai/3.0.79")
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? "https://api.together.xyz/v1")
        let http = AIProviderHTTPClient(providerID: "togetherai", headers: headers, transport: configuration.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: configuration.queryParams) })
        config = TogetherAIModelConfiguration(http: http, baseURL: baseURL ,supportsStructuredOutputs: configuration.supportsStructuredOutputs, supportsMultiPartToolContent: configuration.supportsMultiPartToolContent, maxEmbeddingsPerCall: configuration.maxEmbeddingsPerCall, transformRequestBody: configuration.transformRequestBody, transformRequestBodyWithWarnings: configuration.transformRequestBodyWithWarnings)
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        var wire = compatibleConfiguration(surface: "chat")
        wire.supportsStructuredOutputs = config.supportsStructuredOutputs || modelID == "deepseek-ai/DeepSeek-V4-Flash-0731"
        return OpenAICompatibleChatModel(modelID: modelID, config: wire)
    }

    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        OpenAICompatibleEmbeddingModel(modelID: modelID, config: compatibleConfiguration(surface: "embedding"))
    }

    public func imageModel(_ modelID: String) throws -> any ImageModel {
        TogetherAIImageModel(modelID: modelID, config: config)
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
        TogetherAIRerankingModel(modelID: modelID, config: config)
    }

    private func compatibleConfiguration(surface: String) -> OpenAICompatibleModelConfiguration {
        var http = config.http
        http.providerID = "togetherai.\(surface)"
        var wire = OpenAICompatibleModelConfiguration(http: http, baseURL: config.baseURL)
        wire.includeUsage = true
        wire.usesGenericOpenAICompatibleProviderOptions = false
        wire.allowsEmptyTextResponse = false
        wire.supportsStructuredOutputs = config.supportsStructuredOutputs
        wire.supportsMultiPartToolContent = config.supportsMultiPartToolContent
        wire.maxEmbeddingsPerCall = config.maxEmbeddingsPerCall
        wire.transformRequestBody = config.transformRequestBody
        wire.transformRequestBodyWithWarnings = config.transformRequestBodyWithWarnings
        wire.errorHandler = { apiCallError(provider: "togetherai.\(surface)", response: $0) }
        return wire
    }

    public func completionModel(_ modelID: String) throws -> any LanguageModel { OpenAICompatibleCompletionModel(modelID: modelID, config: compatibleConfiguration(surface: "completion")) }
    public func completion(_ modelID: String) throws -> any LanguageModel { try completionModel(modelID) }

    public func chatModel(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
}

public extension AIProviders {
    static func togetherAI(configuration: TogetherAIProviderSettings) throws -> TogetherAIProvider {
        try TogetherAIProvider(configuration: configuration)
    }
}

public struct TogetherAIModelConfiguration: AIProviderHTTPConfiguration {
    public var http: AIProviderHTTPClient
    public var baseURL: String
    public var supportsStructuredOutputs: Bool
    public var supportsMultiPartToolContent: Bool
    public var maxEmbeddingsPerCall: Int?
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public var transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])?
    public init(http: AIProviderHTTPClient, baseURL: String ,supportsStructuredOutputs: Bool = false, supportsMultiPartToolContent: Bool = false, maxEmbeddingsPerCall: Int? = nil, transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil, transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])? = nil) {
        self.http = http; self.baseURL = withoutTrailingSlash(baseURL)
        self.supportsStructuredOutputs = supportsStructuredOutputs
        self.supportsMultiPartToolContent = supportsMultiPartToolContent
        self.maxEmbeddingsPerCall = maxEmbeddingsPerCall
        self.transformRequestBody = transformRequestBody
        self.transformRequestBodyWithWarnings = transformRequestBodyWithWarnings
    }
}
