import Foundation
import SwiftAITransport

func openAICompatibleURL(_ string: String, queryParams: [String: String]) throws -> URL {
    try providerURL(string, queryParams: queryParams)
}
