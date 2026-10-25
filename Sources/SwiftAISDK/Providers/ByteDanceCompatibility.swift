import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIByteDance

extension ByteDanceVideoModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: ByteDanceModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}
