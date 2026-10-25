import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIGroq

extension GroqLanguageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, http: config.httpClient)
    }
}

extension GroqTranscriptionModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, http: config.httpClient)
    }
}
