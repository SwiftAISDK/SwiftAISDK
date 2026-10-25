import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAITypeSafeAI

public func createTypeSafeAI(settings: ProviderSettings = ProviderSettings()) -> TypeSafeAIProvider {
    TypeSafeAIProvider(settings: settings)
}

public func createTypeSafeAi(settings: ProviderSettings = ProviderSettings()) -> TypeSafeAIProvider {
    createTypeSafeAI(settings: settings)
}

public extension TypeSafeAIProvider {
    convenience init(settings: ProviderSettings = ProviderSettings()) {
        self.init(configuration: TypeSafeAIProviderSettings(apiKey: settings.apiKey,
            baseURL: settings.baseURL, headers: settings.headers,
            environment: settings.environment, transport: settings.transport))
    }
}
