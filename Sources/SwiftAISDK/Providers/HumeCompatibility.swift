import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIHume

extension HumeSpeechModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, http: config.httpClient)
    }
}
