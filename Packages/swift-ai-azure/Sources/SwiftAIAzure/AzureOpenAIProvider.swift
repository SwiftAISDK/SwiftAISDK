import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAI
import SwiftAIOpenAICompatible
import SwiftAIDeepSeek


public typealias AzureOpenAITokenProvider = @Sendable () async throws -> String

/// Identifies the underlying model while Azure requests continue to use the deployment ID.
public struct AzureOpenAILanguageModelSettings: Equatable, Sendable {
    public var modelID: String?

    public init(modelID: String? = nil) {
        self.modelID = modelID
    }
}

public final class AzureOpenAIProvider: AIProvider, @unchecked Sendable {
    public let providerID = "azure"
    public let supportedCapabilities: Set<ModelCapability> = [.language, .completion, .embedding, .image, .transcription, .speech]
    private let provider: AzureHostedModels
    private let config: OpenAIModelConfiguration
    private let settings: AzureOpenAIProviderSettings
    private let audioConfig: AzureAudioConfig

    public init(
        resourceName: String? = nil,
        apiVersion: String = "v1",
        useDeploymentBasedURLs: Bool = false,
        tokenProvider: AzureOpenAITokenProvider? = nil,
        configuration settings: AzureOpenAIProviderSettings,
        audioSettings: AzureOpenAIAudioSettings = .init()
    ) throws {
        self.settings = settings
        if settings.apiKey != nil, tokenProvider != nil {
            throw AIError.invalidArgument(argument: "apiKey/tokenProvider", message: "Both apiKey and tokenProvider were provided. Please use only one authentication method.")
        }
        let resolvedResourceName = resourceName ?? ProcessInfo.processInfo.environment["AZURE_RESOURCE_NAME"]
        if settings.baseURL == nil, let resolvedResourceName {
            try validateHostnamePart(resolvedResourceName, argument: "resourceName")
        }
        let basePrefix = settings.baseURL ?? resolvedResourceName.map { "https://\($0).openai.azure.com/openai" }
        guard let basePrefix else {
            throw AIError.invalidURL("Azure requires ProviderSettings.baseURL or AZURE_RESOURCE_NAME/resourceName.")
        }
        var headers = settings.headers
        if tokenProvider == nil {
            let key = settings.apiKey ?? environmentValue(["AZURE_API_KEY"])
            guard let key else {
                throw AIError.missingAPIKey(provider: providerID, environmentVariables: ["AZURE_API_KEY"])
            }
            headers["api-key"] = headers["api-key"] ?? key
        }
        headers = withUserAgentSuffix(headers, "ai-sdk-azure/4.0.110")
        let baseURL = withoutTrailingSlash(basePrefix)
        let baseURLInfo = try azureOpenAIBaseURLInfo(settings.baseURL)
        let transport = tokenProvider.map { AzureOpenAITokenProviderTransport(base: settings.transport, tokenProvider: $0) } ?? settings.transport
        let http = AIProviderHTTPClient(providerID: providerID, headers: headers, transport: transport, url: { modelID, path in
            let urlString: String
            if useDeploymentBasedURLs {
                urlString = "\(baseURL)/deployments/\(modelID)\(path)"
            } else if !baseURLInfo.isAzureOpenAI || baseURLInfo.isVersioned {
                urlString = "\(baseURL)\(path)"
            } else {
                urlString = "\(baseURL)/v1\(path)"
            }
            guard var components = URLComponents(string: urlString) else { throw AIError.invalidURL(urlString) }
            if useDeploymentBasedURLs || (
                baseURLInfo.isAzureOpenAI
                    && !baseURLInfo.isVersioned
                    && !baseURLInfo.isFoundryProject
            ) {
                components.queryItems = [URLQueryItem(name: "api-version", value: apiVersion)]
            }
            guard let url = components.url else { throw AIError.invalidURL(urlString) }
            return url
        })
        var config = OpenAIModelConfiguration(http: http, baseURL: baseURL, openAIBackedProviderRoot: "azure")
        config.supportsStructuredOutputs = settings.supportsStructuredOutputs
        config.transformRequestBody = settings.transformRequestBody
        config.explicitMessageItemType = baseURLInfo.isFoundryProject
        self.config = config
        audioConfig = AzureAudioConfig(resourceName: resolvedResourceName, settings: audioSettings, apiKey: settings.apiKey ?? environmentValue(["AZURE_API_KEY"]), headers: settings.headers, transport: transport, downloadTransport: settings.transport, tokenProvider: tokenProvider)
        provider = AzureHostedModels(config: config, settings: settings)
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel { try provider.responsesModel(modelID) }
    public func languageModel(_ deploymentID: String, settings: AzureOpenAILanguageModelSettings) throws -> any LanguageModel {
        try languageProvider(deploymentID: deploymentID).responsesModel(settings.modelID ?? deploymentID)
    }
    public func callAsFunction(_ deploymentID: String, settings: AzureOpenAILanguageModelSettings) throws -> any LanguageModel {
        try languageModel(deploymentID, settings: settings)
    }
    public func chatModel(_ deploymentID: String, settings: AzureOpenAILanguageModelSettings) throws -> any LanguageModel {
        try languageProvider(deploymentID: deploymentID).chatModel(settings.modelID ?? deploymentID)
    }
    public func chat(_ deploymentID: String, settings: AzureOpenAILanguageModelSettings) throws -> any LanguageModel {
        try chatModel(deploymentID, settings: settings)
    }
    public func completionModel(_ deploymentID: String, settings: AzureOpenAILanguageModelSettings) throws -> any LanguageModel {
        try languageProvider(deploymentID: deploymentID).completionModel(settings.modelID ?? deploymentID)
    }
    public func completion(_ deploymentID: String, settings: AzureOpenAILanguageModelSettings) throws -> any LanguageModel {
        try completionModel(deploymentID, settings: settings)
    }
    public func responses(_ deploymentID: String, settings: AzureOpenAILanguageModelSettings) throws -> any LanguageModel {
        try languageModel(deploymentID, settings: settings)
    }

    private func languageProvider(deploymentID: String) -> AzureHostedModels {
        var config = self.config
        config.http.requestModelID = deploymentID
        return AzureHostedModels(config: config, settings: settings)
    }
    public func chatModel(_ modelID: String) throws -> any LanguageModel { try provider.chatModel(modelID) }
    public func chat(_ modelID: String) throws -> any LanguageModel { try chatModel(modelID) }
    public func deepseek(_ modelID: String) throws -> any LanguageModel {
        let http = config.withProviderID("azure.deepseek").http
        return DeepSeekLanguageModel(modelID: modelID,
            config: DeepSeekModelConfiguration(http: http, baseURL: config.baseURL,
                                               supportsThinking: false, supportsStructuredOutputs: true))
    }
    public func completionModel(_ modelID: String) throws -> any LanguageModel { try provider.completionModel(modelID) }
    public func completion(_ modelID: String) throws -> any LanguageModel { try completionModel(modelID) }
    public func responses(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel { try provider.embeddingModel(modelID) }
    public func imageModel(_ modelID: String) throws -> any ImageModel {
        AzureImageModel(modelID: modelID, openAI: try provider.imageModel(modelID), config: audioConfig)
    }
    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel {
        AzureTranscriptionModel(modelID: modelID, openAI: try provider.transcriptionModel(modelID), config: audioConfig)
    }
    public func streamingTranscriptionModel(_ modelID: String) throws -> any StreamingTranscriptionModel {
        AzureTranscriptionModel(modelID: modelID, openAI: try provider.transcriptionModel(modelID), config: audioConfig)
    }

    public func speechModel(_ modelID: String) throws -> any SpeechModel {
        AzureSpeechModel(modelID: modelID, openAI: try provider.speechModel(modelID), config: audioConfig)
    }
    public func videoModel(_ modelID: String) throws -> any VideoModel { try provider.videoModel(modelID) }
    public func rerankingModel(_ modelID: String) throws -> any RerankingModel { try provider.rerankingModel(modelID) }

}

private struct AzureOpenAIBaseURLInfo {
    var isAzureOpenAI: Bool
    var isFoundryProject: Bool
    var isVersioned: Bool
}

private func azureOpenAIBaseURLInfo(_ baseURL: String?) throws -> AzureOpenAIBaseURLInfo {
    guard let baseURL else {
        return AzureOpenAIBaseURLInfo(
            isAzureOpenAI: true,
            isFoundryProject: false,
            isVersioned: false
        )
    }
    guard let components = URLComponents(string: baseURL),
          let hostname = components.host?.lowercased() else {
        throw AIError.invalidURL(baseURL)
    }
    let isFoundryHost = hostname.hasSuffix(".services.ai.azure.com")
    let isAzureOpenAI = hostname.hasSuffix(".openai.azure.com")
        || isFoundryHost
        || hostname.hasSuffix(".cognitiveservices.azure.com")
    let pathname = components.path.replacingOccurrences(
        of: #"/+$"#,
        with: "",
        options: .regularExpression
    )
    return AzureOpenAIBaseURLInfo(
        isAzureOpenAI: isAzureOpenAI,
        isFoundryProject: isFoundryHost && pathname.hasPrefix("/api/projects/"),
        isVersioned: isAzureOpenAI && pathname.lowercased().hasSuffix("/openai/v1")
    )
}

struct AzureOpenAITokenProviderTransport: AIStreamingTransport {
    var base: any AITransport
    var tokenProvider: AzureOpenAITokenProvider

    func send(_ request: AIHTTPRequest) async throws -> AIHTTPResponse {
        try await base.send(authenticatedRequest(request))
    }

    func stream(_ request: AIHTTPRequest) async throws -> AIHTTPStreamResponse {
        let streamingTransport = try requireStreamingTransport(base, providerID: "azure")
        return try await streamingTransport.stream(authenticatedRequest(request))
    }

    private func authenticatedRequest(_ request: AIHTTPRequest) async throws -> AIHTTPRequest {
        var request = request
        if !request.headers.keys.contains(where: { $0.caseInsensitiveCompare("authorization") == .orderedSame }) {
            request.headers["authorization"] = "Bearer \(try await tokenProvider())"
        }
        return request
    }
}
private struct AzureHostedModels: Sendable {
    let config: OpenAIModelConfiguration
    let settings: AzureOpenAIProviderSettings

    private func wire(_ surface: String) -> OpenAICompatibleModelConfiguration {
        var value = config.withProviderID("azure.\(surface)").compatibleConfiguration()
        value.includeUsage = settings.includeUsage
        value.maxEmbeddingsPerCall = settings.maxEmbeddingsPerCall
        return value
    }
    func responsesModel(_ modelID: String) throws -> any LanguageModel {
        OpenAICompatibleResponsesModel(modelID: modelID, config: config.withProviderID("azure.responses"))
    }
    func chatModel(_ modelID: String) throws -> any LanguageModel {
        OpenAICompatibleChatModel(modelID: modelID, config: wire("chat"))
    }
    func completionModel(_ modelID: String) throws -> any LanguageModel {
        OpenAICompatibleCompletionModel(modelID: modelID, config: wire("completion"))
    }
    func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        OpenAICompatibleEmbeddingModel(modelID: modelID, config: wire("embeddings"))
    }
    func imageModel(_ modelID: String) throws -> any ImageModel {
        OpenAICompatibleImageModel(modelID: modelID, config: wire("image"))
    }
    func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel {
        OpenAICompatibleTranscriptionModel(modelID: modelID, config: config.withProviderID("azure.transcription"))
    }
    func speechModel(_ modelID: String) throws -> any SpeechModel {
        OpenAICompatibleSpeechModel(modelID: modelID, config: config.withProviderID("azure.speech"))
    }
    func videoModel(_ modelID: String) throws -> any VideoModel {
        throw AIError.unsupportedModel(provider: "azure", capability: .video, modelID: modelID)
    }
    func rerankingModel(_ modelID: String) throws -> any RerankingModel {
        throw AIError.unsupportedModel(provider: "azure", capability: .reranking, modelID: modelID)
    }
}

public extension AIProviders {
    static func azure(resourceName: String? = nil, apiVersion: String = "v1", useDeploymentBasedURLs: Bool = false,
                      tokenProvider: AzureOpenAITokenProvider? = nil, configuration: AzureOpenAIProviderSettings,
                      audioSettings: AzureOpenAIAudioSettings = .init()) throws -> AzureOpenAIProvider {
        try AzureOpenAIProvider(resourceName: resourceName, apiVersion: apiVersion, useDeploymentBasedURLs: useDeploymentBasedURLs,
                               tokenProvider: tokenProvider, configuration: configuration, audioSettings: audioSettings)
    }
}
