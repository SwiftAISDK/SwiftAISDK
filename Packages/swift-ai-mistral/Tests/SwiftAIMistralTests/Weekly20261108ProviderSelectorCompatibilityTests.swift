import Foundation
import Testing
import SwiftAIMistral
import SwiftAIProvider
import SwiftAITransport

@Test func weeklyProviderSelectorCompatibilityMistralInitializerReference() async throws {
    let old: (String?, String?, [String: String], [String: String], any AITransport, (@Sendable () async throws -> String)?) -> MistralProviderSettings = MistralProviderSettings.init(apiKey:baseURL:headers:queryParams:transport:apiKeyProvider:)
    let current: (String?, String?, [String: String], [String: String], any AITransport, (@Sendable () async throws -> String)?, any AIDuplexWebSocketTransport) -> MistralProviderSettings = MistralProviderSettings.init(apiKey:baseURL:headers:queryParams:transport:apiKeyProvider:webSocketTransport:)
    let transport = RecordingTransport(response: jsonResponse("{}"))
    let actual = old("static", "https://proxy.test", ["x-header": "value"], ["query": "value"], transport, { "fresh" })
    #expect(actual.apiKey == "static"); #expect(try await actual.apiKeyProvider?() == "fresh")
    #expect(actual.baseURL == "https://proxy.test" && actual.headers == ["x-header": "value"] && actual.queryParams == ["query": "value"])
    #expect(actual.transport as AnyObject === transport)
    #expect(actual.webSocketTransport as AnyObject === URLSessionDuplexWebSocketTransport.shared)
    let defaults = MistralProviderSettings()
    #expect(defaults.apiKey == nil && defaults.apiKeyProvider == nil && defaults.baseURL == nil && defaults.headers.isEmpty && defaults.queryParams.isEmpty)
    let extended = current(nil, nil, [:], [:], transport, nil, URLSessionDuplexWebSocketTransport.shared)
    #expect(extended.webSocketTransport as AnyObject === URLSessionDuplexWebSocketTransport.shared)
    let trailingClosure = MistralProviderSettings { "trailing" }
    #expect(try await trailingClosure.apiKeyProvider?() == "trailing")
}
