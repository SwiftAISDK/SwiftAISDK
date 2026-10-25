import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAITogetherAI

extension TogetherAIImageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: TogetherAIModelConfiguration(http: config.httpClient, baseURL: config.baseURL ,supportsStructuredOutputs: config.supportsStructuredOutputs, supportsMultiPartToolContent: config.supportsMultiPartToolContent, maxEmbeddingsPerCall: config.maxEmbeddingsPerCall, transformRequestBody: config.transformRequestBody, transformRequestBodyWithWarnings: config.transformRequestBodyWithWarnings))
    }
}

extension TogetherAIRerankingModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: TogetherAIModelConfiguration(http: config.httpClient, baseURL: config.baseURL ,supportsStructuredOutputs: config.supportsStructuredOutputs, supportsMultiPartToolContent: config.supportsMultiPartToolContent, maxEmbeddingsPerCall: config.maxEmbeddingsPerCall, transformRequestBody: config.transformRequestBody, transformRequestBodyWithWarnings: config.transformRequestBodyWithWarnings))
    }
}
