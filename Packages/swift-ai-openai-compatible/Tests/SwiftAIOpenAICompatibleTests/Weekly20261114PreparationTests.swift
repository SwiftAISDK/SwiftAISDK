import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIOpenAICompatible

@Suite struct Weekly20261114PreparationTests {
    @Test func preparedUnaryBodyIncludesTransformsAndMatchesGenerationWithoutSending() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"role":"assistant","content":"Hello"},"finish_reason":"stop"}]}"#))
        var config = OpenAICompatibleModelConfiguration(http: AIProviderHTTPClient(providerID: "test-provider.chat", headers: [:], transport: transport, url: { _, path in URL(string: "https://api.test" + path)! }), baseURL: "https://api.test")
        config.includeUsage = true
        config.transformRequestBodyWithWarnings = { body, warnings in
            var body = body; body["custom_field"] = "added"; warnings.append(.init(type: "other", message: "transformed")); return body
        }
        let model = OpenAICompatibleChatModel(modelID: "test-model", config: config)
        let request = LanguageModelRequest(messages: [.user("Hello")], topK: 10, providerOptions: ["testProvider": ["user": "test-user", "custom_passthrough": "value"]])
        let prepared = try model.prepareRequest(request)
        #expect(await transport.requests().isEmpty)
        #expect(prepared.body["stream"] == nil)
        #expect(prepared.body["stream_options"] == nil)
        #expect(prepared.body["user"] == "test-user")
        #expect(prepared.body["custom_passthrough"] == "value")
        #expect(prepared.body["custom_field"] == "added")
        #expect(prepared.warnings.contains { $0.feature == "topK" })
        #expect(prepared.warnings.contains { $0.message == "transformed" })
        let result = try await model.generate(request)
        let sent = try decodeJSONBody(#require(await transport.requests().first?.body))
        #expect(sent == prepared.body)
        #expect(result.warnings == prepared.warnings)
    }

    @Test func detachedConversionPreservesReasoningToolsUsageAndNamespaceWithoutHTTPMetadata() async throws {
        let transport = RecordingTransport(response: jsonResponse("{}"))
        let config = OpenAICompatibleModelConfiguration(http: AIProviderHTTPClient(providerID: "test-provider.chat", headers: [:], transport: transport, url: { _, _ in URL(string: "https://api.test")! }), baseURL: "https://api.test")
        let model = OpenAICompatibleChatModel(modelID: "test", config: config)
        let raw: JSONValue = ["id": "chat", "created": 1711115037, "model": "test", "choices": [["message": ["role": "assistant", "content": "Answer", "reasoning_content": "Thinking", "refusal": false, "tool_calls": [["function": ["name": "weather", "arguments": "{}"], "extra_content": ["google": ["thought_signature": "sig"]]]]], "finish_reason": "stop"]], "usage": ["prompt_tokens": 4, "completion_tokens": 30, "completion_tokens_details": ["accepted_prediction_tokens": 5, "rejected_prediction_tokens": 2]]]
        let result = try model.convertResponse(body: raw, providerOptions: ["testProvider": [:]])
        #expect(result.text == "Answer")
        #expect(result.reasoning == "Thinking")
        #expect(result.toolCalls.count == 1)
        #expect(!result.toolCalls[0].id.isEmpty)
        #expect(result.toolCalls[0].providerMetadata["testProvider"]?["thoughtSignature"] == "sig")
        #expect(result.providerMetadata["testProvider"]?["acceptedPredictionTokens"] == 5)
        #expect(result.usage?.outputTokens == 30)
        #expect(result.responseMetadata.id == "chat")
        #expect(result.responseMetadata.body == nil)
        #expect(result.responseMetadata.headers.isEmpty)
        #expect(result.requestMetadata.body == nil)
        #expect(result.warnings.isEmpty)
        #expect(await transport.requests().isEmpty)
        for bad: JSONValue in [.null, ["choices": "nope"], ["choices": []], ["choices": [["message": 1]]]] {
            #expect(throws: AIError.self) { try model.convertResponse(body: bad) }
        }
    }

    @Test func detachedConversionUsesConfiguredUsageAndRawMetadataExtraction() throws {
        var config = OpenAICompatibleModelConfiguration(http: AIProviderHTTPClient(providerID: "custom.chat", headers: [:], transport: URLSessionTransport.shared, url: { _, _ in URL(string: "https://api.test")! }), baseURL: "https://api.test")
        config.usage = { _ in TokenUsage(inputTokens: 1, outputTokens: 2) }
        config.responseMetadata = { raw, _ in ["custom": ["extra": raw["unknown"] ?? .null]] }
        let model = OpenAICompatibleChatModel(modelID: "test", config: config)
        let result = try model.convertResponse(body: ["unknown": "retained", "choices": [["message": ["content": [["type": "thinking", "thinking": [["type": "text", "text": "Think"]]], ["type": "text", "text": "Answer"]]]]]])
        #expect(result.text == "Answer")
        #expect(result.reasoning == "Think")
        #expect(result.usage?.inputTokens == 1)
        #expect(result.providerMetadata["custom"]?["extra"] == "retained")
    }
}
