import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIAssemblyAI

extension AssemblyAITranscriptionModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: AssemblyAIModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}
