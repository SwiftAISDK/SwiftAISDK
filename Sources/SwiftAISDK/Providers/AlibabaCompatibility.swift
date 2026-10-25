import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIAlibaba

extension AlibabaLanguageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: AlibabaModelConfiguration(http: config.httpClient, baseURL: config.baseURL ,transformRequestBody: config.transformRequestBody))
    }
}

extension AlibabaEmbeddingModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: AlibabaModelConfiguration(http: config.httpClient, baseURL: config.baseURL ,transformRequestBody: config.transformRequestBody))
    }
}

extension AlibabaVideoModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: AlibabaModelConfiguration(http: config.httpClient, baseURL: config.baseURL ,transformRequestBody: config.transformRequestBody))
    }
}
