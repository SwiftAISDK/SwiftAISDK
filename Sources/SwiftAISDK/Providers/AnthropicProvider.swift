import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIAnthropic

public extension AnthropicProvider {
    convenience init(settings: ProviderSettings = ProviderSettings()) throws {
        try self.init(configuration: AnthropicProviderSettings(
            apiKey: settings.apiKey, authToken: settings.authToken, baseURL: settings.baseURL,
            headers: settings.headers, queryParams: settings.queryParams, environment: settings.environment,
            transport: settings.transport, transformRequestBody: settings.transformRequestBody,
            batchResultDownloads: settings.batchResultDownloads, name: settings.name
        ))
    }
}
