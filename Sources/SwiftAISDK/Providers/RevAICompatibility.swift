import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIRevAI

extension RevAITranscriptionModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: RevAIModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}
