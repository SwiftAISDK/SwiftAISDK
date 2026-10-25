import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public struct OpenAICompatibleProviderSettings: Sendable {
    public var name: String
    public var baseURL: String
    public var apiKey: String?
    public var headers: [String: String]
    public var queryParams: [String: String]
    public var transport: any AITransport
    public var includeUsage: Bool
    public var supportsStructuredOutputs: Bool
    public var supportsMultiPartToolContent: Bool
    public var maxEmbeddingsPerCall: Int?
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public var transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])?

    public init(name: String, baseURL: String, apiKey: String? = nil, headers: [String: String] = [:],
                queryParams: [String: String] = [:], transport: any AITransport = URLSessionTransport.shared,
                includeUsage: Bool = false, supportsStructuredOutputs: Bool = false,
                supportsMultiPartToolContent: Bool = false, maxEmbeddingsPerCall: Int? = nil,
                transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil,
                transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])? = nil) {
        self.name = name; self.baseURL = baseURL; self.apiKey = apiKey; self.headers = headers
        self.queryParams = queryParams; self.transport = transport; self.includeUsage = includeUsage
        self.supportsStructuredOutputs = supportsStructuredOutputs; self.supportsMultiPartToolContent = supportsMultiPartToolContent
        self.maxEmbeddingsPerCall = maxEmbeddingsPerCall; self.transformRequestBody = transformRequestBody
        self.transformRequestBodyWithWarnings = transformRequestBodyWithWarnings
    }
}

/// A generic compatible endpoint. No built-in provider dispatch or global default.
public final class OpenAICompatibleProvider: AIProvider, Sendable {
    public let providerID: String
    public let supportedCapabilities: Set<ModelCapability> = [.language, .completion, .embedding, .image]
    private let config: OpenAICompatibleModelConfiguration
    public init(configuration settings: OpenAICompatibleProviderSettings) {
        providerID = settings.name
        let baseURL = withoutTrailingSlash(settings.baseURL)
        var headers = settings.headers
        if let apiKey = settings.apiKey { headers["Authorization"] = headers["Authorization"] ?? "Bearer \(apiKey)" }
        headers = withUserAgentSuffix(headers, "ai-sdk-openai-compatible/3.0.78")
        var config = OpenAICompatibleModelConfiguration(http: AIProviderHTTPClient(
            providerID: settings.name, headers: headers, transport: settings.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: settings.queryParams) }
        ), baseURL: baseURL)
        config.includeUsage = settings.includeUsage; config.supportsStructuredOutputs = settings.supportsStructuredOutputs
        config.supportsMultiPartToolContent = settings.supportsMultiPartToolContent; config.maxEmbeddingsPerCall = settings.maxEmbeddingsPerCall
        config.transformRequestBody = settings.transformRequestBody; config.transformRequestBodyWithWarnings = settings.transformRequestBodyWithWarnings
        self.config = config
    }
    public func languageModel(_ modelID: String) throws -> any LanguageModel { try chatModel(modelID) }
    public func chatModel(_ modelID: String) throws -> any LanguageModel { OpenAICompatibleChatModel(modelID: modelID, config: config.withProviderID("\(providerID).chat")) }
    public func completionModel(_ modelID: String) throws -> any LanguageModel { OpenAICompatibleCompletionModel(modelID: modelID, config: config.withProviderID("\(providerID).completion")) }
    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel { OpenAICompatibleEmbeddingModel(modelID: modelID, config: config.withProviderID("\(providerID).embedding")) }
    public func imageModel(_ modelID: String) throws -> any ImageModel { OpenAICompatibleImageModel(modelID: modelID, config: config.withProviderID("\(providerID).image")) }
    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel { throw AIError.unsupportedModel(provider: providerID, capability: .transcription, modelID: modelID) }
    public func speechModel(_ modelID: String) throws -> any SpeechModel { throw AIError.unsupportedModel(provider: providerID, capability: .speech, modelID: modelID) }
    public func videoModel(_ modelID: String) throws -> any VideoModel { throw AIError.unsupportedModel(provider: providerID, capability: .video, modelID: modelID) }
    public func rerankingModel(_ modelID: String) throws -> any RerankingModel { throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID) }
}

public extension AIProviders {
    static func openAICompatible(configuration: OpenAICompatibleProviderSettings) -> OpenAICompatibleProvider { OpenAICompatibleProvider(configuration: configuration) }
}
