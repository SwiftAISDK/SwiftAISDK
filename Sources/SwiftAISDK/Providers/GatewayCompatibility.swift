import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIGateway

extension ProviderSettings {
    var gatewaySettings: GatewayProviderSettings {
        .init(apiKey: apiKey, baseURL: baseURL, headers: headers, queryParams: queryParams,
              transport: transport, batchResultDownloads: batchResultDownloads)
    }
}

public extension GatewayProvider {
    convenience init(settings: ProviderSettings = ProviderSettings(), teamIDOrSlug: String? = nil) throws {
        try self.init(configuration: settings.gatewaySettings, teamIDOrSlug: teamIDOrSlug)
    }
    convenience init(settings: ProviderSettings = ProviderSettings(), teamIDOrSlug: String? = nil,
                     webSocketTransport: any AIDuplexWebSocketTransport) throws {
        try self.init(configuration: settings.gatewaySettings, teamIDOrSlug: teamIDOrSlug, webSocketTransport: webSocketTransport)
    }
}
