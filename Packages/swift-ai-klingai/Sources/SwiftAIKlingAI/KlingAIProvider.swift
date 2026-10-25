import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public final class KlingAIProvider: AIProvider, Sendable {
    public let providerID = "klingai"
    public let supportedCapabilities: Set<ModelCapability> = [.video]
    private let config: KlingAIModelConfiguration

    public init(configuration: KlingAIProviderSettings = .init()) throws {
        config = try KlingAIModelConfiguration(settings: configuration)
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .language, modelID: modelID)
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
        KlingAIVideoModel(modelID: modelID, config: config)
    }

    public func rerankingModel(_ modelID: String) throws -> any RerankingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID)
    }

    public func chatModel(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
}

public extension AIProviders {
    static func klingAI(configuration: KlingAIProviderSettings) throws -> KlingAIProvider {
        try KlingAIProvider(configuration: configuration)
    }
}

public struct KlingAIModelConfiguration: AIProviderHTTPConfiguration {
    public var http: AIProviderHTTPClient
    public var baseURL: String
    public init(http: AIProviderHTTPClient, baseURL: String) {
        self.http = http; self.baseURL = withoutTrailingSlash(baseURL)
    }
}

public extension KlingAIModelConfiguration {
    init(settings: KlingAIProviderSettings) throws {
        var headers = settings.headers
        var transport = settings.transport
        if !headers.keys.contains(where: { $0.caseInsensitiveCompare("Authorization") == .orderedSame }) {
            switch try resolveKlingAIAuth(settings: settings) {
            case let .bearerToken(token):
                headers["Authorization"] = "Bearer \(token)"
            case let .legacy(accessKey, secretKey):
                transport = KlingAILegacyAuthTransport(transport: transport, accessKey: accessKey,
                                                       secretKey: secretKey, currentDate: settings.currentDate)
            }
        }
        headers = withUserAgentSuffix(headers, "ai-sdk-klingai/4.0.70")
        let baseURL = withoutTrailingSlash(settings.baseURL ?? "https://api-singapore.klingai.com")
        self.init(http: .init(providerID: "klingai", headers: headers, transport: transport,
                             url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: [:]) }), baseURL: baseURL)
    }
}
