import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIFal

extension FalImageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: FalModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}

extension FalTranscriptionModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: FalModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}

extension FalSpeechModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: FalModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}

extension FalVideoModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: FalModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}
