import Foundation
import Testing
@testable import SwiftAIMistral
import SwiftAIProvider
import SwiftAITransport

@Suite struct Weekly20261101MistralTests {
    @Test func customAuthorizationKeepsPrecedenceOverCredentialSupplier() async throws {
        let keys = WeeklyMistralKeys()
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"done"},"finish_reason":"stop"}]}"#))
        let provider = try MistralProvider(configuration: .init(headers: ["AUTHORIZATION": "Bearer custom"], transport: transport, apiKeyProvider: { await keys.next() }))
        _ = try await provider.languageModel("mistral-large-4").generate(.init(messages: [.user("hello")]))
        #expect(await keys.count == 0)
        #expect(await transport.requests().first?.headers["authorization"] == "Bearer custom")
    }

    @Test func glm53ReasoningUsesSupportedEffortsAndWarnsForFallback() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"done"},"finish_reason":"stop"}]}"#))
        let provider = try MistralProvider(configuration: .init(apiKey: "test", transport: transport))
        for modelID in ["zai-glm-5-3", "zai-glm-5", "zai-glm-latest", "zai-glm-5-3-flash"] {
            let model = try provider.chatModel(modelID)
            for (reasoning, expected) in [("none", "low"), ("minimal", "low"), ("low", "low"), ("medium", "low"), ("high", "high"), ("xhigh", "high"), ("max", "max")] {
                let result = try await model.generate(.init(messages: [.user("Hello")], reasoning: reasoning))
                let request = try #require(await transport.requests().last)
                let body = try decodeJSONBody(try #require(request.body))
                #expect(body["reasoning_effort"] == .string(expected))
                if expected != reasoning {
                    #expect(result.warnings.contains(AIWarning(type: "compatibility", feature: "reasoning", message: "reasoning \"\(reasoning)\" is not directly supported by this model. mapped to effort \"\(expected)\".")))
                } else { #expect(result.warnings.isEmpty) }
            }
        }
    }

    @Test func providerEffortOverridesTopLevelWithoutRemapping() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"done"},"finish_reason":"stop"}]}"#))
        let provider = try MistralProvider(configuration: .init(apiKey: "test", transport: transport))
        let model = try provider.languageModel("zai-glm-5-3")
        for effort in ["low", "max", "none"] {
            let result = try await model.generate(.init(messages: [.user("Hello")], reasoning: "high", providerOptions: ["mistral": ["reasoningEffort": .string(effort)]]))
            let request = try #require(await transport.requests().last)
            let body = try decodeJSONBody(try #require(request.body))
            #expect(body["reasoning_effort"] == .string(effort))
            #expect(result.warnings.isEmpty)
        }
    }

    @Test func conversationReasoningRetainsItsOwnKnownModelBoundary() throws {
        for modelID in ["zai-glm-5-3", "custom-future", "codestral-latest"] {
            let prepared = try mistralConversationPreparedCall(.init(messages: [.user("Hello")], reasoning: "high"), modelID: modelID, stream: false)
            #expect(prepared.body["completion_args"]?["reasoning_effort"] == nil)
            #expect(prepared.warnings.contains { $0.type == "unsupported" && $0.feature == "reasoning" })
        }
        for modelID in ["glm-5-2", "zai-glm-5-2", "mistral-large-4"] {
            let prepared = try mistralConversationPreparedCall(.init(messages: [.user("Hello")], reasoning: "none"), modelID: modelID, stream: true)
            #expect(prepared.body["completion_args"]?["reasoning_effort"] == "none")
        }
    }

    @Test func rotatingKeySupportsGenerationAndStreamingWithoutEagerResolution() async throws {
        let keys = WeeklyMistralKeys()
        let transport = RecordingTransport(responses: [
            jsonResponse(#"{"choices":[{"message":{"content":"done"},"finish_reason":"stop"}]}"#),
            sseResponse(#"data: {"choices":[{"delta":{"content":"done"},"finish_reason":"stop"}]}"#)
        ])
        let provider = try MistralProvider(configuration: .init(transport: transport, apiKeyProvider: { await keys.next() }))
        #expect(await keys.count == 0)
        let model = try provider.languageModel("mistral-large-4")
        _ = try await model.generate(.init(messages: [.user("Hello")]))
        for try await _ in model.stream(.init(messages: [.user("Hello")])) {}
        let requests = await transport.requests()
        #expect(requests.map { normalizeHeaders($0.headers)["authorization"] } == ["Bearer key-1", "Bearer key-2"])
    }
}

private actor WeeklyMistralKeys {
    private(set) var count = 0
    func next() -> String { count += 1; return "key-\(count)" }
}
