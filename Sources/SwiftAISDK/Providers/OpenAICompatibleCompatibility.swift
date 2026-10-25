import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible

extension ModelHTTPConfig {
    var compatibleConfiguration: OpenAICompatibleModelConfiguration {
        var result = OpenAICompatibleModelConfiguration(http: AIProviderHTTPClient(
            providerID: providerID, headers: headers, transport: transport, dynamicHeaders: dynamicHeaders,
            userAgentSuffix: userAgentSuffix, requestModelID: requestModelID, url: url
        ), baseURL: baseURL)
        if let root = openAIBackedProviderRoot ?? SwiftAIOpenAICompatible.openAIBackedProviderRoot(providerID) {
            result.wireProfile = .openAI(namespace: root)
        }
        result.includeUsage = includeUsage
        result.supportsMultiPartToolContent = supportsMultiPartToolContent
        result.supportsStructuredOutputs = supportsStructuredOutputs
        result.maxEmbeddingsPerCall = maxEmbeddingsPerCall
        result.usesGenericOpenAICompatibleProviderOptions = usesGenericOpenAICompatibleProviderOptions
        result.allowsEmptyTextResponse = allowsEmptyTextResponse
        result.transformRequestBody = transformRequestBody
        result.transformRequestBodyWithWarnings = transformRequestBodyWithWarnings
        result.errorHandler = { self.httpStatusError($0) }
        result.chatErrorHandler = { openAICompatibleHTTPStatusError(provider: self.providerID, response: $0) }
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
        let root = openAICompatibleProviderRoot(providerID)
        result.toolCallsBeforeText = root == "moonshotai"
        if root == "moonshotai" {
            result.responseHeaderMetadata = { moonshotCacheWriteMetadata(headers: $0, namespace: $1) }
            result.convertMessages = moonshotChatMessages
            result.supportsStructuredOutputForModel = moonshotSupportsStructuredOutputs
            result.usage = moonshotChatUsage
        } else if root == "xai" {
            result.usage = xaiChatUsage
            result.responseMetadata = { raw, namespace in
                guard let tier = raw["service_tier"], tier != .null else { return [:] }
                return openAICompatibleNamespacedProviderMetadata(["serviceTier": tier], providerID: self.providerID, namespace: namespace)
            }
        } else if root == "deepinfra" {
            result.usage = deepInfraChatUsage
        }
        result.additionalWarnings = { request in self.providerID.hasPrefix("xai.") ? xaiChatWarnings(for: request) : [] }
        result.prepareBody = { body, request, modelID, warnings in
            var body = body
            if root == "fireworks" { body = fireworksChatBody(from: body, warnings: &warnings) }
            if root == "moonshotai" { body = try moonshotChatBody(from: body, request: request, modelID: modelID, warnings: &warnings) }
            if self.providerID == "googleVertex.xai" { body.removeValue(forKey: "reasoning_effort") }
            if self.providerID.hasPrefix("xai.") { body = try xaiChatBody(from: body, request: request, warnings: &warnings) }
            return body
        }
        if isOpenAIBackedProvider(providerID, config: self) {
            result.maximumImages = openAIImageMaxImagesPerCall
            result.imageHasDefaultResponseFormat = openAIImageHasDefaultResponseFormat
        }
        if (openAIBackedProviderRoot ?? SwiftAIOpenAICompatible.openAIBackedProviderRoot(providerID)) == "openai" {
            result.imageSupportsFileInputs = openAIImageSupportsFileInputs
            result.imageSupportsMaskInputs = openAIImageSupportsFileInputs
        }
        result.imageMetadata = { openAIImageProviderMetadata(from: $0, providerID: self.providerID, openAIBackedProviderRoot: self.openAIBackedProviderRoot) }
        return result
    }
}

extension OpenAICompatibleChatModel {
    convenience init(modelID: String, config: ModelHTTPConfig) { self.init(modelID: modelID, config: config.compatibleConfiguration) }
}
extension OpenAICompatibleCompletionModel {
    convenience init(modelID: String, config: ModelHTTPConfig) { self.init(modelID: modelID, config: config.compatibleConfiguration) }
}
extension OpenAICompatibleEmbeddingModel {
    convenience init(modelID: String, config: ModelHTTPConfig) { self.init(modelID: modelID, config: config.compatibleConfiguration) }
}
extension OpenAICompatibleImageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) { self.init(modelID: modelID, config: config.compatibleConfiguration) }
}

func openAICompatibleHTTPStatusError(provider: String, response: AIHTTPResponse) -> AIError {
    guard provider == "gmicloud.chat" else {
        return SwiftAIOpenAICompatible.openAICompatibleHTTPStatusError(provider: provider, response: response)
    }
    let body = gmiCloudErrorMessage(from: response.body) ?? response.bodyText
    if response.headers.isEmpty { return .apiCall(provider: provider, statusCode: response.statusCode, body: body) }
    return .apiCall(provider: provider, statusCode: response.statusCode, body: body, headers: response.headers)
}
