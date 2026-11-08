import Foundation
import Testing
import SwiftAIGladia
import SwiftAIProvider
import SwiftAITransport

@Test func weeklyProviderSelectorCompatibilityGladiaInitializerReference() async throws {
    let old: (String?, (@Sendable () async throws -> String)?, String?, [String: String], [String: String], any AITransport) -> GladiaProviderSettings = GladiaProviderSettings.init(apiKey:apiKeyProvider:baseURL:headers:queryParams:transport:)
    let current: (String?, (@Sendable () async throws -> String)?, String?, [String: String], [String: String], any AITransport, Int?, Int?) -> GladiaProviderSettings = GladiaProviderSettings.init(apiKey:apiKeyProvider:baseURL:headers:queryParams:transport:pollIntervalMs:pollTimeoutMs:)
    let transport = RecordingTransport(response: jsonResponse("{}"))
    let value = old("static", { "fresh" }, "https://proxy.test", ["x-header": "value"], ["query": "value"], transport)
    #expect(value.apiKey == "static"); #expect(try await value.apiKeyProvider?() == "fresh")
    #expect(value.baseURL == "https://proxy.test"); #expect(value.headers == ["x-header": "value"]); #expect(value.queryParams == ["query": "value"])
    #expect(value.transport as AnyObject === transport)
    #expect(value.pollIntervalMs == nil); #expect(value.pollTimeoutMs == nil)
    let defaulted = GladiaProviderSettings()
    #expect(defaulted.apiKey == nil && defaulted.apiKeyProvider == nil && defaulted.baseURL == nil)
    #expect(defaulted.headers.isEmpty && defaulted.queryParams.isEmpty)
    #expect(defaulted.pollIntervalMs == nil && defaulted.pollTimeoutMs == nil)
    let extended = current(nil, nil, nil, [:], [:], transport, 5, 20)
    #expect(extended.pollIntervalMs == 5 && extended.pollTimeoutMs == 20)
}

@Test func weeklyProviderSelectorCompatibilityGladiaModelConfigurationReference() throws {
    let old: (AIProviderHTTPClient, String) -> GladiaModelConfiguration = GladiaModelConfiguration.init(http:baseURL:)
    let current: (AIProviderHTTPClient, String, Int?, Int?) -> GladiaModelConfiguration = GladiaModelConfiguration.init(http:baseURL:pollIntervalMs:pollTimeoutMs:)
    let transport = RecordingTransport(response: jsonResponse("{}"))
    let http = AIProviderHTTPClient(providerID: "gladia", headers: ["x-test": "value"], transport: transport, url: { _, _ in URL(string: "https://proxy.test")! })
    let actual = old(http, "https://proxy.test/")
    let expected = current(http, "https://proxy.test/", nil, nil)
    #expect(actual.baseURL == "https://proxy.test" && actual.baseURL == expected.baseURL)
    #expect(actual.headers == expected.headers && actual.http.providerID == "gladia")
    #expect(actual.pollIntervalMs == nil && actual.pollTimeoutMs == nil)
    let extended = current(http, "https://proxy.test", 10, 30)
    #expect(extended.pollIntervalMs == 10 && extended.pollTimeoutMs == 30)
}
