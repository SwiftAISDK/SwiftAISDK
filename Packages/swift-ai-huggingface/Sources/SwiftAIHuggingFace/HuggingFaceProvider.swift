import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities


public final class HuggingFaceProvider: AIProvider, @unchecked Sendable {
    public let providerID = "huggingface"
    public let supportedCapabilities: Set<ModelCapability> = [.language]
    private let config: HuggingFaceHTTPConfiguration

    public init(configuration settings: HuggingFaceProviderSettings) throws {
        var resolvedSettings = settings
        if let supplier = resolvedSettings.apiKeyProvider {
            let credential = AIAsyncCredential(supplier)
            resolvedSettings.apiKey = credential.placeholder
            resolvedSettings.transport = credential.resolvingTransport(resolvedSettings.transport)
        }
        let settings = resolvedSettings
        let names = ["HUGGINGFACE_API_KEY"]
        guard let key = settings.apiKey ?? environmentValue(names) else {
            throw AIError.missingAPIKey(provider: providerID, environmentVariables: names)
        }
        var headers = normalizeHeaders(settings.headers)
        headers["authorization"] = headers["authorization"] ?? "Bearer \(key)"
        headers = withUserAgentSuffix(headers, "ai-sdk/huggingface/2.0.82")
        let baseURL = withoutTrailingSlash(settings.baseURL ?? "https://router.huggingface.co/v1")
        config = HuggingFaceHTTPConfiguration(http: AIProviderHTTPClient(
            providerID: "huggingface.responses", headers: headers, transport: settings.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: settings.queryParams) }))
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        HuggingFaceResponsesLanguageModel(modelID: modelID, http: config.http)
    }

    public func callAsFunction(_ modelID: String) throws -> any LanguageModel {
        try languageModel(modelID)
    }

    public func responsesModel(_ modelID: String) throws -> any LanguageModel {
        try languageModel(modelID)
    }

    public func responses(_ modelID: String) throws -> any LanguageModel {
        try responsesModel(modelID)
    }

    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .embedding, modelID: modelID)
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
        throw AIError.unsupportedModel(provider: providerID, capability: .video, modelID: modelID)
    }

    public func rerankingModel(_ modelID: String) throws -> any RerankingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID)
    }
}
public extension AIProviders {
    static func huggingFace(configuration: HuggingFaceProviderSettings) throws -> HuggingFaceProvider { try HuggingFaceProvider(configuration: configuration) }
}

struct HuggingFaceHTTPConfiguration: AIProviderHTTPConfiguration { var http: AIProviderHTTPClient }
