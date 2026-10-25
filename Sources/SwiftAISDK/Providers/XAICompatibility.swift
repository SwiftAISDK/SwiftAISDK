import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIXAI

extension ModelHTTPConfig {
    var xaiConfiguration: XAIModelConfiguration { .init(http: httpClient, baseURL: baseURL, responsesConfiguration: openAIConfiguration) }
}

extension XAIImageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) { self.init(modelID: modelID, config: config.xaiConfiguration) }
}

extension XAIVideoModel {
    convenience init(modelID: String, config: ModelHTTPConfig) { self.init(modelID: modelID, config: config.xaiConfiguration) }
}

extension XAIRealtimeModel {
    convenience init(modelID: String, config: ModelHTTPConfig) { self.init(modelID: modelID, config: config.xaiConfiguration) }
}

extension XAIResponsesBatchLanguageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) { self.init(modelID: modelID, config: config.xaiConfiguration) }
}

extension XAISpeechModel {
    convenience init(config: ModelHTTPConfig) { self.init(config: config.xaiConfiguration) }
}

extension XAIFileClient {
    convenience init(config: ModelHTTPConfig) { self.init(config: config.xaiConfiguration) }
}

extension XAIBatchProvider {
    convenience init(config: ModelHTTPConfig) { self.init(config: config.xaiConfiguration) }
}

extension XAITranscriptionModel {
    convenience init(modelID: String = "", config: ModelHTTPConfig, webSocketTransport: any AIDuplexWebSocketTransport = URLSessionDuplexWebSocketTransport.shared) { self.init(modelID: modelID, config: config.xaiConfiguration, webSocketTransport: webSocketTransport) }
}
