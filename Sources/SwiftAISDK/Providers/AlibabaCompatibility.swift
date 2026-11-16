import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIAlibaba

extension ModelHTTPConfig {
    var alibabaConfiguration: AlibabaModelConfiguration {
        AlibabaModelConfiguration(
            http: httpClient, baseURL: baseURL, transformRequestBody: transformRequestBody,
            videoBaseURL: alibabaVideoBaseURL, embeddingBaseURL: alibabaEmbeddingBaseURL, includeUsage: alibabaIncludeUsage
        )
    }
}

extension AlibabaLanguageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: config.alibabaConfiguration)
    }
}

extension AlibabaEmbeddingModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: config.alibabaConfiguration)
    }
}

extension AlibabaVideoModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: config.alibabaConfiguration)
    }
}
