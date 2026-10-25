import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIDeepSeek

extension ModelHTTPConfig {
    var deepSeekConfiguration: DeepSeekModelConfiguration {
        DeepSeekModelConfiguration(http: httpClient, baseURL: baseURL, supportsThinking: deepSeekSupportsThinking, supportsStructuredOutputs: supportsStructuredOutputs)
    }
}

extension DeepSeekLanguageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) { self.init(modelID: modelID, config: config.deepSeekConfiguration) }
}

extension DeepSeekFileClient {
    convenience init(config: ModelHTTPConfig) { self.init(config: config.deepSeekConfiguration) }
}
