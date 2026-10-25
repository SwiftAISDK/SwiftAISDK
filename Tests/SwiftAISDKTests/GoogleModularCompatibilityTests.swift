@testable import SwiftAIGateway
@testable import SwiftAIFal
import Foundation
import Testing
import SwiftAISDK

@Test func googleCompatibilityPreservesLegacyNamedHeaderPolicy() async throws {
    let transport = RecordingTransport(response: jsonResponse("""
    {"candidates":[{"content":{"parts":[{"text":"ok"}]},"finishReason":"STOP"}]}
    """))
    let provider = try SwiftAISDK.AIProviders.google(settings: ProviderSettings(apiKey: "key", transport: transport, name: "anthropic"))
    _ = try await provider.languageModel("gemini").generate(LanguageModelRequest(messages: [.user("hello")]))
    let request = try #require(await transport.requests().first)
    #expect(request.headers["user-agent"] == "ai-sdk-anthropic/4.0.88")
}

@Test(arguments: [false, true]) func googleCompatibilityPreservesLegacyNamedErrorPolicy(stream: Bool) async throws {
    let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 503, headers: [:], body: Data("unavailable".utf8)))
    let provider = try SwiftAISDK.AIProviders.google(settings: ProviderSettings(apiKey: "key", transport: transport, name: "gateway"))
    let model = try provider.languageModel("gemini")
    do {
        if stream {
            for try await _ in model.stream(LanguageModelRequest(messages: [.user("hello")])) {}
        } else {
            _ = try await model.generate(LanguageModelRequest(messages: [.user("hello")]))
        }
        Issue.record("Expected the compatibility Gateway error policy")
    } catch let error as AIError {
        guard case .gateway = error else {
            Issue.record("Expected the legacy named error, received \(error)"); return
        }
    }
}
