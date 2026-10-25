import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAILMNT

extension LMNTSpeechModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, http: config.httpClient)
    }
}
