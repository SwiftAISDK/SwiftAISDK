import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIProdia

extension ProdiaLanguageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: ProdiaModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}

extension ProdiaImageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: ProdiaModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}

extension ProdiaVideoModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: ProdiaModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}
