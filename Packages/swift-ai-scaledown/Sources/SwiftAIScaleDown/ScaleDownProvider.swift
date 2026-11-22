import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

/// Published npm baseline mirrored by this provider.
public let scaleDownProviderVersion = "3.0.3"

public struct ScaleDownProviderSettings: Sendable {
    public var apiKey: String?
    public var apiKeyProvider: (@Sendable () async throws -> String)?
    public var baseURL: String?
    public var headers: [String: String]
    public var environment: [String: String]?
    public var transport: any AITransport

    public init(apiKey: String? = nil, apiKeyProvider: (@Sendable () async throws -> String)? = nil,
                baseURL: String? = nil, headers: [String: String] = [:], environment: [String: String]? = nil,
                transport: any AITransport = URLSessionTransport.shared) {
        self.apiKey = apiKey; self.apiKeyProvider = apiKeyProvider; self.baseURL = baseURL
        self.headers = headers; self.environment = environment; self.transport = transport
    }
}

public func createScaleDown(configuration: ScaleDownProviderSettings = .init()) -> ScaleDownProvider {
    ScaleDownProvider(configuration: configuration)
}
public let scaledown = createScaleDown()
public let scaleDown = scaledown
public typealias ScaleDownDecisionModelID = String
public typealias ScaleDownExtractionModelID = String

public final class ScaleDownProvider: AIProvider, AIDecisionProvider, AIExtractionProvider, Sendable {
    public let providerID = "scaledown"
    public let supportedCapabilities: Set<ModelCapability> = [.decision, .extraction]
    private let configuration: ScaleDownConfiguration

    public init(configuration settings: ScaleDownProviderSettings = .init()) {
        configuration = ScaleDownConfiguration(settings: settings)
    }
    public func decisionModel(_ modelID: String) throws -> any AIDecisionModelV4 {
        ScaleDownDecisionModel(modelID: modelID, configuration: configuration)
    }
    public func extractionModel(_ modelID: String) throws -> any AIExtractionModelV4 {
        ScaleDownExtractionModel(modelID: modelID, configuration: configuration)
    }
    public func decision(_ modelID: String) throws -> any AIDecisionModelV4 { try decisionModel(modelID) }
    public func extraction(_ modelID: String) throws -> any AIExtractionModelV4 { try extractionModel(modelID) }
    public func languageModel(_ id: String) throws -> any LanguageModel { throw unsupported(.language, id) }
    public func embeddingModel(_ id: String) throws -> any EmbeddingModel { throw unsupported(.embedding, id) }
    public func imageModel(_ id: String) throws -> any ImageModel { throw unsupported(.image, id) }
    public func transcriptionModel(_ id: String) throws -> any TranscriptionModel { throw unsupported(.transcription, id) }
    public func speechModel(_ id: String) throws -> any SpeechModel { throw unsupported(.speech, id) }
    public func videoModel(_ id: String) throws -> any VideoModel { throw unsupported(.video, id) }
    public func rerankingModel(_ id: String) throws -> any RerankingModel { throw unsupported(.reranking, id) }
    private func unsupported(_ capability: ModelCapability, _ id: String) -> AIError {
        .unsupportedModel(provider: providerID, capability: capability, modelID: id)
    }
}

public extension AIProviders {
    static func scaleDown(configuration: ScaleDownProviderSettings = .init()) -> ScaleDownProvider {
        createScaleDown(configuration: configuration)
    }
}

struct ScaleDownConfiguration: Sendable {
    var settings: ScaleDownProviderSettings
    var baseURL: String { withoutTrailingSlash(settings.baseURL ?? "https://api.scaledown.xyz") }

    func send(path: String, providerID: String, body: JSONValue, headers: [String: String],
              signal: AIAbortSignal?) async throws -> (AIHTTPRequest, AIHTTPResponse, JSONValue) {
        try signal?.throwIfAborted()
        try Task.checkCancellation()
        let apiKey: String
        if let supplier = settings.apiKeyProvider { apiKey = try await supplier() }
        else if let key = settings.apiKey { apiKey = key }
        else if let key = settings.environment.map({ $0["SCALEDOWN_API_KEY"] }) ?? environmentValue(["SCALEDOWN_API_KEY"]) {
            apiKey = key
        } else { throw AIError.missingAPIKey(provider: "scaledown", environmentVariables: ["SCALEDOWN_API_KEY"]) }
        try signal?.throwIfAborted()
        try Task.checkCancellation()
        let modelHeaders = withUserAgentSuffix(
            ["x-api-key": apiKey].merging(normalizeHeaders(settings.headers)) { _, new in new },
            "ai-sdk-scaledown/\(scaleDownProviderVersion)"
        )
        var requestHeaders = combineHeaders(modelHeaders, normalizeHeaders(headers))
        requestHeaders["content-type"] = requestHeaders["content-type"] ?? "application/json"
        let request = AIHTTPRequest(method: "POST", url: try requireURL(baseURL + path), headers: requestHeaders,
                                    body: try encodeJSONBody(body), abortSignal: signal)
        let response = try await settings.transport.send(request)
        try signal?.throwIfAborted()
        try Task.checkCancellation()
        guard (200..<300).contains(response.statusCode) else {
            var error = responseError(request, response, body, providerID)
            let raw = try? response.jsonValue()
            if let detail = raw?["detail"]?.stringValue { error.message = detail }
            else if let details = raw?["detail"]?.arrayValue,
                    details.allSatisfy({ $0["msg"]?.stringValue != nil }) {
                error.message = details.compactMap { $0["msg"]?.stringValue }.joined(separator: ", ")
            }
            throw AIError.apiCall(error)
        }
        do { return (request, response, try response.jsonValue()) }
        catch { throw AIError.apiCall(responseError(request, response, body, providerID, message: "ScaleDown response was not valid JSON.")) }
    }
}

func responseError(_ request: AIHTTPRequest, _ response: AIHTTPResponse, _ body: JSONValue,
                   _ provider: String, message: String? = nil) -> AIAPICallError {
    var error = AIAPICallError(provider: provider, url: request.url.absoluteString, requestBody: body,
                              statusCode: response.statusCode, responseHeaders: response.headers,
                              responseBody: String(decoding: response.body, as: UTF8.self),
                              isRetryable: (200..<300).contains(response.statusCode) ? false : nil)
    error.message = message
    return error
}
