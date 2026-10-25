import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIVercel

public extension VercelProvider {
    convenience init(settings: ProviderSettings = ProviderSettings()) throws {
        try self.init(configuration: VercelProviderSettings(apiKey: settings.apiKey,
            baseURL: settings.baseURL, headers: settings.headers, queryParams: settings.queryParams,
            transport: settings.transport, includeUsage: settings.includeUsage, supportsStructuredOutputs: settings.supportsStructuredOutputs,
            transformRequestBody: settings.transformRequestBody))
    }
}
