import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIZAI

/// The legacy aggregate settings alias, retained for source compatibility.
public typealias ZAIProviderSettings = ProviderSettings

public func createZai(settings: ZAIProviderSettings = ZAIProviderSettings()) -> ZAIProvider { ZAIProvider(settings: settings) }
public func createZAI(settings: ZAIProviderSettings = ZAIProviderSettings()) -> ZAIProvider { createZai(settings: settings) }

public extension ZAIProvider {
    convenience init(settings: ZAIProviderSettings = ZAIProviderSettings()) {
        self.init(configuration: SwiftAIZAI.ZAIProviderSettings(apiKey: settings.apiKey,
            baseURL: settings.baseURL, headers: settings.headers, queryParams: settings.queryParams,
            environment: settings.environment, transport: settings.transport,
            transformRequestBody: settings.transformRequestBody))
    }
}
