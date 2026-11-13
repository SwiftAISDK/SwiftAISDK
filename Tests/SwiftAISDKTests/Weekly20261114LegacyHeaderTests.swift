import Testing
@testable import SwiftAISDK

@Suite("Weekly20261114 legacy provider package header identities")
struct Weekly20261114LegacyHeaderTests {
    @Test(arguments: [
        ("assemblyai", "3.0.82"),
        ("revai", "3.0.81"),
        ("deepseek", "3.0.86"),
        ("elevenlabs", "3.0.86"),
        ("klingai", "4.0.84")
    ])
    func packageVersionMatchesItsOwningProvider(_ providerID: String, _ version: String) throws {
        let headers = try OpenAICompatibleProvider.buildHeaders(
            providerID: providerID, authorization: .none,
            settings: ProviderSettings(headers: ["User-Agent": "application/1"], environment: [:])
        )
        #expect(headers["user-agent"] == "application/1 ai-sdk-\(providerID)/\(version)")
    }

    @Test func explicitSuffixAndIntentionalNativeByteDanceIdentityArePreserved() throws {
        let settings = ProviderSettings(headers: ["user-agent": "application/1"], environment: [:])
        let custom = try OpenAICompatibleProvider.buildHeaders(
            providerID: "assemblyai", authorization: .none, settings: settings,
            userAgentSuffix: "custom-proxy/1"
        )
        #expect(custom["user-agent"] == "application/1 custom-proxy/1")
        let native = try OpenAICompatibleProvider.buildHeaders(providerID: "bytedance", authorization: .none, settings: settings)
        #expect(native["user-agent"] == "application/1 ai-sdk/bytedance/2.0.71")
    }
}
