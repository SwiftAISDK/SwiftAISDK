import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIOpenAICompatible

@Suite struct Weekly20261108CompatibleTests {
    @Test func refusalAndMalformedToolReplayFollowPublishedGenericPolicy() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":null,"refusal":"Cannot answer."},"finish_reason":"stop"}]}"#))
        let provider = OpenAICompatibleProvider(configuration: .init(name: "custom", baseURL: "https://api.test/v1", transport: transport))
        let model = try provider.chatModel("model")
        let result = try await model.generate(.init(messages: [AIMessage(role: .assistant, content: [.toolCall(.init(id: "call", name: "lookup", arguments: "unparseable"))])]))
        #expect(result.text == "Cannot answer."); #expect(result.finishReason == "content-filter")
        #expect(result.requestMetadata.url == "https://api.test/v1/chat/completions")
        let body = try decodeJSONBody(#require(await transport.requests().first?.body))
        #expect(body["messages"]?[0]?["tool_calls"]?[0]?["function"]?["arguments"] == #""unparseable""#)
    }

    @Test func inlineTextFilePreservesUTF8AndMetadata() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"ok"},"finish_reason":"stop"}]}"#))
        let provider = OpenAICompatibleProvider(configuration: .init(name: "custom", baseURL: "https://api.test/v1", transport: transport))
        _ = try await provider.chatModel("model").generate(.init(messages: [AIMessage(role: .user, content: [.file(mimeType: "text/plain", data: Data("Résumé: café, 日本語".utf8), filename: nil, providerMetadata: ["openaiCompatible": ["cache_control": ["type": "ephemeral"]]])])]))
        let body = try decodeJSONBody(#require(await transport.requests().first?.body))
        #expect(body["messages"]?[0]?["content"]?[0]?["text"] == "Résumé: café, 日本語")
        #expect(body["messages"]?[0]?["content"]?[0]?["cache_control"]?["type"] == "ephemeral")
    }

    @Test func explicitNullReasoningOverridesPortableReasoning() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"ok"},"finish_reason":"stop"}]}"#))
        let provider = OpenAICompatibleProvider(configuration: .init(name: "custom", baseURL: "https://api.test/v1", transport: transport))
        _ = try await provider.chatModel("model").generate(.init(messages: [.user("Hi")], reasoning: "high", providerOptions: ["custom": ["reasoningEffort": .null]]))
        let body = try decodeJSONBody(#require(await transport.requests().first?.body))
        #expect(body["reasoning_effort"] == .null)
    }
}
