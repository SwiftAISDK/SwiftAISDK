import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIGMICloud

public func createGMICloud(settings: ProviderSettings = ProviderSettings()) throws -> GMICloudProvider { try GMICloudProvider(settings: settings) }

public extension GMICloudProvider {
    convenience init(settings: ProviderSettings = ProviderSettings()) throws {
        try self.init(configuration: GMICloudProviderSettings(apiKey: settings.apiKey,
            baseURL: settings.baseURL, headers: settings.headers, queryParams: settings.queryParams,
            environment: settings.environment, transport: settings.transport, supportsStructuredOutputs: settings.supportsStructuredOutputs,
            transformRequestBody: settings.transformRequestBody))
    }
}
