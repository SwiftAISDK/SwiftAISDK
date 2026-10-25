import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIBlackForestLabs

extension BlackForestLabsImageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: BlackForestLabsModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}

extension BlackForestLabsVideoModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: BlackForestLabsModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}
