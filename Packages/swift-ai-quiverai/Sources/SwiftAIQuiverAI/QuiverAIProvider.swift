import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenResponses

public struct QuiverAIProviderSettings: Sendable {
    public var apiKey: String?
    public var baseURL: String?
    public var headers: [String: String]
    public var queryParams: [String: String]
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public var transport: any AITransport

    public init(apiKey: String? = nil, baseURL: String? = nil, headers: [String: String] = [:],
                queryParams: [String: String] = [:], transport: any AITransport = URLSessionTransport.shared,
                transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil) {
        self.apiKey = apiKey; self.baseURL = baseURL; self.headers = headers
        self.queryParams = queryParams; self.transport = transport
        self.transformRequestBody = transformRequestBody
    }
}

public final class QuiverAIProvider: AIProvider, Sendable {
    public let providerID = "quiverai"
    public let supportedCapabilities: Set<ModelCapability> = [.language, .image]
    private let config: QuiverAIModelConfiguration

    public init(configuration: QuiverAIProviderSettings = .init()) throws {
        let names = ["QUIVERAI_API_KEY"]
        guard let key = configuration.apiKey ?? environmentValue(names) else {
            throw AIError.missingAPIKey(provider: "quiverai", environmentVariables: names)
        }
        var headers = configuration.headers
        headers["Authorization"] = headers["Authorization"] ?? "Bearer \(key)"
        headers = withUserAgentSuffix(headers, "ai-sdk-quiverai/2.0.69")
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? environmentValue(["QUIVERAI_BASE_URL"]) ?? "https://api.quiver.ai/v1")
        let http = AIProviderHTTPClient(providerID: "quiverai", headers: headers, transport: configuration.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: configuration.queryParams) })
        config = QuiverAIModelConfiguration(http: http, baseURL: baseURL ,transformRequestBody: configuration.transformRequestBody)
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        let provider = try OpenResponsesProvider(name: "quiverai", url: config.url(modelID, "/responses").absoluteString,
            configuration: .init(headers: config.headers, transport: config.transport, strictResponseInput: true,
                                 transformRequestBody: config.transformRequestBody),
            customToolID: "quiverai.custom", structuredOutputs: false,
            getResponseErrorMetadata: quiverAIResponseErrorMetadata, failedResponseHandler: quiverAIFailedResponse,
            userAgentSuffix: "")
        return try provider.languageModel(modelID)
    }

    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .embedding, modelID: modelID)
    }

    public func imageModel(_ modelID: String) throws -> any ImageModel {
        QuiverAIImageModel(modelID: modelID, config: config.withProviderID("quiverai.image"))
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

    public func chatModel(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
}

public extension AIProviders {
    static func quiverAI(configuration: QuiverAIProviderSettings) throws -> QuiverAIProvider {
        try QuiverAIProvider(configuration: configuration)
    }
}

public struct QuiverAIModelConfiguration: AIProviderHTTPConfiguration {
    public var http: AIProviderHTTPClient
    public var baseURL: String
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public init(http: AIProviderHTTPClient, baseURL: String ,transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil) {
        self.http = http; self.baseURL = withoutTrailingSlash(baseURL)
        self.transformRequestBody = transformRequestBody
    }
}

public extension QuiverAIModelConfiguration {
    func httpStatusError(_ response: AIHTTPResponse) -> AIError {
        let failure = quiverAIFailedResponse(response)
        return .apiCall(AIAPICallError(provider: providerID, url: response.url?.absoluteString,
            statusCode: failure.statusCode ?? response.statusCode, responseHeaders: response.headers,
            responseBody: failure.responseBody, isRetryable: failure.isRetryable))
    }
}
