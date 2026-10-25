import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible


/// The published `@ai-sdk/zai` package version mirrored by this port.
public let zaiProviderVersion = "3.0.40"

/// Z.AI accepts the documented GLM identifiers as well as future model IDs.
public typealias ZAIChatModelID = String

/// Creates a Z.AI provider using the defaults from `@ai-sdk/zai`.
public func createZai(
    configuration settings: ZAIProviderSettings
) -> ZAIProvider {
    ZAIProvider(configuration: settings)
}

/// Swift acronym-cased alias for ``createZai(configuration:)``.
public func createZAI(
    configuration settings: ZAIProviderSettings
) -> ZAIProvider {
    createZai(configuration: settings)
}

/// Default Z.AI provider, equivalent to upstream `zai`.
public let zai = createZai(configuration: .init())

/// Z.AI GLM chat completions over the provider's OpenAI-compatible endpoint.
public final class ZAIProvider: AIProvider, @unchecked Sendable {
    public let providerID = "zai"
    public let supportedCapabilities: Set<ModelCapability> = [.language]

    private let config: OpenAICompatibleModelConfiguration
    private let resolveAPIKey: @Sendable () -> String?

    public init(configuration settings: ZAIProviderSettings) {
        let headers = withUserAgentSuffix(
            settings.headers,
            "ai-sdk-zai/\(zaiProviderVersion)"
        )

        let explicitAPIKey = settings.apiKey
        let configuredEnvironment = settings.environment
        resolveAPIKey = {
            if let explicitAPIKey { return explicitAPIKey }
            if let configuredEnvironment { return configuredEnvironment["ZAI_API_KEY"] }
            return environmentValue(["ZAI_API_KEY"])
        }

        let callerTransform = settings.transformRequestBody
        let baseURL = withoutTrailingSlash(settings.baseURL ?? "https://api.z.ai/api/paas/v4")
        var configured = OpenAICompatibleModelConfiguration(http: AIProviderHTTPClient(
            providerID: "zai.chat", headers: headers, transport: settings.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: settings.queryParams) }), baseURL: baseURL)
        configured.transformRequestBody = { body in
            let transformed = zaiTransformRequestBody(body)
            return callerTransform?(transformed) ?? transformed
        }
        config = configured
    }

    public func languageModel(_ modelID: ZAIChatModelID) throws -> any LanguageModel {
        ZAILanguageModel(
            modelID: modelID,
            config: config,
            resolveAPIKey: resolveAPIKey
        )
    }

    public func chatModel(_ modelID: ZAIChatModelID) throws -> any LanguageModel {
        try languageModel(modelID)
    }

    public func callAsFunction(_ modelID: ZAIChatModelID) throws -> any LanguageModel {
        try languageModel(modelID)
    }

    public func chat(_ modelID: ZAIChatModelID) throws -> any LanguageModel {
        try languageModel(modelID)
    }

    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        throw AIError.unsupportedModel(
            provider: providerID,
            capability: .embedding,
            modelID: modelID
        )
    }

    public func imageModel(_ modelID: String) throws -> any ImageModel {
        throw AIError.unsupportedModel(
            provider: providerID,
            capability: .image,
            modelID: modelID
        )
    }

    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel {
        throw AIError.unsupportedModel(
            provider: providerID,
            capability: .transcription,
            modelID: modelID
        )
    }

    public func speechModel(_ modelID: String) throws -> any SpeechModel {
        throw AIError.unsupportedModel(
            provider: providerID,
            capability: .speech,
            modelID: modelID
        )
    }

    public func videoModel(_ modelID: String) throws -> any VideoModel {
        throw AIError.unsupportedModel(
            provider: providerID,
            capability: .video,
            modelID: modelID
        )
    }

    public func rerankingModel(_ modelID: String) throws -> any RerankingModel {
        throw AIError.unsupportedModel(
            provider: providerID,
            capability: .reranking,
            modelID: modelID
        )
    }
}
public extension AIProviders {
    static func zai(configuration: ZAIProviderSettings) -> ZAIProvider { ZAIProvider(configuration: configuration) }
}
