import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible
import SwiftAIGMICloud
import SwiftAIDeepInfra
import SwiftAIFireworks
import SwiftAIMoonshotAI

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
        let openAIWire = openAIConfiguration.compatibleConfiguration()
        result.languageCapabilities = openAIWire.languageCapabilities
        if isOpenAIBackedProvider(providerID, config: self) {
            result.mapReasoning = openAIWire.mapReasoning
        }
        result.mapsReasoningEffort = openAICompatibleProviderRoot(providerID) == "openai"
        let root = openAICompatibleProviderRoot(providerID)
        result.toolCallsBeforeText = root == "moonshotai"
        if root == "deepinfra" { result.usage = deepInfraChatUsage }
        result.prepareBody = { body, request, modelID, warnings in
            var body = body
            if self.providerID == "googleVertex.xai" { body.removeValue(forKey: "reasoning_effort") }
            return body
        }
        if root == "fireworks" { configureFireworksChat(&result) }
        if root == "moonshotai" { configureMoonshotChat(&result) }
        if root == "xai" { configureXAIChat(&result) }
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
    return gmiCloudHTTPStatusError(response)
}
