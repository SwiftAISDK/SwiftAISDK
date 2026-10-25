import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIAnthropic

struct MiniMaxHTTPConfiguration: AIProviderHTTPConfiguration {
    var http: AIProviderHTTPClient
    var baseURL: String
    init(providerID: String, baseURL: String, headers: [String: String], transport: any AITransport) {
        let baseURL = withoutTrailingSlash(baseURL)
        self.baseURL = baseURL
        http = AIProviderHTTPClient(providerID: providerID, headers: headers, transport: transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: [:]) })
    }
    var anthropicConfiguration: AnthropicModelConfiguration {
        var config = AnthropicModelConfiguration(baseURL: baseURL, http: http)
        config.requestPolicy = miniMaxRequestPolicy
        return config
    }
}
