import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIFireworks

extension FireworksImageModel {
    convenience init(modelID: String, config: ModelHTTPConfig, pollIntervalMillis: Int = 500, pollTimeoutMillis: Int = 120_000) {
        self.init(modelID: modelID, config: FireworksModelConfiguration(http: config.httpClient, baseURL: config.baseURL ,includeUsage: config.includeUsage, supportsStructuredOutputs: config.supportsStructuredOutputs, supportsMultiPartToolContent: config.supportsMultiPartToolContent, maxEmbeddingsPerCall: config.maxEmbeddingsPerCall, transformRequestBody: config.transformRequestBody, transformRequestBodyWithWarnings: config.transformRequestBodyWithWarnings), pollIntervalMillis: pollIntervalMillis, pollTimeoutMillis: pollTimeoutMillis)
    }
}
