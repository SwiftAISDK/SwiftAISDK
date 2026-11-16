@testable import SwiftAICerebras
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translated from packages/cerebras/src/cerebras-chat-language-model.test.ts.
@Suite("Cerebras upstream parity")
struct CerebrasUpstreamParityTests {
    private func model(_ transport: RecordingTransport, _ modelID: String = "gpt-oss-120b") throws -> any LanguageModel {
        try AIProviders.cerebras(configuration: CerebrasProviderSettings(apiKey: "test-api-key", transport: transport))
            .languageModel(modelID)
    }

    private func fixtureStream(_ chunks: String) -> AIHTTPResponse {
        let lines = chunks.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return sseResponse(lines.map { "data: \($0)\n\n" }.joined() + "data: [DONE]\n\n")
    }

    // "preserves the captured first tool-call step"
    @Test func preservesCapturedFirstToolCallStep() async throws {
        let transport = RecordingTransport(response: jsonResponse(cerebrasStructuredOutputTools1JSON))
        let result = try await model(transport).generate(LanguageModelRequest(messages: [.user("Hello")], responseFormat: .json()))

        #expect(result.reasoning.hasPrefix("The user is asking about a \"magic number\"."))
        #expect(result.text == "")
        #expect(result.toolCalls.map(\.id) == ["85e4fd267"])
        #expect(result.toolCalls.map(\.name) == ["nonUsefulTool"])
        #expect(result.toolCalls.map(\.arguments) == ["{}"])
        #expect(result.finishReason == "tool-calls")
    }

    // "drops the captured repeated tool call when structured output text is present"
    @Test func dropsCapturedRepeatedToolCallWithStructuredText() async throws {
        let transport = RecordingTransport(response: jsonResponse(cerebrasStructuredOutputTools2JSON))
        let result = try await model(transport).generate(LanguageModelRequest(messages: [.user("Hello")], responseFormat: .json()))

        #expect(result.reasoning.hasPrefix("The function returned 2026 as the magic number."))
        #expect(result.text == #"{"result":"2026"}"#)
        #expect(result.toolCalls.isEmpty)
        #expect(result.finishReason == "stop")
    }

    // "preserves the captured mixed response without structured output"
    @Test func preservesCapturedMixedResponseWithoutStructuredOutput() async throws {
        let transport = RecordingTransport(response: jsonResponse(cerebrasStructuredOutputTools2JSON))
        let result = try await model(transport).generate(LanguageModelRequest(messages: [.user("Hello")]))

        #expect(result.text == #"{"result":"2026"}"#)
        #expect(result.toolCalls.map(\.id) == ["0babb4517"])
        #expect(result.finishReason == "tool-calls")
    }

    // doStream "normalizes captured streamed structured output with tool calls finish reason"
    // and "drops the spurious tool calls from a mixed structured-output stream"
    @Test func streamNormalizesFinishAndDropsSpuriousToolCalls() async throws {
        let transport = RecordingTransport(response: fixtureStream(cerebrasStructuredOutputTools1Chunks))
        var parts: [LanguageStreamPart] = []
        for try await part in try model(transport).stream(LanguageModelRequest(messages: [.user("Hello")], responseFormat: .json())) {
            parts.append(part)
        }

        let toolCalls = parts.compactMap { part -> AIToolCall? in
            if case let .toolCall(call) = part { return call }
            return nil
        }
        #expect(toolCalls.isEmpty)

        guard case let .finishMetadata(reason, usage, providerMetadata)? = parts.last else {
            Issue.record("Expected a finish part last")
            return
        }
        #expect(reason == "stop")
        #expect(providerMetadata == ["cerebras": ["acceptedPredictionTokens": 0, "rejectedPredictionTokens": 0]])
        #expect(usage?.inputTokens == 433)
        #expect(usage?.inputTokensNoCache == 177)
        #expect(usage?.inputTokensCacheRead == 256)
        #expect(usage?.outputTokens == 122)
        #expect(usage?.outputTextTokens == 14)
        #expect(usage?.outputReasoningTokens == 108)
    }

    // Upstream OpenAICompatibleChatLanguageModel returns empty content for a
    // choice without text; only an empty choices array is an error.
    @Test func reasoningOnlyResponseIsNotAnError() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"role":"assistant","content":null,"reasoning":"thinking"},"finish_reason":"length"}]}"#))
        let result = try await model(transport).generate(LanguageModelRequest(messages: [.user("Hello")]))
        #expect(result.text == "")
        #expect(result.reasoning == "thinking")
        #expect(result.finishReason == "length")
    }

    @Test func emptyChoicesAreRejected() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[]}"#))
        await #expect {
            _ = try await model(transport).generate(LanguageModelRequest(messages: [.user("Hello")]))
        } throws: { error in
            String(describing: error).contains("Response did not contain any choices.")
        }
    }

    // isCustomReasoning: "provider-default" leaves reasoning_effort unset.
    @Test func providerDefaultReasoningIsNotSent() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"ok"},"finish_reason":"stop"}]}"#))
        _ = try await model(transport).generate(LanguageModelRequest(messages: [.user("Hello")], reasoning: "provider-default"))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["reasoning_effort"] == nil)
    }

    // service tiers: "does not fabricate missing serviceTier metadata" (undefined / null)
    @Test(arguments: [#""#, #","service_tier":null"#])
    func doesNotFabricateMissingServiceTier(_ tier: String) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"id":"chatcmpl-test","model":"gpt-oss-120b","choices":[{"message":{"role":"assistant","content":"blue"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":2}\#(tier)}"#))
        let result = try await model(transport).generate(LanguageModelRequest(
            messages: [.user("Hello")],
            providerOptions: ["cerebras": ["serviceTier": "auto"]]
        ))
        #expect(result.providerMetadata["cerebras"]?["serviceTier"] == nil)
    }
}
