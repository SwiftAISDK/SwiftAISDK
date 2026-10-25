import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIReplicate

extension ReplicateImageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: ReplicateModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}

extension ReplicateVideoModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: ReplicateModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}
