import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIQuiverAI

extension QuiverAIImageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: QuiverAIModelConfiguration(http: config.httpClient, baseURL: config.baseURL ,transformRequestBody: config.transformRequestBody))
    }
}
