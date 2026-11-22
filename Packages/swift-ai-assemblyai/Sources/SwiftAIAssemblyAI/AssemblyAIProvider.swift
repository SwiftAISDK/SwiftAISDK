import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public struct AssemblyAIProviderSettings: Sendable {
    public var apiKey: String?
    /// Supplies a fresh API key immediately before each authenticated request.
    public var apiKeyProvider: (@Sendable () async throws -> String)?
    /// Overrides the transcription API origin.
    public var baseURL: String?
    /// Overrides the speech generation API origin.
    public var speechBaseURL: String?
    public var headers: [String: String]
    public var queryParams: [String: String]
    public var transport: any AITransport

    public init(apiKey: String? = nil, apiKeyProvider: (@Sendable () async throws -> String)? = nil, baseURL: String? = nil, headers: [String: String] = [:],
                queryParams: [String: String] = [:], transport: any AITransport = URLSessionTransport.shared) {
        self.init(apiKey: apiKey, apiKeyProvider: apiKeyProvider, baseURL: baseURL, speechBaseURL: nil,
                  headers: headers, queryParams: queryParams, transport: transport)
    }

    public init(apiKey: String? = nil, apiKeyProvider: (@Sendable () async throws -> String)? = nil,
                baseURL: String? = nil, speechBaseURL: String?, headers: [String: String] = [:],
                queryParams: [String: String] = [:], transport: any AITransport = URLSessionTransport.shared) {
        self.apiKey = apiKey
        self.apiKeyProvider = apiKeyProvider
        self.baseURL = baseURL
        self.speechBaseURL = speechBaseURL
        self.headers = headers
        self.queryParams = queryParams
        self.transport = transport
    }
}

public final class AssemblyAIProvider: AIProvider, Sendable {
    public let providerID = "assemblyai"
    public let supportedCapabilities: Set<ModelCapability> = [.transcription, .speech]
    private let transcriptionConfig: AssemblyAIModelConfiguration
    private let speechHTTP: AIProviderHTTPClient

    public init(configuration: AssemblyAIProviderSettings = .init()) throws {
        var resolvedSettings = configuration
        if let supplier = resolvedSettings.apiKeyProvider {
            let credential = AIAsyncCredential(supplier)
            resolvedSettings.apiKey = credential.placeholder
            resolvedSettings.transport = credential.resolvingTransport(resolvedSettings.transport)
        }
        let configuration = resolvedSettings
        let names = ["ASSEMBLYAI_API_KEY"]
        guard let key = configuration.apiKey ?? environmentValue(names) else {
            throw AIError.missingAPIKey(provider: "assemblyai", environmentVariables: names)
        }
        var headers = normalizeHeaders(configuration.headers)
        headers["authorization"] = headers["authorization"] ?? "\(key)"
        let requestHeaders = withUserAgentSuffix(headers, "ai-sdk-assemblyai/3.0.85")
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? "https://api.assemblyai.com")
        let speechBaseURL = withoutTrailingSlash(configuration.speechBaseURL ?? "https://tts.us.assemblyai.com")
        func http(baseURL: String) -> AIProviderHTTPClient {
            AIProviderHTTPClient(providerID: "assemblyai", headers: requestHeaders, transport: configuration.transport,
                url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: configuration.queryParams) })
        }
        transcriptionConfig = AssemblyAIModelConfiguration(http: http(baseURL: baseURL), baseURL: baseURL)
        speechHTTP = http(baseURL: speechBaseURL)
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
        AssemblyAITranscriptionModel(modelID: modelID, config: transcriptionConfig)
    }

    public func speechModel(_ modelID: String) throws -> any SpeechModel {
        speech(modelID)
    }

    public func speech(_ modelID: String) -> AssemblyAISpeechModel {
        AssemblyAISpeechModel(modelID: modelID, http: speechHTTP)
    }

    public func videoModel(_ modelID: String) throws -> any VideoModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .video, modelID: modelID)
    }

    public func rerankingModel(_ modelID: String) throws -> any RerankingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID)
    }

    public func chatModel(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
}

public extension AIProviders {
    static func assemblyAI(configuration: AssemblyAIProviderSettings) throws -> AssemblyAIProvider {
        try AssemblyAIProvider(configuration: configuration)
    }
}

public struct AssemblyAIModelConfiguration: AIProviderHTTPConfiguration {
    public var http: AIProviderHTTPClient
    public var baseURL: String
    public init(http: AIProviderHTTPClient, baseURL: String) {
        self.http = http; self.baseURL = withoutTrailingSlash(baseURL)
    }
}
