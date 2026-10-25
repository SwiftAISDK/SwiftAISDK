import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible
import SwiftAIOpenAI

extension ModelHTTPConfig {
    var openAIConfiguration: OpenAIModelConfiguration {
        var result = OpenAIModelConfiguration(http: AIProviderHTTPClient(
            providerID: providerID, headers: headers, transport: transport, dynamicHeaders: dynamicHeaders,
            userAgentSuffix: userAgentSuffix, requestModelID: requestModelID, url: url
        ), baseURL: baseURL, openAIBackedProviderRoot: openAIBackedProviderRoot)
        result.transformRequestBody = transformRequestBody
        result.batchResultMaxLineBytes = batchResultMaxLineBytes
        result.strictResponseInput = strictResponseInput
        result.responsesRequestMode = responsesRequestMode
        result.getResponseErrorMetadata = getResponseErrorMetadata
        result.openResponsesCustomToolID = openResponsesCustomToolID
        result.supportsWebSearchSourcesInclude = supportsWebSearchSourcesInclude
        result.explicitMessageItemType = explicitMessageItemType
        result.supportsStructuredOutputs = supportsStructuredOutputs
        result.errorHandler = { self.httpStatusError($0) }
        if providerID.hasPrefix("xai.") { configureXAIResponses(&result) }
        return result
    }
}

extension ProviderSettings {
    var openAISettings: OpenAIProviderSettings {
        .init(apiKey: apiKey, baseURL: baseURL, organization: organization, project: project,
              headers: headers, queryParams: queryParams, environment: environment, transport: transport,
              includeUsage: includeUsage, supportsStructuredOutputs: supportsStructuredOutputs,
              maxEmbeddingsPerCall: maxEmbeddingsPerCall, strictResponseInput: strictResponseInput,
              transformRequestBody: transformRequestBody, transformRequestBodyWithWarnings: transformRequestBodyWithWarnings,
              batchResultDownloads: batchResultDownloads, name: name)
    }
}

public extension OpenAILiveModel {
    convenience init(modelID: String = "gpt-live-1", settings: ProviderSettings = .init()) throws {
        try self.init(modelID: modelID, configuration: settings.openAISettings)
    }
}

extension OpenAILiveModel {
    convenience init(modelID: String, config: ModelHTTPConfig) { self.init(modelID: modelID, config: config.openAIConfiguration) }
}
extension OpenAICompatibleResponsesModel {
    convenience init(modelID: String, config: ModelHTTPConfig) { self.init(modelID: modelID, config: config.openAIConfiguration) }
}
extension OpenAIResponsesBatchLanguageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) { self.init(modelID: modelID, config: config.openAIConfiguration) }
}
extension OpenAIDecisionModel {
    convenience init(modelID: String, config: ModelHTTPConfig) { self.init(modelID: modelID, config: config.openAIConfiguration) }
}
extension OpenAICompatibleSpeechModel {
    convenience init(modelID: String, config: ModelHTTPConfig) { self.init(modelID: modelID, config: config.openAIConfiguration) }
}
extension OpenAICompatibleTranscriptionModel {
    convenience init(modelID: String, config: ModelHTTPConfig) { self.init(modelID: modelID, config: config.openAIConfiguration) }
}
extension OpenAIBatchProvider {
    convenience init(config: ModelHTTPConfig) { self.init(config: config.openAIConfiguration) }
}
extension OpenAISkillsClient {
    convenience init(providerID: String, providerReferenceKey: String, config: ModelHTTPConfig) {
        self.init(providerID: providerID, providerReferenceKey: providerReferenceKey, config: config.openAIConfiguration)
    }
}
extension MultipartFileClient {
    convenience init(providerID: String, providerReferenceKey: String, config: ModelHTTPConfig,
                     betaHeader: (String, String)? = nil, includePurpose: Bool = false, defaultFilename: String = "file", providerOptionsName: String? = nil) {
        self.init(providerID: providerID, providerReferenceKey: providerReferenceKey, config: config.openAIConfiguration,
                  betaHeader: betaHeader, includePurpose: includePurpose, defaultFilename: defaultFilename, providerOptionsName: providerOptionsName)
    }
}
