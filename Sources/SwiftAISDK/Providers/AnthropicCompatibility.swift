import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIAnthropic

extension ModelHTTPConfig {
    var anthropicConfiguration: AnthropicModelConfiguration {
        var configuration = AnthropicModelConfiguration(
            baseURL: baseURL, http: AIProviderHTTPClient(providerID: providerID, headers: headers,
                transport: transport, dynamicHeaders: dynamicHeaders, userAgentSuffix: userAgentSuffix,
                requestModelID: requestModelID, url: url),
            transformRequestBody: transformRequestBody, batchResultMaxLineBytes: batchResultMaxLineBytes
        )
        if providerID == "minimax.messages" {
            configuration.requestPolicy = { modelID in
                var policy = AnthropicRequestPolicy()
                if miniMaxSupportsM31Features(modelID) {
                    policy.metadataNamespace = "minimax"
                    policy.maximumTemperature = 2
                    policy.supportsSamplingWithThinking = true
                    policy.prepareRequest = { try miniMaxReasoningRequest($0, modelID: $1, warnings: &$2) }
                    policy.userMediaContent = miniMaxMediaContent
                }
                return policy
            }
        }
        return configuration
    }
}

extension AnthropicLanguageModel {
    convenience init(modelID: String, config: ModelHTTPConfig,
        supportedURLs: [String: [AISupportedURLPattern]] = [
            "image/*": [AISupportedURLPattern(anthropicSupportedHTTPURL)],
            "application/pdf": [AISupportedURLPattern(anthropicSupportedHTTPURL)]
        ],
        transformRequestHeaders: (@Sendable ([String: String], [String: JSONValue]) async throws -> [String: String])? = nil
    ) {
        self.init(modelID: modelID, config: config.anthropicConfiguration,
                  supportedURLs: supportedURLs, transformRequestHeaders: transformRequestHeaders)
    }
}

extension AnthropicBatchLanguageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: config.anthropicConfiguration)
    }
}

extension AnthropicSkillsClient {
    convenience init(providerID: String, providerReferenceKey: String, config: ModelHTTPConfig) {
        self.init(providerID: providerID, providerReferenceKey: providerReferenceKey, config: config.anthropicConfiguration)
    }
}
