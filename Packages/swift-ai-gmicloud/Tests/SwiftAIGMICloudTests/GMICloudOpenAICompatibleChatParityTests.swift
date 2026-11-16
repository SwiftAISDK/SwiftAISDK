@testable import SwiftAIGMICloud
import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Testing

// Upstream GmicloudChatLanguageModel extends OpenAICompatibleChatLanguageModel without
// overriding request or response handling, so the generic provider-option, reasoning,
// warning and empty-content behavior (openai-compatible-chat-language-model.test.ts) applies.

private func gmiModel(_ transport: RecordingTransport) throws -> any LanguageModel {
    try GMICloudProvider(configuration: GMICloudProviderSettings(apiKey: "gmi-key", transport: transport))("deepseek-ai/DeepSeek-V4-Flash-0731")
}

private let emptyContentResponse = #"{"id":"chatcmpl-1","object":"chat.completion","created":1711115037,"model":"deepseek-ai/DeepSeek-V4-Flash-0731","choices":[{"index":0,"message":{"role":"assistant","content":""},"finish_reason":"stop"}],"usage":{"prompt_tokens":4,"total_tokens":34,"completion_tokens":30}}"#

@Test func gmiCloudPassesOpenAICompatibleAndProviderOptionsLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(emptyContentResponse))
    let model = try gmiModel(transport)
    _ = try await model.generate(LanguageModelRequest(
        messages: [.user("Hello")],
        providerOptions: ["openaiCompatible": ["user": "test-user-id"]]
    ))
    _ = try await model.generate(LanguageModelRequest(
        messages: [.user("Hello")],
        providerOptions: ["gmicloud": ["someCustomOption": "test-value", "reasoningEffort": "high"]]
    ))
    _ = try await model.generate(LanguageModelRequest(
        messages: [.user("Hello")],
        providerOptions: ["notThisProviderName": ["someCustomOption": "test-value"]]
    ))
    let requests = await transport.requests()
    let first = try decodeJSONBody(try #require(requests[0].body))
    let second = try decodeJSONBody(try #require(requests[1].body))
    let third = try decodeJSONBody(try #require(requests[2].body))
    #expect(first == [
        "model": "deepseek-ai/DeepSeek-V4-Flash-0731",
        "messages": [["role": "user", "content": "Hello"]],
        "user": "test-user-id"
    ])
    #expect(second["someCustomOption"] == "test-value")
    #expect(second["reasoning_effort"] == "high")
    #expect(second["reasoningEffort"] == nil)
    #expect(third["someCustomOption"] == nil)
}

@Test func gmiCloudMapsTopLevelReasoningAndWarnsAboutTopKLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(emptyContentResponse))
    let result = try await gmiModel(transport).generate(LanguageModelRequest(messages: [.user("Hello")], topK: 1, reasoning: "medium"))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["reasoning_effort"] == "medium")
    #expect(result.warnings == [AIWarning(type: "unsupported", feature: "topK")])
}

@Test func gmiCloudAcceptsEmptyAndNullAssistantContentLikeUpstream() async throws {
    let transport = RecordingTransport(responses: [
        jsonResponse(emptyContentResponse),
        jsonResponse(#"{"choices":[{"message":{"role":"assistant","content":null},"finish_reason":"stop"}]}"#)
    ])
    let model = try gmiModel(transport)
    let empty = try await model.generate(LanguageModelRequest(messages: [.user("Hello")]))
    let null = try await model.generate(LanguageModelRequest(messages: [.user("Hello")]))
    #expect(empty.content.isEmpty)
    #expect(null.content.isEmpty)
    #expect(null.finishReason == "stop")
}

// gmicloud-error.test.ts: "falls back to the outer message when details is absent"
@Test func gmiCloudErrorFallsBackToOuterMessageWithoutDetails() async throws {
    let transport = RecordingTransport(response: AIHTTPResponse(
        statusCode: 400,
        headers: [:],
        body: Data(#"{"error":{"message":"Backend request failed with status 400"}}"#.utf8)
    ))
    await #expect(throws: AIError.apiCall(provider: "gmicloud.chat", statusCode: 400, body: "Backend request failed with status 400")) {
        _ = try await gmiModel(transport).generate(LanguageModelRequest(messages: [.user("hi")]))
    }
}
