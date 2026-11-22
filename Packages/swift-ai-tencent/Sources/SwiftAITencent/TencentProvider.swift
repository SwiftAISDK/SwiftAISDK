import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible

public let tencentProviderVersion = "3.0.5"

/// TokenHub and VOD credentials are resolved independently when a request is sent.
public struct TencentProviderSettings: Sendable {
    public var apiKey: String?
    public var apiKeyProvider: (@Sendable () async throws -> String)?
    public var baseURL: String?
    public var secretId: String?
    public var secretKey: String?
    public var sessionToken: String?
    public var subAppId: String?
    public var region: String?
    public var vodBaseURL: String?
    public var headers: [String: String]
    public var environment: [String: String]?
    public var transport: any AITransport
    public var currentDate: @Sendable () -> Date

    public init(apiKey: String? = nil, apiKeyProvider: (@Sendable () async throws -> String)? = nil,
                baseURL: String? = nil, secretId: String? = nil, secretKey: String? = nil,
                sessionToken: String? = nil, subAppId: String? = nil, region: String? = nil,
                vodBaseURL: String? = nil, headers: [String: String] = [:],
                environment: [String: String]? = nil, transport: any AITransport = URLSessionTransport.shared,
                currentDate: @escaping @Sendable () -> Date = { Date() }) {
        self.apiKey = apiKey; self.apiKeyProvider = apiKeyProvider; self.baseURL = baseURL
        self.secretId = secretId; self.secretKey = secretKey; self.sessionToken = sessionToken
        self.subAppId = subAppId; self.region = region; self.vodBaseURL = vodBaseURL
        self.headers = headers; self.environment = environment; self.transport = transport; self.currentDate = currentDate
    }
}

/// TokenHub Chat Completions uses the shared OpenAI-compatible implementation.
public typealias TencentChatLanguageModel = OpenAICompatibleChatModel

public final class TencentProvider: AIProvider, Sendable {
    public let providerID = "tencent"
    public let supportedCapabilities: Set<ModelCapability> = [.language, .video]
    private let settings: TencentProviderSettings
    public init(configuration: TencentProviderSettings = .init()) { settings = configuration }

    public func languageModel(_ modelID: String) throws -> any LanguageModel { chat(modelID) }
    public func chat(_ modelID: String) -> TencentChatLanguageModel {
        var config = OpenAICompatibleModelConfiguration(http: tencentTokenHubClient(settings, providerID: "tencent.chat"),
            baseURL: withoutTrailingSlash(settings.baseURL ?? tencentTokenHubBaseURL))
        config.includeUsage = true
        return TencentChatLanguageModel(modelID: modelID, config: config)
    }
    public func chatModel(_ modelID: String) -> TencentChatLanguageModel { chat(modelID) }
    public func videoModel(_ modelID: String) throws -> any VideoModel { try video(modelID) }
    public func video(_ modelID: String) throws -> TencentVideoModel { try TencentVideoModel(modelID: modelID, configuration: settings) }
    public func textEmbeddingModel(_ modelID: String) throws -> any EmbeddingModel { try embeddingModel(modelID) }
    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel { throw unsupported(.embedding, modelID) }
    public func imageModel(_ modelID: String) throws -> any ImageModel { throw unsupported(.image, modelID) }
    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel { throw unsupported(.transcription, modelID) }
    public func speechModel(_ modelID: String) throws -> any SpeechModel { throw unsupported(.speech, modelID) }
    public func rerankingModel(_ modelID: String) throws -> any RerankingModel { throw unsupported(.reranking, modelID) }
    private func unsupported(_ capability: ModelCapability, _ id: String) -> AIError {
        .unsupportedModel(provider: providerID, capability: capability, modelID: id)
    }
}

public func createTencent(configuration: TencentProviderSettings = .init()) -> TencentProvider { TencentProvider(configuration: configuration) }
public let tencent = createTencent()
public extension AIProviders {
    static func tencent(configuration: TencentProviderSettings) -> TencentProvider { TencentProvider(configuration: configuration) }
}

let tencentTokenHubBaseURL = "https://tokenhub-intl.tencentcloudmaas.com/v1"
let tencentVodBaseURL = "https://vod.intl.tencentcloudapi.com"
func tencentTokenHubClient(_ settings: TencentProviderSettings, providerID: String) -> AIProviderHTTPClient {
    let credential = AIAsyncCredential {
        if let supplier = settings.apiKeyProvider { return try await supplier() }
        guard let key = settings.apiKey ?? (settings.environment ?? ProcessInfo.processInfo.environment)["TENCENT_TOKENHUB_API_KEY"] else {
            throw AIError.missingAPIKey(provider: "tencent", environmentVariables: ["TENCENT_TOKENHUB_API_KEY"])
        }
        return key
    }
    var headers = normalizeHeaders(settings.headers)
    headers["authorization"] = headers["authorization"] ?? "Bearer \(credential.placeholder)"
    headers = withUserAgentSuffix(headers, "ai-sdk-tencent/\(tencentProviderVersion)")
    let baseURL = withoutTrailingSlash(settings.baseURL ?? tencentTokenHubBaseURL)
    return AIProviderHTTPClient(providerID: providerID, headers: headers, transport: settings.transport,
        credentialResolver: credential, url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: [:]) })
}
