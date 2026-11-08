import Foundation
import Testing
import SwiftAIDeepgram
import SwiftAIProvider
import SwiftAITransport

@Test func weeklyProviderSelectorCompatibilityDeepgramInitializerReference() async throws {
    let old: (String?, (@Sendable () async throws -> String)?, String?, [String: String], [String: String], any AITransport) -> DeepgramProviderSettings = DeepgramProviderSettings.init(apiKey:apiKeyProvider:baseURL:headers:queryParams:transport:)
    let current: (String?, (@Sendable () async throws -> String)?, String?, [String: String], [String: String], any AITransport, any AIDuplexWebSocketTransport) -> DeepgramProviderSettings = DeepgramProviderSettings.init(apiKey:apiKeyProvider:baseURL:headers:queryParams:transport:webSocketTransport:)
    let transport = RecordingTransport(response: jsonResponse("{}"))
    let value = old("static", { "fresh" }, "https://proxy.test", ["x-header": "value"], ["query": "value"], transport)
    #expect(value.apiKey == "static"); #expect(try await value.apiKeyProvider?() == "fresh")
    #expect(value.baseURL == "https://proxy.test"); #expect(value.headers == ["x-header": "value"]); #expect(value.queryParams == ["query": "value"])
    #expect(value.transport as AnyObject === transport)
    #expect(value.webSocketTransport as AnyObject === URLSessionDuplexWebSocketTransport.shared)
    let defaulted = DeepgramProviderSettings()
    #expect(defaulted.apiKey == nil && defaulted.apiKeyProvider == nil && defaulted.baseURL == nil)
    #expect(defaulted.headers.isEmpty && defaulted.queryParams.isEmpty)
    #expect(defaulted.webSocketTransport as AnyObject === URLSessionDuplexWebSocketTransport.shared)
    let extended = current(nil, nil, nil, [:], [:], transport, URLSessionDuplexWebSocketTransport.shared)
    #expect(extended.webSocketTransport as AnyObject === URLSessionDuplexWebSocketTransport.shared)
}
