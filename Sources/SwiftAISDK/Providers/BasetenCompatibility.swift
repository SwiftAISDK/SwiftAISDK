import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIBaseten

extension BasetenEmbeddingModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: BasetenModelConfiguration(http: config.httpClient, baseURL: config.baseURL ,includeUsage: config.includeUsage, supportsStructuredOutputs: config.supportsStructuredOutputs, supportsMultiPartToolContent: config.supportsMultiPartToolContent, maxEmbeddingsPerCall: config.maxEmbeddingsPerCall, transformRequestBody: config.transformRequestBody, transformRequestBodyWithWarnings: config.transformRequestBodyWithWarnings, modelURL: config.modelURL))
    }
}



extension ModelHTTPConfig {
    var basetenEmbeddingConfig: ModelHTTPConfig? {
        guard let modelURL, modelURL.contains("/sync"), !modelURL.contains("/predict") else { return nil }
        let embeddingBaseURL = modelURL.contains("/sync/v1") ? modelURL : "\(modelURL)/v1"
        return ModelHTTPConfig(
            providerID: "baseten.embedding",
            baseURL: embeddingBaseURL,
            modelURL: modelURL,
            headers: headers,
            transport: transport,
            includeUsage: includeUsage,
            queryParams: queryParams,
            supportsStructuredOutputs: supportsStructuredOutputs,
            maxEmbeddingsPerCall: maxEmbeddingsPerCall,
            transformRequestBody: transformRequestBody,
            failedResponseHandling: .openAICompatible
        )
    }
}