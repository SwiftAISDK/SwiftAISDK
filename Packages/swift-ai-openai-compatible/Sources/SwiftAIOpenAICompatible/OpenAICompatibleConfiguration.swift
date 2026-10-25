import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

/// Selects wire conventions; it does not install or route to another provider.
public enum OpenAICompatibleWireProfile: Sendable {
    case generic
    case openAI(namespace: String)
}

public struct OpenAICompatibleLanguageCapabilities: Sendable {
    public var isReasoningModel = false
    public var supportsNonReasoningParameters = false
    public var supportedReasoningEfforts: [String]?
    public init() {}
}

/// HTTP and wire policy for Chat, Completion, Embeddings and Images adapters.
/// Provider model catalogs, credentials and routing remain outside this type.
public struct OpenAICompatibleModelConfiguration: Sendable {
    public var http: AIProviderHTTPClient
    public var baseURL: String
    public var wireProfile: OpenAICompatibleWireProfile = .generic
    public var includeUsage = false
    public var supportsMultiPartToolContent = false
    public var supportsStructuredOutputs = false
    public var maxEmbeddingsPerCall: Int?
    public var usesGenericOpenAICompatibleProviderOptions = true
    public var allowsEmptyTextResponse = true
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public var transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])?
    public var errorHandler: (@Sendable (AIHTTPResponse) -> AIError)?
    public var chatErrorHandler: (@Sendable (AIHTTPResponse) -> AIError)?
    public var streamErrorParser: (@Sendable (JSONValue) -> AIStreamProviderError?)?
    public var languageCapabilities: (@Sendable (String) -> OpenAICompatibleLanguageCapabilities)?
    public var normalizeSchema: (@Sendable (JSONValue) throws -> (schema: JSONValue, warnings: [AIWarning]))?
    public var prepareBody: (@Sendable ([String: JSONValue], LanguageModelRequest, String, inout [AIWarning]) throws -> [String: JSONValue])?
    public var convertMessages: (@Sendable ([AIMessage]) throws -> [JSONValue])?
    public var additionalWarnings: (@Sendable (LanguageModelRequest) -> [AIWarning])?
    public var supportsStructuredOutputForModel: (@Sendable (String) -> Bool)?
    public var mapsReasoningEffort = false
    public var toolCallsBeforeText = false
    public var usage: (@Sendable (JSONValue) -> TokenUsage?)?
    public var responseHeaderMetadata: (@Sendable ([String: String], String?) -> [String: JSONValue])?
    public var responseMetadata: (@Sendable (JSONValue, String?) -> [String: JSONValue])?
    public var imageSupportsFileInputs: (@Sendable (String) -> Bool?)?
    public var imageSupportsMaskInputs: (@Sendable (String) -> Bool?)?
    public var maximumImages: (@Sendable (String) -> Int)?
    public var imageHasDefaultResponseFormat: (@Sendable (String) -> Bool)?
    public var imageMetadata: (@Sendable (JSONValue) -> [String: JSONValue])?

    public init(http: AIProviderHTTPClient, baseURL: String) { self.http = http; self.baseURL = withoutTrailingSlash(baseURL) }
    public var providerID: String { http.providerID }
    public var headers: [String: String] { http.headers }
    public var transport: any AITransport { http.transport }
    public var requestModelID: String? { http.requestModelID }
    var openAIBackedProviderRoot: String? {
        if case let .openAI(namespace) = wireProfile { return namespace }; return nil
    }
    func withProviderID(_ providerID: String) -> Self { var copy = self; copy.http.providerID = providerID; return copy }
    func request(path: String, modelID: String, body: JSONValue, headers: [String: String] = [:], abortSignal: AIAbortSignal? = nil) throws -> AIHTTPRequest {
        try http.request(path: path, modelID: modelID, body: body, headers: headers, abortSignal: abortSignal)
    }
    func rawRequest(path: String, modelID: String, body: Data, contentType: String?, headers: [String: String] = [:], abortSignal: AIAbortSignal? = nil) throws -> AIHTTPRequest {
        try http.rawRequest(path: path, modelID: modelID, body: body, contentType: contentType, headers: headers, abortSignal: abortSignal)
    }
    func streamRequest(_ request: AIHTTPRequest) async throws -> AIHTTPStreamResponse { try await http.streamRequest(request) }
    func sendJSONResponse(path: String, modelID: String, body: JSONValue, headers: [String: String] = [:], abortSignal: AIAbortSignal? = nil) async throws -> (json: JSONValue, response: AIHTTPResponse) {
        let response = try await transport.send(request(path: path, modelID: modelID, body: body, headers: headers, abortSignal: abortSignal))
        guard (200..<300).contains(response.statusCode) else { throw httpStatusError(response) }
        return (try response.jsonValue(), response)
    }
    func httpStatusError(_ response: AIHTTPResponse) -> AIError { errorHandler?(response) ?? openAICompatibleHTTPStatusError(provider: providerID, response: response) }
    func chatHTTPStatusError(_ response: AIHTTPResponse) -> AIError { chatErrorHandler?(response) ?? openAICompatibleHTTPStatusError(provider: providerID, response: response) }
}

public func isOpenAIBackedProvider(_ providerID: String, config: OpenAICompatibleModelConfiguration) -> Bool { config.openAIBackedProviderRoot != nil }
public func openAIBackedProviderRoot(_ providerID: String, config: OpenAICompatibleModelConfiguration) -> String? { config.openAIBackedProviderRoot }
