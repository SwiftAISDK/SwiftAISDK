import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIBaseten
import SwiftAIDeepInfra
import SwiftAIFireworks

func basetenDefaultChatModelID(config: ModelHTTPConfig) -> String {
    basetenDefaultChatModelID(modelURL: config.modelURL)
}

func basetenChatConfig(from config: ModelHTTPConfig) throws -> ModelHTTPConfig {
    if let modelURL = try basetenChatBaseURL(modelURL: config.modelURL) {
        return config.withBaseURL(modelURL).withProviderID("baseten.chat")
    }
    return config.withProviderID("baseten.chat")
}


/// Chat, completion and embedding factories of a native package provider.
/// The umbrella registry factories for Baseten, DeepInfra and Fireworks forward
/// these surfaces to the native providers, so umbrella users get exactly the
/// package wire policy (provider options, portable reasoning, empty responses,
/// request transforms) instead of a re-implemented copy.
struct NativeOpenAICompatibleDelegate: @unchecked Sendable {
    let languageModel: (String) throws -> any LanguageModel
    let completionModel: ((String) throws -> any LanguageModel)?
    let embeddingModel: (String) throws -> any EmbeddingModel
}

func nativeOpenAICompatibleDelegate(
    providerID: String,
    apiKey: String,
    baseURL: String,
    settings: ProviderSettings
) throws -> NativeOpenAICompatibleDelegate? {
    switch providerID {
    case "baseten":
        let provider = try BasetenProvider(configuration: BasetenProviderSettings(
            apiKey: apiKey, baseURL: baseURL, modelURL: settings.modelURL, headers: settings.headers,
            queryParams: settings.queryParams, transport: settings.transport, includeUsage: settings.includeUsage,
            supportsStructuredOutputs: settings.supportsStructuredOutputs,
            supportsMultiPartToolContent: settings.supportsMultiPartToolContent,
            maxEmbeddingsPerCall: settings.maxEmbeddingsPerCall, transformRequestBody: settings.transformRequestBody,
            transformRequestBodyWithWarnings: settings.transformRequestBodyWithWarnings
        ))
        return NativeOpenAICompatibleDelegate(
            languageModel: { try provider.languageModel($0) },
            completionModel: nil,
            embeddingModel: { try provider.embeddingModel($0) }
        )
    case "deepinfra":
        let provider = try DeepInfraProvider(configuration: DeepInfraProviderSettings(
            apiKey: apiKey, baseURL: baseURL, headers: settings.headers,
            queryParams: settings.queryParams, transport: settings.transport, includeUsage: settings.includeUsage,
            supportsStructuredOutputs: settings.supportsStructuredOutputs,
            supportsMultiPartToolContent: settings.supportsMultiPartToolContent,
            maxEmbeddingsPerCall: settings.maxEmbeddingsPerCall, transformRequestBody: settings.transformRequestBody,
            transformRequestBodyWithWarnings: settings.transformRequestBodyWithWarnings
        ))
        return NativeOpenAICompatibleDelegate(
            languageModel: { try provider.languageModel($0) },
            completionModel: { try provider.completionModel($0) },
            embeddingModel: { try provider.embeddingModel($0) }
        )
    case "fireworks":
        let provider = try FireworksProvider(configuration: FireworksProviderSettings(
            apiKey: apiKey, baseURL: baseURL, headers: settings.headers,
            queryParams: settings.queryParams, transport: settings.transport, includeUsage: settings.includeUsage,
            supportsStructuredOutputs: settings.supportsStructuredOutputs,
            supportsMultiPartToolContent: settings.supportsMultiPartToolContent,
            maxEmbeddingsPerCall: settings.maxEmbeddingsPerCall, transformRequestBody: settings.transformRequestBody,
            transformRequestBodyWithWarnings: settings.transformRequestBodyWithWarnings
        ))
        return NativeOpenAICompatibleDelegate(
            languageModel: { try provider.languageModel($0) },
            completionModel: { try provider.completionModel($0) },
            embeddingModel: { try provider.embeddingModel($0) }
        )
    default:
        return nil
    }
}
