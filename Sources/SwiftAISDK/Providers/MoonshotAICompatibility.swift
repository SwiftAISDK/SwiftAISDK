import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIMoonshotAI

extension MoonshotAIChatLanguageModel {
    /// Routes umbrella Moonshot chat through the native package model, so
    /// `AIProviders.moonshotAI(settings:)` matches `MoonshotAIProvider`.
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(
            modelID: modelID,
            config: MoonshotAIModelConfiguration(
                http: config.httpClient,
                baseURL: config.baseURL,
                supportsStructuredOutputs: config.supportsStructuredOutputs,
                supportsMultiPartToolContent: config.supportsMultiPartToolContent,
                maxEmbeddingsPerCall: config.maxEmbeddingsPerCall,
                transformRequestBody: config.transformRequestBody,
                transformRequestBodyWithWarnings: config.transformRequestBodyWithWarnings
            ),
            includeUsage: config.includeUsage
        )
    }
}
