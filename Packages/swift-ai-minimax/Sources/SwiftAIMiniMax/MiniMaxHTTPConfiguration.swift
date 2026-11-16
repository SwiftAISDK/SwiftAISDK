import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIAnthropic

struct MiniMaxHTTPConfiguration: AIProviderHTTPConfiguration {
    var http: AIProviderHTTPClient
    var baseURL: String
    init(providerID: String, baseURL: String, headers: [String: String], transport: any AITransport, credentialResolver: AIAsyncCredential? = nil) {
        let baseURL = withoutTrailingSlash(baseURL)
        self.baseURL = baseURL
        http = AIProviderHTTPClient(providerID: providerID, headers: headers, transport: transport, credentialResolver: credentialResolver,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: [:]) })
    }
    /// Mirrors upstream `minimaxImageFailedResponseHandler`: `error.message`
    /// becomes the error message while the raw response body is retained.
    /// Messages requests use the Anthropic configuration's own error policy.
    func httpStatusError(_ response: AIHTTPResponse) -> AIError {
        let error = apiCallError(provider: providerID, response: response)
        guard case var .apiCall(callError) = error,
              let message = (try? decodeJSONBody(response.body))?["error"]?["message"]?.stringValue else {
            return error
        }
        callError.message = message
        return .apiCall(callError)
    }

    var anthropicConfiguration: AnthropicModelConfiguration {
        var config = AnthropicModelConfiguration(baseURL: baseURL, http: http)
        config.requestPolicy = miniMaxRequestPolicy
        return config
    }
}
