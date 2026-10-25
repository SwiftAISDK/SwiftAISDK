import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIKlingAI

extension KlingAIVideoModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: KlingAIModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}
