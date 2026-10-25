import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAITopaz

extension TopazImageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: TopazModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}

extension TopazVideoModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: TopazModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}
