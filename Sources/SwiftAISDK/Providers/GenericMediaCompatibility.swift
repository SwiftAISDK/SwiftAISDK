import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

extension JSONImageModel {
    convenience init(modelID: String, path: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, path: path, config: JSONModelConfiguration(http: config.httpClient,
            errorHandler: { config.httpStatusError($0) },
            rawErrorHandler: { compatibilityAPICallError(provider: config.providerID, response: $0) }))
    }
}

extension JSONTranscriptionModel {
    convenience init(modelID: String, path: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, path: path, config: JSONModelConfiguration(http: config.httpClient,
            errorHandler: { config.httpStatusError($0) },
            rawErrorHandler: { compatibilityAPICallError(provider: config.providerID, response: $0) }))
    }
}

extension JSONSpeechModel {
    convenience init(modelID: String, path: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, path: path, config: JSONModelConfiguration(http: config.httpClient,
            errorHandler: { config.httpStatusError($0) },
            rawErrorHandler: { compatibilityAPICallError(provider: config.providerID, response: $0) }))
    }
}

extension JSONVideoModel {
    convenience init(modelID: String, path: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, path: path, config: JSONModelConfiguration(http: config.httpClient,
            errorHandler: { config.httpStatusError($0) },
            rawErrorHandler: { compatibilityAPICallError(provider: config.providerID, response: $0) }))
    }
}

extension JSONRerankingModel {
    convenience init(modelID: String, path: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, path: path, config: JSONModelConfiguration(http: config.httpClient,
            errorHandler: { config.httpStatusError($0) },
            rawErrorHandler: { compatibilityAPICallError(provider: config.providerID, response: $0) }))
    }
}
