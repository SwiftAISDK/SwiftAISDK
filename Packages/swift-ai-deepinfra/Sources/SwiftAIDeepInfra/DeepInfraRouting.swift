import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities


public func deepInfraRootBaseURL(_ baseURL: String) -> String {
    let normalized = withoutTrailingSlash(baseURL)
    if normalized.hasSuffix("/openai") {
        return String(normalized.dropLast("/openai".count))
    }
    if normalized.hasSuffix("/inference") {
        return String(normalized.dropLast("/inference".count))
    }
    return normalized
}


public func deepInfraOpenAIURL(root: String, path: String, queryParams: [String: String]) throws -> URL {
    let string = "\(root)/openai\(path)"
    guard !queryParams.isEmpty else { return try requireURL(string) }
    guard var components = URLComponents(string: string) else { throw AIError.invalidURL(string) }
    var items = components.queryItems ?? []
    for key in queryParams.keys.sorted() {
        items.append(URLQueryItem(name: key, value: queryParams[key]))
    }
    components.queryItems = items
    guard let url = components.url else { throw AIError.invalidURL(string) }
    return url
}