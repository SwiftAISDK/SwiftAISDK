import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

struct FishAudioHTTPConfiguration: AIProviderHTTPConfiguration {
    var http: AIProviderHTTPClient
    init(providerID: String, baseURL: String, headers: [String: String],
         transport: any AITransport, queryParams: [String: String] = [:]) {
        let baseURL = withoutTrailingSlash(baseURL)
        http = AIProviderHTTPClient(providerID: providerID, headers: headers, transport: transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: queryParams) })
    }
}
