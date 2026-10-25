import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIFishAudio

public func createFishAudio(settings: ProviderSettings = ProviderSettings()) throws -> FishAudioProvider {
    try FishAudioProvider(settings: settings)
}

public extension FishAudioProvider {
    convenience init(settings: ProviderSettings = ProviderSettings()) throws {
        try self.init(configuration: FishAudioProviderSettings(apiKey: settings.apiKey,
            baseURL: settings.baseURL, headers: settings.headers, queryParams: settings.queryParams,
            environment: settings.environment, transport: settings.transport))
    }
}
