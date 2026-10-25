import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIDeepInfra

extension DeepInfraImageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: DeepInfraModelConfiguration(http: config.httpClient, baseURL: config.baseURL ,includeUsage: config.includeUsage, supportsStructuredOutputs: config.supportsStructuredOutputs, supportsMultiPartToolContent: config.supportsMultiPartToolContent, maxEmbeddingsPerCall: config.maxEmbeddingsPerCall, transformRequestBody: config.transformRequestBody, transformRequestBodyWithWarnings: config.transformRequestBodyWithWarnings))
    }
}
