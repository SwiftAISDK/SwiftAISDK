import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIGoogle
public func googleVertexOpenAIBaseURL(project: String?, location: String?) throws -> String {
    guard let project = project ?? environmentValue(["GOOGLE_VERTEX_PROJECT"]) else {
        throw AIError.invalidURL("Google Vertex OpenAI-compatible mode requires project or GOOGLE_VERTEX_PROJECT.")
    }
    let location = location ?? environmentValue(["GOOGLE_VERTEX_LOCATION"]) ?? "global"
    try validateHostnamePart(location, argument: "location")
    let host = googleVertexRegionalHost(location: location)
    return "https://\(host)/v1/projects/\(project)/locations/\(location)/endpoints/openapi"
}

private let googleVertexMaaSMaxOutputTokensByModel: [String: Int] = [
    "meta/llama-4-maverick-17b-128e-instruct-maas": 8_192,
    "meta/llama-4-scout-17b-16e-instruct-maas": 8_192
]

public func googleVertexMaaSRequestBody(_ body: [String: JSONValue]) -> [String: JSONValue] {
    guard body["max_tokens"] == nil,
          let modelID = body["model"]?.stringValue,
          let maxOutputTokens = googleVertexMaaSMaxOutputTokensByModel[modelID] else {
        return body
    }
    var body = body
    body["max_tokens"] = .number(Double(maxOutputTokens))
    return body
}

public func googleVertexAnthropicBaseURL(project: String?, location: String?) throws -> String {
    guard let project = project ?? environmentValue(["GOOGLE_VERTEX_PROJECT"]) else {
        throw AIError.invalidURL("Google Vertex Anthropic mode requires project or GOOGLE_VERTEX_PROJECT.")
    }
    let location = location ?? environmentValue(["GOOGLE_VERTEX_LOCATION"]) ?? "global"
    try validateHostnamePart(location, argument: "location")
    let host = googleVertexRegionalHost(location: location)
    return "https://\(host)/v1/projects/\(project)/locations/\(location)/publishers/anthropic/models"
}

private func googleVertexRegionalHost(location: String) -> String {
    if location == "global" {
        return "aiplatform.googleapis.com"
    }
    if location == "eu" || location == "us" {
        return "aiplatform.\(location).rep.googleapis.com"
    }
    return "\(location)-aiplatform.googleapis.com"
}
