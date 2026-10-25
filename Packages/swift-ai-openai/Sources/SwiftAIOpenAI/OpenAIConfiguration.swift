import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible

public struct OpenAIProviderSettings: Sendable {
    public var apiKey: String?
    public var baseURL: String?
    public var organization: String?
    public var project: String?
    public var headers: [String: String]
    public var queryParams: [String: String]
    public var environment: [String: String]?
    public var transport: any AITransport
    public var includeUsage: Bool
    public var supportsStructuredOutputs: Bool
    public var maxEmbeddingsPerCall: Int?
    public var strictResponseInput: Bool
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public var transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])?
    public var batchResultDownloads: AIBatchResultDownloadSettings?
    public var name: String?

    public init(apiKey: String? = nil, baseURL: String? = nil, organization: String? = nil, project: String? = nil,
                headers: [String: String] = [:], queryParams: [String: String] = [:], environment: [String: String]? = nil,
                transport: any AITransport = URLSessionTransport.shared, includeUsage: Bool = false,
                supportsStructuredOutputs: Bool = false, maxEmbeddingsPerCall: Int? = nil, strictResponseInput: Bool = false,
                transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil,
                transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])? = nil,
                batchResultDownloads: AIBatchResultDownloadSettings? = nil, name: String? = nil) {
        self.apiKey = apiKey; self.baseURL = baseURL; self.organization = organization; self.project = project
        self.headers = headers; self.queryParams = queryParams; self.environment = environment; self.transport = transport
        self.includeUsage = includeUsage; self.supportsStructuredOutputs = supportsStructuredOutputs
        self.maxEmbeddingsPerCall = maxEmbeddingsPerCall; self.strictResponseInput = strictResponseInput
        self.transformRequestBody = transformRequestBody; self.transformRequestBodyWithWarnings = transformRequestBodyWithWarnings
        self.batchResultDownloads = batchResultDownloads; self.name = name
    }
    func environmentValue(_ names: [String]) -> String? {
        let values = environment ?? ProcessInfo.processInfo.environment
        return names.compactMap { values[$0] }.first
    }
}

/// Configuration of the Responses/Batch/Decisions and OpenAI media wire adapters.
/// Hosting integrations supply HTTP routing and optional response policies.
public struct OpenAIModelConfiguration: Sendable {
    public var http: AIProviderHTTPClient
    public var baseURL: String
    public var openAIBackedProviderRoot: String?
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public var batchResultMaxLineBytes: Int?
    public var strictResponseInput = false
    public var responsesRequestMode: ResponsesRequestMode = .openAICompatible
    public var getResponseErrorMetadata: (@Sendable (JSONValue) -> OpenResponsesErrorMetadata)?
    public var openResponsesCustomToolID: String?
    public var supportsWebSearchSourcesInclude = true
    public var explicitMessageItemType = false
    public var supportsStructuredOutputs = false
    public var errorHandler: (@Sendable (AIHTTPResponse) -> AIError)?
    public var prepareResponses: (@Sendable (String, LanguageModelRequest, Bool) throws -> OpenAICompatibleResponsesPreparedRequest)?
    public var streamErrorParser: (@Sendable (JSONValue) -> AIStreamProviderError?)?

    public init(http: AIProviderHTTPClient, baseURL: String, openAIBackedProviderRoot: String? = "openai") {
        self.http = http; self.baseURL = withoutTrailingSlash(baseURL); self.openAIBackedProviderRoot = openAIBackedProviderRoot
    }
    public var providerID: String { http.providerID }
    public var headers: [String: String] { http.headers }
    public var transport: any AITransport { http.transport }
    public var requestModelID: String? { http.requestModelID }
    public var url: @Sendable (String, String) throws -> URL { http.url }
    public func withProviderID(_ providerID: String) -> Self { var copy = self; copy.http.providerID = providerID; return copy }
    public func request(path: String, modelID: String, body: JSONValue, headers: [String: String] = [:], abortSignal: AIAbortSignal? = nil) throws -> AIHTTPRequest {
        try http.request(path: path, modelID: modelID, body: body, headers: headers, abortSignal: abortSignal)
    }
    public func rawRequest(path: String, modelID: String, body: Data, contentType: String?, headers: [String: String] = [:], abortSignal: AIAbortSignal? = nil) throws -> AIHTTPRequest {
        try http.rawRequest(path: path, modelID: modelID, body: body, contentType: contentType, headers: headers, abortSignal: abortSignal)
    }
    public func streamRequest(_ request: AIHTTPRequest) async throws -> AIHTTPStreamResponse { try await http.streamRequest(request) }
    public func sendJSONResponse(path: String, modelID: String, body: JSONValue, headers: [String: String] = [:], abortSignal: AIAbortSignal? = nil) async throws -> (json: JSONValue, response: AIHTTPResponse) {
        let response = try await transport.send(request(path: path, modelID: modelID, body: body, headers: headers, abortSignal: abortSignal))
        guard (200..<300).contains(response.statusCode) else { throw httpStatusError(response) }
        return (try response.jsonValue(), response)
    }
    public func httpStatusError(_ response: AIHTTPResponse) -> AIError { errorHandler?(response) ?? apiCallError(provider: providerID, response: response) }

    public func compatibleConfiguration() -> OpenAICompatibleModelConfiguration {
        var result = OpenAICompatibleModelConfiguration(http: http, baseURL: baseURL)
        if let root = openAIBackedProviderRoot { result.wireProfile = .openAI(namespace: root) }
        result.usesGenericOpenAICompatibleProviderOptions = false
        result.allowsEmptyTextResponse = false
        result.supportsStructuredOutputs = supportsStructuredOutputs
        result.transformRequestBody = transformRequestBody
        result.errorHandler = { self.httpStatusError($0) }
        result.streamErrorParser = openAIProviderStreamError
        result.normalizeSchema = normalizeOpenAIJSONSchema
        result.languageCapabilities = { modelID in
            let source = openAILanguageModelCapabilities(modelID)
            var value = OpenAICompatibleLanguageCapabilities()
            value.isReasoningModel = source.isReasoningModel
            value.supportsNonReasoningParameters = source.supportsNonReasoningParameters
            value.supportedReasoningEfforts = source.supportedReasoningEfforts
            return value
        }
        result.mapsReasoningEffort = openAICompatibleProviderRoot(providerID) == "openai"
        result.maximumImages = openAIImageMaxImagesPerCall
        result.imageHasDefaultResponseFormat = openAIImageHasDefaultResponseFormat
        if openAIBackedProviderRoot == "openai" {
            result.imageSupportsFileInputs = openAIImageSupportsFileInputs
            result.imageSupportsMaskInputs = openAIImageSupportsFileInputs
        }
        result.imageMetadata = { openAIImageProviderMetadata(from: $0, providerID: self.providerID, openAIBackedProviderRoot: self.openAIBackedProviderRoot) }
        return result
    }
}

public func isOpenAIBackedProvider(_ providerID: String, config: OpenAIModelConfiguration) -> Bool { openAIBackedProviderRoot(providerID, config: config) != nil }
public func openAIBackedProviderRoot(_ providerID: String, config: OpenAIModelConfiguration) -> String? { config.openAIBackedProviderRoot ?? openAIBackedProviderRoot(providerID) }

func isOpenAIBackedProvider(_ providerID: String) -> Bool { SwiftAIOpenAICompatible.isOpenAIBackedProvider(providerID) }
func openAIBackedProviderRoot(_ providerID: String) -> String? { SwiftAIOpenAICompatible.openAIBackedProviderRoot(providerID) }
