import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAI
import SwiftAIOpenAICompatible
public struct XAIProviderSettings: Sendable {
    public var apiKey: String?
    public var baseURL: String?
    public var headers: [String: String]
    public var queryParams: [String: String]
    public var transport: any AITransport
    public var includeUsage: Bool
    public var supportsStructuredOutputs: Bool
    public var supportsMultiPartToolContent: Bool
    public var strictResponseInput: Bool
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public var transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])?
    public var batchResultDownloads: AIBatchResultDownloadSettings?
    public init(apiKey: String? = nil, baseURL: String? = nil, headers: [String: String] = [:], queryParams: [String: String] = [:], transport: any AITransport = URLSessionTransport.shared,
        includeUsage: Bool = false, supportsStructuredOutputs: Bool = false, supportsMultiPartToolContent: Bool = false, strictResponseInput: Bool = false, transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil, transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])? = nil, batchResultDownloads: AIBatchResultDownloadSettings? = nil) {
        self.apiKey = apiKey; self.baseURL = baseURL; self.headers = headers; self.queryParams = queryParams; self.transport = transport
        self.includeUsage = includeUsage
        self.supportsStructuredOutputs = supportsStructuredOutputs
        self.supportsMultiPartToolContent = supportsMultiPartToolContent
        self.strictResponseInput = strictResponseInput
        self.transformRequestBody = transformRequestBody
        self.transformRequestBodyWithWarnings = transformRequestBodyWithWarnings
        self.batchResultDownloads = batchResultDownloads
    }
}

public final class XAIProvider: AIProvider, Sendable {
    public let providerID = "xai"
    public let supportedCapabilities: Set<ModelCapability> = [.language, .image, .transcription, .speech, .video]
    private let configuration: XAIProviderSettings
    private let http: AIProviderHTTPClient
    private let baseURL: String

    public init(configuration: XAIProviderSettings = .init()) throws {
        let names = ["XAI_API_KEY"]
        guard let key = configuration.apiKey ?? environmentValue(names) else {
            throw AIError.missingAPIKey(provider: "xai", environmentVariables: names)
        }
        self.configuration = configuration
        var headers = configuration.headers
        headers["Authorization"] = headers["Authorization"] ?? "Bearer \(key)"
        headers = withUserAgentSuffix(headers, "ai-sdk-xai/5.0.30")
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? "https://api.x.ai/v1")
        self.baseURL = baseURL
        self.http = AIProviderHTTPClient(providerID: "xai", headers: headers, transport: configuration.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: configuration.queryParams) })
    }

    private func config(_ surface: String? = nil) -> XAIModelConfiguration {
        var http = http
        if let surface { http.providerID = "xai.\(surface)" }
        var responses = OpenAIModelConfiguration(http: http, baseURL: baseURL, openAIBackedProviderRoot: nil)
        responses.transformRequestBody = configuration.transformRequestBody
        responses.batchResultMaxLineBytes = configuration.batchResultDownloads?.maxLineBytes
        responses.strictResponseInput = configuration.strictResponseInput
        responses.supportsStructuredOutputs = configuration.supportsStructuredOutputs
        let providerID = http.providerID
        responses.errorHandler = { apiCallError(provider: providerID, response: $0) }
        configureXAIResponses(&responses)
        return XAIModelConfiguration(http: http, baseURL: baseURL, responsesConfiguration: responses)
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel { try responses(modelID) }
    public func responses(_ modelID: String) throws -> XAIResponsesBatchLanguageModel { XAIResponsesBatchLanguageModel(modelID: modelID, config: config("responses")) }
    public func responsesModel(_ modelID: String) throws -> XAIResponsesBatchLanguageModel { try responses(modelID) }
    public func batchLanguageModel(_ modelID: String) throws -> any BatchLanguageModel { try responses(modelID) }
    public func experimentalBatch() throws -> any AIBatchProvider { XAIBatchProvider(config: config("responses")) }
    public func chatModel(_ modelID: String) throws -> any LanguageModel {
        var wire = config("chat").openAIConfiguration.compatibleConfiguration()
        wire.includeUsage = configuration.includeUsage
        wire.supportsStructuredOutputs = configuration.supportsStructuredOutputs
        wire.supportsMultiPartToolContent = configuration.supportsMultiPartToolContent
        wire.usesGenericOpenAICompatibleProviderOptions = false
        wire.allowsEmptyTextResponse = false
        wire.transformRequestBody = configuration.transformRequestBody
        wire.transformRequestBodyWithWarnings = configuration.transformRequestBodyWithWarnings
        configureXAIChat(&wire)
        return OpenAICompatibleChatModel(modelID: modelID, config: wire)
    }
    public func chat(_ modelID: String) throws -> any LanguageModel { try chatModel(modelID) }
    public func imageModel(_ modelID: String) throws -> any ImageModel { XAIImageModel(modelID: modelID, config: config()) }
    public func videoModel(_ modelID: String) throws -> any VideoModel { XAIVideoModel(modelID: modelID, config: config()) }
    public func speechModel(_ modelID: String) throws -> any SpeechModel { XAISpeechModel(config: config("speech")) }
    public func speechModel() throws -> any SpeechModel { try speechModel("") }
    public func speech() throws -> any SpeechModel { try speechModel() }
    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel { XAITranscriptionModel(modelID: modelID, config: config("transcription")) }
    public func transcriptionModel() throws -> any TranscriptionModel { try transcriptionModel("") }
    public func transcription() throws -> any TranscriptionModel { try transcriptionModel() }
    public func streamingTranscriptionModel(_ modelID: String = "", webSocketTransport: any AIDuplexWebSocketTransport = URLSessionDuplexWebSocketTransport.shared) throws -> any StreamingTranscriptionModel {
        XAITranscriptionModel(modelID: modelID, config: config("transcription"), webSocketTransport: webSocketTransport)
    }
    public func files() throws -> XAIFileClient { XAIFileClient(config: config("files")) }
    public func realtimeModel(_ modelID: String) throws -> XAIRealtimeModel { XAIRealtimeModel(modelID: modelID, config: config("realtime")) }
    public func realtime(_ modelID: String) throws -> XAIRealtimeModel { try realtimeModel(modelID) }
    public func experimentalRealtime(_ modelID: String) throws -> any AIRealtimeModelV4 { try realtimeModel(modelID) }
    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel { throw AIError.unsupportedModel(provider: providerID, capability: .embedding, modelID: modelID) }
    public func rerankingModel(_ modelID: String) throws -> any RerankingModel { throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID) }
}

public extension AIProviders {
    static func xAI(configuration: XAIProviderSettings) throws -> XAIProvider { try XAIProvider(configuration: configuration) }
}

public struct XAIModelConfiguration: AIProviderHTTPConfiguration {
    public var http: AIProviderHTTPClient
    public var baseURL: String
    public var openAIConfiguration: OpenAIModelConfiguration
    public init(http: AIProviderHTTPClient, baseURL: String, responsesConfiguration: OpenAIModelConfiguration? = nil) {
        self.http = http; self.baseURL = withoutTrailingSlash(baseURL)
        var responses = responsesConfiguration ?? OpenAIModelConfiguration(http: http, baseURL: baseURL, openAIBackedProviderRoot: nil)
        if responsesConfiguration == nil {
            responses.errorHandler = { apiCallError(provider: http.providerID, response: $0) }
            configureXAIResponses(&responses)
        }
        self.openAIConfiguration = responses
    }
}

/// Installs xAI request and stream-error policy on the reusable Responses engine.
public func configureXAIResponses(_ configuration: inout OpenAIModelConfiguration) {
    let providerID = configuration.providerID
    let transform = configuration.transformRequestBody
    configuration.prepareResponses = { modelID, request, stream in
        try xaiResponsesPreparedRequest(modelID: modelID, providerID: providerID, request: request, stream: stream, transformRequestBody: transform)
    }
    if providerID == "xai.responses" { configuration.streamErrorParser = xaiResponsesStreamProviderError }
}

/// Installs the preserved legacy xAI Chat dialect on the compatible engine.
public func configureXAIChat(_ configuration: inout OpenAICompatibleModelConfiguration) {
    let providerID = configuration.providerID
    configuration.usage = xaiChatUsage
    configuration.responseMetadata = { raw, namespace in
        guard let tier = raw["service_tier"], tier != .null else { return [:] }
        return openAICompatibleNamespacedProviderMetadata(["serviceTier": tier], providerID: providerID, namespace: namespace)
    }
    configuration.additionalWarnings = xaiChatWarnings
    configuration.prepareBody = { body, request, _, warnings in try xaiChatBody(from: body, request: request, warnings: &warnings) }
}
