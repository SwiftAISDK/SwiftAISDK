import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAILuma

extension LumaImageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: LumaModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}
