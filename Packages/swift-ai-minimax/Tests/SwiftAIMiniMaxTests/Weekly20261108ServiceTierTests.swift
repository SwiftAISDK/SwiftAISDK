import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIMiniMax

@Suite struct Weekly20261108MiniMaxServiceTier {
    private let response = #"{"content":[{"type":"text","text":"ok"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}"#

    @Test func typedPriorityAndCustomNamespaceOverrideCanonicalTier() async throws {
        let transport = RecordingTransport(response: jsonResponse(response))
        let model = try MiniMaxProvider(settings: .init(apiKey: "key", transport: transport)).languageModel("minimax-m3.1-flash")
        let options = MiniMaxLanguageModelOptions(serviceTier: .priority)
        _ = try await model.generate(.init(messages: [.user("Hi")], providerOptions: options.providerOptions))
        _ = try await model.generate(.init(messages: [.user("Hi")], providerOptions: ["anthropic": ["serviceTier": "priority"], "minimax": ["serviceTier": "standard"]]))
        let bodies = try await transport.requests().map { try decodeJSONBody(#require($0.body)) }
        #expect(bodies[0]["service_tier"] == "priority")
        #expect(bodies[1]["service_tier"] == "standard")
    }

    @Test func anthropicOnlyTierWarnsAndInvalidValuesRejectBeforeHTTP() async throws {
        let transport = RecordingTransport(response: jsonResponse(response))
        let model = try MiniMaxProvider(settings: .init(apiKey: "key", transport: transport)).languageModel("minimax-m3.1-flash")
        for tier: JSONValue in [.null, "invalid"] {
            await #expect(throws: AIError.self) { try await model.generate(.init(messages: [.user("Hi")], providerOptions: ["minimax": ["serviceTier": tier]])) }
        }
        #expect(await transport.requests().isEmpty)
        let result = try await model.generate(.init(messages: [.user("Hi")], providerOptions: ["anthropic": ["serviceTier": "auto"]]))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["service_tier"] == nil)
        #expect(result.warnings.contains { $0.feature == "serviceTier" })
    }

    @Test func streamingPriorityUsesTheSameRequestPolicy() async throws {
        let transport = RecordingTransport(response: sseResponse("""
        data: {"type":"message_start","message":{"id":"one","usage":{"input_tokens":1}}}

        data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":1}}

        data: {"type":"message_stop"}
        """))
        let model = try MiniMaxProvider(settings: .init(apiKey: "key", transport: transport)).languageModel("minimax-m3.1-flash")
        for try await _ in model.stream(.init(messages: [.user("Hi")], providerOptions: MiniMaxLanguageModelOptions(serviceTier: .priority).providerOptions)) {}
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["service_tier"] == "priority")
    }
}
