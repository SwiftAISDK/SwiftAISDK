import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIAnthropic
import SwiftAIOpenAICompatible
import SwiftAIOpenAI

/// Settings for the OpenAI-compatible and Anthropic endpoints hosted by Vertex.
public struct GoogleVertexHostedProviderSettings: Sendable {
    public var apiKey: String?
    public var baseURL: String?
    public var headers: [String: String]
    public var queryParams: [String: String]
    public var transport: any AITransport
    public var includeUsage: Bool
    public var supportsStructuredOutputs: Bool
    public var supportsMultiPartToolContent: Bool
    public var maxEmbeddingsPerCall: Int?
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public var transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])?

    public init(apiKey: String? = nil, baseURL: String? = nil, headers: [String: String] = [:],
                queryParams: [String: String] = [:], transport: any AITransport = URLSessionTransport.shared,
                includeUsage: Bool = false, supportsStructuredOutputs: Bool = false,
                supportsMultiPartToolContent: Bool = false, maxEmbeddingsPerCall: Int? = nil,
                transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil,
                transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])? = nil) {
        self.apiKey = apiKey; self.baseURL = baseURL; self.headers = headers; self.queryParams = queryParams
        self.transport = transport; self.includeUsage = includeUsage
        self.supportsStructuredOutputs = supportsStructuredOutputs
        self.supportsMultiPartToolContent = supportsMultiPartToolContent
        self.maxEmbeddingsPerCall = maxEmbeddingsPerCall
        self.transformRequestBody = transformRequestBody
        self.transformRequestBodyWithWarnings = transformRequestBodyWithWarnings
    }
}

public enum GoogleVertexHostedEndpoint: Sendable { case maaS, xai, anthropic }

/// Vertex endpoint policy composed with the original shared wire implementations.
public final class GoogleVertexHostedProvider: AIProvider, Sendable {
    public let providerID: String
    public let supportedCapabilities: Set<ModelCapability>
    private let endpoint: GoogleVertexHostedEndpoint
    private let compatible: OpenAICompatibleModelConfiguration
    private let anthropic: AnthropicModelConfiguration

    public init(endpoint: GoogleVertexHostedEndpoint, project: String? = nil, location: String? = nil,
                configuration settings: GoogleVertexHostedProviderSettings) throws {
        self.endpoint = endpoint
        switch endpoint {
        case .maaS: providerID = "googleVertex.maas"; supportedCapabilities = [.language, .completion, .embedding, .image]
        case .xai: providerID = "googleVertex.xai"; supportedCapabilities = [.language]
        case .anthropic: providerID = "googleVertex.anthropic"; supportedCapabilities = [.language]
        }
        let names = ["GOOGLE_VERTEX_ACCESS_TOKEN", "GOOGLE_ACCESS_TOKEN"]
        guard let key = settings.apiKey ?? environmentValue(names) else {
            throw AIError.missingAPIKey(provider: providerID, environmentVariables: names)
        }
        // Preserve the xAI factory's validation of its default project URL even
        // when a caller supplies an endpoint override.
        let defaultURL: String
        switch endpoint {
        case .maaS: defaultURL = try settings.baseURL ?? googleVertexOpenAIBaseURL(project: project, location: location)
        case .xai: defaultURL = try googleVertexOpenAIBaseURL(project: project, location: location)
        case .anthropic: defaultURL = try settings.baseURL ?? googleVertexAnthropicBaseURL(project: project, location: location)
        }
        let baseURL = withoutTrailingSlash(settings.baseURL ?? defaultURL)
        var headers = settings.headers
        headers["Authorization"] = headers["Authorization"] ?? "Bearer \(key)"
        let http = AIProviderHTTPClient(providerID: providerID, headers: headers, transport: settings.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: settings.queryParams) })
        var openAI = OpenAIModelConfiguration(http: http, baseURL: baseURL, openAIBackedProviderRoot: nil)
        openAI.supportsStructuredOutputs = settings.supportsStructuredOutputs
        openAI.transformRequestBody = settings.transformRequestBody
        var compatible = openAI.compatibleConfiguration()
        compatible.includeUsage = settings.includeUsage
        compatible.supportsMultiPartToolContent = settings.supportsMultiPartToolContent
        compatible.maxEmbeddingsPerCall = settings.maxEmbeddingsPerCall
        compatible.transformRequestBodyWithWarnings = settings.transformRequestBodyWithWarnings
        if case .maaS = endpoint {
            compatible.transformRequestBody = { googleVertexMaaSRequestBody(settings.transformRequestBody?($0) ?? $0) }
        }
        if case .xai = endpoint {
            compatible.prepareBody = { body, _, _, _ in
                var body = body; body.removeValue(forKey: "reasoning_effort"); return body
            }
        }
        self.compatible = compatible
        var anthropicHTTP = http
        anthropicHTTP.providerID = "googleVertex.anthropic.messages"
        self.anthropic = AnthropicModelConfiguration(baseURL: baseURL, http: anthropicHTTP,
            transformRequestBody: settings.transformRequestBody)
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        if case .anthropic = endpoint {
            return AnthropicLanguageModel(modelID: modelID, config: anthropic,
                transformRequestHeaders: googleVertexAnthropicRequestHeaders)
        }
        return OpenAICompatibleChatModel(modelID: modelID, config: compatible)
    }
    public func chatModel(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
    public func completionModel(_ modelID: String) throws -> any LanguageModel {
        try require(.completion, modelID); return OpenAICompatibleCompletionModel(modelID: modelID, config: compatible)
    }
    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        try require(.embedding, modelID); return OpenAICompatibleEmbeddingModel(modelID: modelID, config: compatible)
    }
    public func imageModel(_ modelID: String) throws -> any ImageModel {
        try require(.image, modelID); return OpenAICompatibleImageModel(modelID: modelID, config: compatible)
    }
    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel { throw unsupported(.transcription, modelID) }
    public func speechModel(_ modelID: String) throws -> any SpeechModel { throw unsupported(.speech, modelID) }
    public func videoModel(_ modelID: String) throws -> any VideoModel { throw unsupported(.video, modelID) }
    public func rerankingModel(_ modelID: String) throws -> any RerankingModel { throw unsupported(.reranking, modelID) }
    private func unsupported(_ capability: ModelCapability, _ modelID: String) -> AIError {
        .unsupportedModel(provider: providerID, capability: capability, modelID: modelID)
    }
    private func require(_ capability: ModelCapability, _ modelID: String) throws {
        guard supportedCapabilities.contains(capability) else { throw unsupported(capability, modelID) }
    }
}

public extension AIProviders {
    static func googleVertex(configuration: GoogleVertexProviderSettings) throws -> GoogleVertexProvider {
        try GoogleVertexProvider(settings: configuration)
    }
    static func googleVertexMaaS(project: String? = nil, location: String? = nil,
                                 configuration: GoogleVertexHostedProviderSettings) throws -> GoogleVertexHostedProvider {
        try GoogleVertexHostedProvider(endpoint: .maaS, project: project, location: location, configuration: configuration)
    }
    static func googleVertexXAI(project: String? = nil, location: String? = nil,
                                configuration: GoogleVertexHostedProviderSettings) throws -> GoogleVertexHostedProvider {
        try GoogleVertexHostedProvider(endpoint: .xai, project: project, location: location, configuration: configuration)
    }
    static func googleVertexAnthropic(project: String? = nil, location: String? = nil,
                                      configuration: GoogleVertexHostedProviderSettings) throws -> GoogleVertexHostedProvider {
        try GoogleVertexHostedProvider(endpoint: .anthropic, project: project, location: location, configuration: configuration)
    }
}
