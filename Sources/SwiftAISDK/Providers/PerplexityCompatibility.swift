import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIPerplexity

extension PerplexityLanguageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: PerplexityModelConfiguration(http: config.httpClient, transformRequestBody: config.transformRequestBody))
    }
}

extension PerplexitySonarLanguageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: PerplexityModelConfiguration(http: config.httpClient, transformRequestBody: config.transformRequestBody))
    }
}

extension PerplexityEmbeddingModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: PerplexityModelConfiguration(http: config.httpClient, transformRequestBody: config.transformRequestBody))
    }
}

extension PerplexityDecisionModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: PerplexityModelConfiguration(http: config.httpClient, transformRequestBody: config.transformRequestBody))
    }
}
