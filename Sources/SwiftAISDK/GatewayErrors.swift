import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIGateway

// The compatibility aggregate retains provider-specific error selection.
// Core transport only constructs provider-neutral HTTP errors.
func compatibilityAPICallError(provider: String, response: AIHTTPResponse) -> AIError {
    compatibilityAPICallError(provider: provider, statusCode: response.statusCode, body: response.bodyText, headers: response.headers)
}

func compatibilityAPICallError(provider: String, statusCode: Int, body: String, headers: [String: String] = [:]) -> AIError {
    if provider == "gateway" {
        return .gateway(gatewayErrorFromHTTPStatus(statusCode: statusCode, body: body, headers: headers))
    }
    return SwiftAITransport.apiCallError(provider: provider, statusCode: statusCode, body: body, headers: headers)
}
