import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible


public final class VercelProvider: AIProvider, @unchecked Sendable {
    public let providerID = "vercel"
    public let supportedCapabilities: Set<ModelCapability> = [.language]
    private let config: OpenAICompatibleModelConfiguration

    public init(configuration settings: VercelProviderSettings) throws {
        let headers = try vercelHeaders(settings: settings)
        let baseURL = withoutTrailingSlash(settings.baseURL ?? "https://api.v0.dev/v1")
        var configured = OpenAICompatibleModelConfiguration(http: AIProviderHTTPClient(
            providerID: "vercel.chat", headers: headers, transport: settings.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: settings.queryParams) }), baseURL: baseURL)
        configured.includeUsage = settings.includeUsage
        configured.supportsStructuredOutputs = settings.supportsStructuredOutputs
        configured.transformRequestBody = settings.transformRequestBody
        configured.usesGenericOpenAICompatibleProviderOptions = false
        configured.allowsEmptyTextResponse = false

        config = configured
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        OpenAICompatibleChatModel(modelID: modelID, config: config)
    }

    public func callAsFunction(_ modelID: String) throws -> any LanguageModel {
        try languageModel(modelID)
    }

    public func chatModel(_ modelID: String) throws -> any LanguageModel {
        try languageModel(modelID)
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

private func vercelHeaders(settings: VercelProviderSettings) throws -> [String: String] {
    var headers = settings.headers
    let key = settings.apiKey ?? environmentValue(["VERCEL_API_KEY"])
    guard let key else {
        throw AIError.missingAPIKey(provider: "vercel", environmentVariables: ["VERCEL_API_KEY"])
    }
    if !headers.keys.contains(where: { $0.caseInsensitiveCompare("authorization") == .orderedSame }) {
        headers["Authorization"] = "Bearer \(key)"
    }
    return withUserAgentSuffix(headers, "ai-sdk/vercel/3.0.30")
}
public extension AIProviders {
    static func vercel(configuration: VercelProviderSettings) throws -> VercelProvider { try VercelProvider(configuration: configuration) }
}
