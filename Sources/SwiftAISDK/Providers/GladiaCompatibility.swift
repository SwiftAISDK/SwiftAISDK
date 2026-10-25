import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIGladia

extension GladiaTranscriptionModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: GladiaModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}
