import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIHeyGen

extension HeyGenVideoModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: HeyGenModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}
