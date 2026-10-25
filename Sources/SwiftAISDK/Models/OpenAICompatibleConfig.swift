import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAI

public enum AzureOpenAITools {
    public static func codeInterpreter(container: JSONValue? = nil) -> JSONValue {
        OpenAITools.codeInterpreter(container: container)
    }

    public static func fileSearch(vectorStoreIDs: [String], maxNumResults: Int? = nil, ranking: JSONValue? = nil, filters: JSONValue? = nil) -> JSONValue {
        OpenAITools.fileSearch(vectorStoreIDs: vectorStoreIDs, maxNumResults: maxNumResults, ranking: ranking, filters: filters)
    }

    /// Source-compatible image-generation tool factory retained from 1.5.x.
    public static func imageGeneration(
        background: String? = nil,
        inputFidelity: String? = nil,
        inputImageMask: JSONValue? = nil,
        model: String? = nil,
        moderation: String? = nil,
        outputCompression: Int? = nil,
        outputFormat: String? = nil,
        partialImages: Int? = nil,
        quality: String? = nil,
        size: String? = nil
    ) -> JSONValue {
        imageGeneration(
            action: nil,
            background: background,
            inputFidelity: inputFidelity,
            inputImageMask: inputImageMask,
            model: model,
            moderation: moderation,
            outputCompression: outputCompression,
            outputFormat: outputFormat,
            partialImages: partialImages,
            quality: quality,
            size: size
        )
    }

    public static func imageGeneration(
        action: String? = nil,
        background: String? = nil,
        inputFidelity: String? = nil,
        inputImageMask: JSONValue? = nil,
        model: String? = nil,
        moderation: String? = nil,
        outputCompression: Int? = nil,
        outputFormat: String? = nil,
        partialImages: Int? = nil,
        quality: String? = nil,
        size: String? = nil
    ) -> JSONValue {
        OpenAITools.imageGeneration(
            action: action,
            background: background,
            inputFidelity: inputFidelity,
            inputImageMask: inputImageMask,
            model: model,
            moderation: moderation,
            outputCompression: outputCompression,
            outputFormat: outputFormat,
            partialImages: partialImages,
            quality: quality,
            size: size
        )
    }

    public static func webSearch(filters: JSONValue? = nil, externalWebAccess: Bool? = nil, searchContextSize: String? = nil, userLocation: JSONValue? = nil) -> JSONValue {
        OpenAITools.webSearch(filters: filters, externalWebAccess: externalWebAccess, searchContextSize: searchContextSize, userLocation: userLocation)
    }

    @available(*, deprecated, message: "Use webSearch instead.")
    public static func webSearchPreview(searchContextSize: String? = nil, userLocation: JSONValue? = nil) -> JSONValue {
        OpenAITools.webSearchPreview(searchContextSize: searchContextSize, userLocation: userLocation)
    }
}

enum ModelHTTPFailedResponseHandling: Sendable {
    case raw
    case openAICompatible
}

struct ModelHTTPConfig: @unchecked Sendable {
    var providerID: String
    var baseURL: String
    var modelURL: String?
    var requestModelID: String?
    var headers: [String: String]
    var dynamicHeaders: (@Sendable () -> [String: String])?
    var userAgentSuffix: String?
    var transport: any AITransport
    var includeUsage: Bool
    var queryParams: [String: String]
    var supportsMultiPartToolContent: Bool
    var supportsStructuredOutputs: Bool
    var maxEmbeddingsPerCall: Int?
    var strictResponseInput: Bool
    var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    var transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])?
    var batchResultMaxLineBytes: Int?
    var responsesRequestMode: ResponsesRequestMode
    var getResponseErrorMetadata: (@Sendable (JSONValue) -> OpenResponsesErrorMetadata)?
    var openResponsesCustomToolID: String?
    var supportsWebSearchSourcesInclude: Bool
    var explicitMessageItemType: Bool
    var openAIBackedProviderRoot: String?
    var usesGenericOpenAICompatibleProviderOptions: Bool
    var deepSeekSupportsThinking: Bool
    var allowsEmptyTextResponse: Bool
    var failedResponseHandling: ModelHTTPFailedResponseHandling
    var failedResponseHandler: (@Sendable (AIHTTPResponse) -> OpenResponsesFailedResponse)?
    var url: @Sendable (String, String) throws -> URL

    init(
        providerID: String,
        baseURL: String,
        modelURL: String? = nil,
        requestModelID: String? = nil,
        headers: [String: String],
        transport: any AITransport,
        dynamicHeaders: (@Sendable () -> [String: String])? = nil,
        userAgentSuffix: String? = nil,
        includeUsage: Bool = false,
        queryParams: [String: String] = [:],
        supportsMultiPartToolContent: Bool = false,
        supportsStructuredOutputs: Bool = false,
        maxEmbeddingsPerCall: Int? = nil,
        strictResponseInput: Bool = false,
        transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil,
        transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])? = nil,
        batchResultMaxLineBytes: Int? = nil,
        responsesRequestMode: ResponsesRequestMode = .openAICompatible,
        getResponseErrorMetadata: (@Sendable (JSONValue) -> OpenResponsesErrorMetadata)? = nil,
        openResponsesCustomToolID: String? = nil,
        supportsWebSearchSourcesInclude: Bool = true,
        explicitMessageItemType: Bool = false,
        openAIBackedProviderRoot: String? = nil,
        usesGenericOpenAICompatibleProviderOptions: Bool = false,
        deepSeekSupportsThinking: Bool = true,
        allowsEmptyTextResponse: Bool = false,
        failedResponseHandling: ModelHTTPFailedResponseHandling = .raw,
        failedResponseHandler: (@Sendable (AIHTTPResponse) -> OpenResponsesFailedResponse)? = nil,
        url: (@Sendable (String, String) throws -> URL)? = nil
    ) {
        self.providerID = providerID
        let normalizedBaseURL = withoutTrailingSlash(baseURL)
        self.baseURL = normalizedBaseURL
        self.modelURL = modelURL.map(withoutTrailingSlash)
        self.requestModelID = requestModelID
        self.headers = headers
        self.dynamicHeaders = dynamicHeaders
        self.userAgentSuffix = userAgentSuffix
        self.transport = transport
        self.includeUsage = includeUsage
        self.queryParams = queryParams
        self.supportsMultiPartToolContent = supportsMultiPartToolContent
        self.supportsStructuredOutputs = supportsStructuredOutputs
        self.maxEmbeddingsPerCall = maxEmbeddingsPerCall
        self.strictResponseInput = strictResponseInput
        self.transformRequestBody = transformRequestBody
        self.transformRequestBodyWithWarnings = transformRequestBodyWithWarnings
        self.batchResultMaxLineBytes = batchResultMaxLineBytes
        self.responsesRequestMode = responsesRequestMode
        self.getResponseErrorMetadata = getResponseErrorMetadata
        self.openResponsesCustomToolID = openResponsesCustomToolID
        self.supportsWebSearchSourcesInclude = supportsWebSearchSourcesInclude
        self.explicitMessageItemType = explicitMessageItemType
        self.openAIBackedProviderRoot = openAIBackedProviderRoot
        self.usesGenericOpenAICompatibleProviderOptions = usesGenericOpenAICompatibleProviderOptions
        self.deepSeekSupportsThinking = deepSeekSupportsThinking
        self.allowsEmptyTextResponse = allowsEmptyTextResponse
        self.failedResponseHandling = failedResponseHandling
        self.failedResponseHandler = failedResponseHandler
        self.url = url ?? { _, path in
            try openAICompatibleURL("\(normalizedBaseURL)\(path)", queryParams: queryParams)
        }
    }

    private var httpClient: AIProviderHTTPClient {
        AIProviderHTTPClient(providerID: providerID, headers: headers, transport: transport,
                             dynamicHeaders: dynamicHeaders, userAgentSuffix: userAgentSuffix,
                             requestModelID: requestModelID, url: url)
    }

    func request(path: String, modelID: String, body: JSONValue, headers: [String: String] = [:], abortSignal: AIAbortSignal? = nil) throws -> AIHTTPRequest {
        try httpClient.request(path: path, modelID: modelID, body: body, headers: headers, abortSignal: abortSignal)
    }

    func rawRequest(path: String, modelID: String, body: Data, contentType: String?, headers: [String: String] = [:], abortSignal: AIAbortSignal? = nil) throws -> AIHTTPRequest {
        try httpClient.rawRequest(path: path, modelID: modelID, body: body, contentType: contentType, headers: headers, abortSignal: abortSignal)
    }

    func streamRequest(_ request: AIHTTPRequest) async throws -> AIHTTPStreamResponse {
        try await httpClient.streamRequest(request)
    }

    func sendJSON(path: String, modelID: String, body: JSONValue, headers: [String: String] = [:], abortSignal: AIAbortSignal? = nil) async throws -> JSONValue {
        try await sendJSONResponse(path: path, modelID: modelID, body: body, headers: headers, abortSignal: abortSignal).json
    }

    func sendJSONResponse(path: String, modelID: String, body: JSONValue, headers: [String: String] = [:], abortSignal: AIAbortSignal? = nil) async throws -> (json: JSONValue, response: AIHTTPResponse) {
        let response = try await transport.send(request(path: path, modelID: modelID, body: body, headers: headers, abortSignal: abortSignal))
        guard (200..<300).contains(response.statusCode) else {
            throw httpStatusError(response)
        }
        return (try response.jsonValue(), response)
    }

    func httpStatusError(_ response: AIHTTPResponse) -> AIError {
        if let failedResponseHandler {
            let failure = failedResponseHandler(response)
            return .apiCall(AIAPICallError(
                provider: providerID,
                url: response.url?.absoluteString,
                statusCode: failure.statusCode ?? response.statusCode,
                responseHeaders: response.headers,
                responseBody: failure.responseBody,
                isRetryable: failure.isRetryable
            ))
        }
        switch failedResponseHandling {
        case .raw:
            return compatibilityAPICallError(provider: providerID, response: response)
        case .openAICompatible:
            return openAICompatibleHTTPStatusError(provider: providerID, response: response)
        }
    }

    func withProviderID(_ providerID: String) -> ModelHTTPConfig {
        ModelHTTPConfig(
            providerID: providerID,
            baseURL: baseURL,
            modelURL: modelURL,
            requestModelID: requestModelID,
            headers: headers,
            transport: transport,
            dynamicHeaders: dynamicHeaders,
            userAgentSuffix: userAgentSuffix,
            includeUsage: includeUsage,
            queryParams: queryParams,
            supportsMultiPartToolContent: supportsMultiPartToolContent,
            supportsStructuredOutputs: supportsStructuredOutputs,
            maxEmbeddingsPerCall: maxEmbeddingsPerCall,
            strictResponseInput: strictResponseInput,
            transformRequestBody: transformRequestBody,
            transformRequestBodyWithWarnings: transformRequestBodyWithWarnings,
            batchResultMaxLineBytes: batchResultMaxLineBytes,
            responsesRequestMode: responsesRequestMode,
            getResponseErrorMetadata: getResponseErrorMetadata,
            openResponsesCustomToolID: openResponsesCustomToolID,
            supportsWebSearchSourcesInclude: supportsWebSearchSourcesInclude,
            explicitMessageItemType: explicitMessageItemType,
            openAIBackedProviderRoot: openAIBackedProviderRoot,
            usesGenericOpenAICompatibleProviderOptions: usesGenericOpenAICompatibleProviderOptions,
            deepSeekSupportsThinking: deepSeekSupportsThinking,
            allowsEmptyTextResponse: allowsEmptyTextResponse,
            failedResponseHandling: failedResponseHandling,
            failedResponseHandler: failedResponseHandler,
            url: url
        )
    }

    func withRequestModelID(_ requestModelID: String) -> ModelHTTPConfig {
        var copy = self
        copy.requestModelID = requestModelID
        return copy
    }

    func withDeepSeekSupportsThinking(_ supportsThinking: Bool) -> ModelHTTPConfig {
        ModelHTTPConfig(
            providerID: providerID,
            baseURL: baseURL,
            modelURL: modelURL,
            requestModelID: requestModelID,
            headers: headers,
            transport: transport,
            dynamicHeaders: dynamicHeaders,
            userAgentSuffix: userAgentSuffix,
            includeUsage: includeUsage,
            queryParams: queryParams,
            supportsMultiPartToolContent: supportsMultiPartToolContent,
            supportsStructuredOutputs: supportsStructuredOutputs,
            maxEmbeddingsPerCall: maxEmbeddingsPerCall,
            strictResponseInput: strictResponseInput,
            transformRequestBody: transformRequestBody,
            transformRequestBodyWithWarnings: transformRequestBodyWithWarnings,
            batchResultMaxLineBytes: batchResultMaxLineBytes,
            responsesRequestMode: responsesRequestMode,
            getResponseErrorMetadata: getResponseErrorMetadata,
            openResponsesCustomToolID: openResponsesCustomToolID,
            supportsWebSearchSourcesInclude: supportsWebSearchSourcesInclude,
            explicitMessageItemType: explicitMessageItemType,
            openAIBackedProviderRoot: openAIBackedProviderRoot,
            usesGenericOpenAICompatibleProviderOptions: usesGenericOpenAICompatibleProviderOptions,
            deepSeekSupportsThinking: supportsThinking,
            allowsEmptyTextResponse: allowsEmptyTextResponse,
            failedResponseHandling: failedResponseHandling,
            failedResponseHandler: failedResponseHandler,
            url: url
        )
    }

    func withSupportsStructuredOutputs(_ supportsStructuredOutputs: Bool) -> ModelHTTPConfig {
        ModelHTTPConfig(
            providerID: providerID,
            baseURL: baseURL,
            modelURL: modelURL,
            requestModelID: requestModelID,
            headers: headers,
            transport: transport,
            dynamicHeaders: dynamicHeaders,
            userAgentSuffix: userAgentSuffix,
            includeUsage: includeUsage,
            queryParams: queryParams,
            supportsMultiPartToolContent: supportsMultiPartToolContent,
            supportsStructuredOutputs: supportsStructuredOutputs,
            maxEmbeddingsPerCall: maxEmbeddingsPerCall,
            strictResponseInput: strictResponseInput,
            transformRequestBody: transformRequestBody,
            transformRequestBodyWithWarnings: transformRequestBodyWithWarnings,
            batchResultMaxLineBytes: batchResultMaxLineBytes,
            responsesRequestMode: responsesRequestMode,
            getResponseErrorMetadata: getResponseErrorMetadata,
            openResponsesCustomToolID: openResponsesCustomToolID,
            supportsWebSearchSourcesInclude: supportsWebSearchSourcesInclude,
            explicitMessageItemType: explicitMessageItemType,
            openAIBackedProviderRoot: openAIBackedProviderRoot,
            usesGenericOpenAICompatibleProviderOptions: usesGenericOpenAICompatibleProviderOptions,
            deepSeekSupportsThinking: deepSeekSupportsThinking,
            allowsEmptyTextResponse: allowsEmptyTextResponse,
            failedResponseHandling: failedResponseHandling,
            failedResponseHandler: failedResponseHandler,
            url: url
        )
    }

    func withBaseURL(_ baseURL: String) -> ModelHTTPConfig {
        ModelHTTPConfig(
            providerID: providerID,
            baseURL: baseURL,
            modelURL: modelURL,
            requestModelID: requestModelID,
            headers: headers,
            transport: transport,
            dynamicHeaders: dynamicHeaders,
            userAgentSuffix: userAgentSuffix,
            includeUsage: includeUsage,
            queryParams: queryParams,
            supportsMultiPartToolContent: supportsMultiPartToolContent,
            supportsStructuredOutputs: supportsStructuredOutputs,
            maxEmbeddingsPerCall: maxEmbeddingsPerCall,
            strictResponseInput: strictResponseInput,
            transformRequestBody: transformRequestBody,
            transformRequestBodyWithWarnings: transformRequestBodyWithWarnings,
            batchResultMaxLineBytes: batchResultMaxLineBytes,
            responsesRequestMode: responsesRequestMode,
            getResponseErrorMetadata: getResponseErrorMetadata,
            openResponsesCustomToolID: openResponsesCustomToolID,
            supportsWebSearchSourcesInclude: supportsWebSearchSourcesInclude,
            explicitMessageItemType: explicitMessageItemType,
            openAIBackedProviderRoot: openAIBackedProviderRoot,
            usesGenericOpenAICompatibleProviderOptions: usesGenericOpenAICompatibleProviderOptions,
            deepSeekSupportsThinking: deepSeekSupportsThinking,
            allowsEmptyTextResponse: allowsEmptyTextResponse,
            failedResponseHandling: failedResponseHandling,
            failedResponseHandler: failedResponseHandler
        )
    }

    func withSupportsWebSearchSourcesInclude(_ supportsInclude: Bool) -> ModelHTTPConfig {
        var copy = self
        copy.supportsWebSearchSourcesInclude = supportsInclude
        return copy
    }
}

public enum AuthorizationStyle: Equatable, Hashable, Sendable {
    case bearer(environmentVariables: [String])
    case token(environmentVariables: [String])
    case apiKeyHeader(name: String, prefix: String? = nil, environmentVariables: [String])
    case none
}

public struct ProviderSettings: Sendable {
    /// Opt in only when the compatible server accepts rich tool-result content.
    public var supportsMultiPartToolContent: Bool = false
    public var apiKey: String?
    public var authToken: String?
    public var baseURL: String?
    public var modelURL: String?
    public var organization: String?
    public var project: String?
    public var headers: [String: String]
    public var queryParams: [String: String]
    public var environment: [String: String]?
    public var transport: any AITransport
    public var includeUsage: Bool
    public var supportsStructuredOutputs: Bool
    public var maxEmbeddingsPerCall: Int?
    /// Sends ID-less Open Responses assistant history as strict easy-input
    /// messages instead of incomplete output items.
    public var strictResponseInput: Bool
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    /// An additive warning-aware transform. It runs after the existing transform
    /// and its warnings are exposed by generated and streamed chat responses.
    public var transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])? = nil
    public var batchResultDownloads: AIBatchResultDownloadSettings? = nil
    public var name: String?

    public init(
        apiKey: String? = nil,
        authToken: String? = nil,
        baseURL: String? = nil,
        modelURL: String? = nil,
        organization: String? = nil,
        project: String? = nil,
        headers: [String: String] = [:],
        queryParams: [String: String] = [:],
        environment: [String: String]? = nil,
        transport: any AITransport = URLSessionTransport.shared,
        includeUsage: Bool = false,
        supportsStructuredOutputs: Bool = false,
        maxEmbeddingsPerCall: Int? = nil,
        strictResponseInput: Bool = false,
        transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil,
        name: String? = nil
    ) {
        self.apiKey = apiKey
        self.authToken = authToken
        self.baseURL = baseURL
        self.modelURL = modelURL
        self.organization = organization
        self.project = project
        self.headers = headers
        self.queryParams = queryParams
        self.environment = environment
        self.transport = transport
        self.includeUsage = includeUsage
        self.supportsStructuredOutputs = supportsStructuredOutputs
        self.maxEmbeddingsPerCall = maxEmbeddingsPerCall
        self.strictResponseInput = strictResponseInput
        self.transformRequestBody = transformRequestBody
        self.name = name
    }

    /// Source-compatible initializer retained from before strict Open
    /// Responses assistant-history conversion became configurable.
    public init(
        apiKey: String? = nil,
        authToken: String? = nil,
        baseURL: String? = nil,
        modelURL: String? = nil,
        organization: String? = nil,
        project: String? = nil,
        headers: [String: String] = [:],
        queryParams: [String: String] = [:],
        environment: [String: String]? = nil,
        transport: any AITransport = URLSessionTransport.shared,
        includeUsage: Bool = false,
        supportsStructuredOutputs: Bool = false,
        maxEmbeddingsPerCall: Int? = nil,
        transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil,
        name: String? = nil
    ) {
        self.init(
            apiKey: apiKey,
            authToken: authToken,
            baseURL: baseURL,
            modelURL: modelURL,
            organization: organization,
            project: project,
            headers: headers,
            queryParams: queryParams,
            environment: environment,
            transport: transport,
            includeUsage: includeUsage,
            supportsStructuredOutputs: supportsStructuredOutputs,
            maxEmbeddingsPerCall: maxEmbeddingsPerCall,
            strictResponseInput: false,
            transformRequestBody: transformRequestBody,
            name: name
        )
    }

    func environmentValue(_ names: [String]) -> String? {
        if let environment {
            return names.lazy.compactMap { environment[$0] }.first
        }
        return SwiftAITransport.environmentValue(names)
    }
}