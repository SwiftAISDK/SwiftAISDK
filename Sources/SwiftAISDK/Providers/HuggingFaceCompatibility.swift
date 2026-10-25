import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIHuggingFace

extension HuggingFaceResponsesLanguageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, http: config.httpClient)
    }
}

public extension HuggingFaceProvider {
    convenience init(settings: ProviderSettings = ProviderSettings()) throws {
        try self.init(configuration: HuggingFaceProviderSettings(apiKey: settings.apiKey,
            baseURL: settings.baseURL, headers: settings.headers, queryParams: settings.queryParams,
            transport: settings.transport))
    }
}
