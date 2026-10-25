import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible

public final class OpenAIProvider: AIProvider, AIEvaluationProvider, AIDecisionProvider, Sendable {
    public let providerID: String
    public let supportedCapabilities: Set<ModelCapability> = [.language, .completion, .embedding, .image, .transcription, .speech, .evaluation, .decision]
    private let config: OpenAIModelConfiguration
    private let settings: OpenAIProviderSettings

    public init(configuration settings: OpenAIProviderSettings = .init()) throws {
        self.settings = settings
        providerID = settings.name ?? "openai"
        guard let key = settings.apiKey ?? settings.environmentValue(["OPENAI_API_KEY"]) else {
            throw AIError.missingAPIKey(provider: providerID, environmentVariables: ["OPENAI_API_KEY"])
        }
        var headers = settings.headers
        headers["Authorization"] = headers["Authorization"] ?? "Bearer \(key)"
        if let organization = settings.organization { headers["OpenAI-Organization"] = headers["OpenAI-Organization"] ?? organization }
        if let project = settings.project { headers["OpenAI-Project"] = headers["OpenAI-Project"] ?? project }
        headers = withUserAgentSuffix(headers, "ai-sdk-openai/4.0.102")
        let baseURL = withoutTrailingSlash(settings.baseURL ?? settings.environmentValue(["OPENAI_BASE_URL"]) ?? "https://api.openai.com/v1")
        var config = OpenAIModelConfiguration(http: AIProviderHTTPClient(providerID: providerID, headers: headers, transport: settings.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: settings.queryParams) }), baseURL: baseURL, openAIBackedProviderRoot: providerID)
        config.transformRequestBody = settings.transformRequestBody; config.batchResultMaxLineBytes = settings.batchResultDownloads?.maxLineBytes
        config.strictResponseInput = settings.strictResponseInput; config.supportsStructuredOutputs = settings.supportsStructuredOutputs
        self.config = config
    }
    private func wire(_ surface: String) -> OpenAICompatibleModelConfiguration {
        var value = config.withProviderID("\(providerID).\(surface)").compatibleConfiguration()
        value.includeUsage = settings.includeUsage; value.maxEmbeddingsPerCall = settings.maxEmbeddingsPerCall
        value.transformRequestBodyWithWarnings = settings.transformRequestBodyWithWarnings
        return value
    }
    public func languageModel(_ modelID: String) throws -> any LanguageModel { responses(modelID) }
    public func responses(_ modelID: String) -> any BatchLanguageModel { OpenAIResponsesBatchLanguageModel(modelID: modelID, config: config.withProviderID("\(providerID).responses")) }
    public func chat(_ modelID: String) -> any LanguageModel { OpenAICompatibleChatModel(modelID: modelID, config: wire("chat")) }
    public func chatModel(_ modelID: String) throws -> any LanguageModel { chat(modelID) }
    public func completion(_ modelID: String) -> any LanguageModel { OpenAICompatibleCompletionModel(modelID: modelID, config: wire("completion")) }
    public func completionModel(_ modelID: String) throws -> any LanguageModel { completion(modelID) }
    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel { OpenAICompatibleEmbeddingModel(modelID: modelID, config: wire("embedding")) }
    public func imageModel(_ modelID: String) throws -> any ImageModel { OpenAICompatibleImageModel(modelID: modelID, config: wire("image")) }
    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel { OpenAICompatibleTranscriptionModel(modelID: modelID, config: config.withProviderID("\(providerID).transcription")) }
    public func speechModel(_ modelID: String) throws -> any SpeechModel { OpenAICompatibleSpeechModel(modelID: modelID, config: config.withProviderID("\(providerID).speech")) }
    public func decisionModel(_ modelID: String) throws -> any AIDecisionModelV4 { OpenAIDecisionModel(modelID: modelID, config: config.withProviderID("\(providerID).decision")) }
    public func evaluationModel(_ modelID: String) throws -> any AIEvaluationModelV4 { OpenAIDecisionModel(modelID: modelID, config: config.withProviderID("\(providerID).evaluation")) }
    public func experimentalDecisionModel(_ modelID: String) throws -> any AIDecisionModelV4 { try decisionModel(modelID) }
    public func batchLanguageModel(_ modelID: String) -> any BatchLanguageModel { responses(modelID) }
    public func experimentalBatch() -> any AIBatchProvider { OpenAIBatchProvider(config: config.withProviderID("\(providerID).responses")) }
    public func files() -> any AIFileClient { MultipartFileClient(providerID: "\(providerID).files", providerReferenceKey: providerID, config: config, includePurpose: true, providerOptionsName: "openai") }
    public func skills() -> any AISkillsClient { OpenAISkillsClient(providerID: "\(providerID).skills", providerReferenceKey: providerID, config: config) }
    public func experimentalRealtime(_ modelID: String) throws -> any AIRealtimeModelV4 {
        guard modelID == "gpt-live-1" else { throw AIError.invalidArgument(argument: "modelID", message: "OpenAI realtime model IDs other than 'gpt-live-1' require the Realtime API, which is not yet available in SwiftAISDK.") }
        return OpenAILiveModel(modelID: modelID, config: config)
    }
    public func videoModel(_ modelID: String) throws -> any VideoModel { throw AIError.unsupportedModel(provider: providerID, capability: .video, modelID: modelID) }
    public func rerankingModel(_ modelID: String) throws -> any RerankingModel { throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID) }
}

public extension AIProviders {
    static func openAI(configuration: OpenAIProviderSettings = .init()) throws -> OpenAIProvider { try OpenAIProvider(configuration: configuration) }
}
