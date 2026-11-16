@testable import SwiftAIVercel
import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Testing

// Upstream createVercel composes the generic OpenAICompatibleChatLanguageModel with
// provider "vercel.chat", so the generic provider-option, reasoning, warning and
// empty-content behavior (openai-compatible-chat-language-model.test.ts) applies.

private func vercelModel(_ transport: RecordingTransport) throws -> any LanguageModel {
    try AIProviders.vercel(configuration: VercelProviderSettings(apiKey: "vercel-key", transport: transport)).languageModel("v0-1.5-md")
}

private let emptyContentResponse = #"{"id":"chatcmpl-1","object":"chat.completion","created":1711115037,"model":"v0-1.5-md","choices":[{"index":0,"message":{"role":"assistant","content":""},"finish_reason":"stop"}],"usage":{"prompt_tokens":4,"total_tokens":34,"completion_tokens":30}}"#

@Test func vercelPassesOpenAICompatibleSettingsLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(emptyContentResponse))
    _ = try await vercelModel(transport).generate(LanguageModelRequest(
        messages: [.user("Hello")],
        providerOptions: ["openaiCompatible": ["user": "test-user-id"]]
    ))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body == [
        "model": "v0-1.5-md",
        "messages": [["role": "user", "content": "Hello"]],
        "user": "test-user-id"
    ])
}

@Test func vercelDeprecatedOpenAICompatibleKeyWarnsLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(emptyContentResponse))
    let result = try await vercelModel(transport).generate(LanguageModelRequest(
        messages: [.user("Hello")],
        providerOptions: ["openai-compatible": ["user": "test-user-id"]]
    ))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["user"] == "test-user-id")
    #expect(result.warnings == [AIWarning(type: "deprecated", setting: "providerOptions key 'openai-compatible'", message: "Use 'openaiCompatible' instead.")])
}

@Test func vercelIncludesProviderSpecificOptionsOnlyForVercelKeyLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(emptyContentResponse))
    let model = try vercelModel(transport)
    _ = try await model.generate(LanguageModelRequest(
        messages: [.user("Hello")],
        providerOptions: ["vercel": ["someCustomOption": "test-value"]]
    ))
    _ = try await model.generate(LanguageModelRequest(
        messages: [.user("Hello")],
        providerOptions: ["notThisProviderName": ["someCustomOption": "test-value"]]
    ))
    let requests = await transport.requests()
    let first = try decodeJSONBody(try #require(requests[0].body))
    let second = try decodeJSONBody(try #require(requests[1].body))
    #expect(first["someCustomOption"] == "test-value")
    #expect(second["someCustomOption"] == nil)
}

@Test func vercelMapsTopLevelReasoningAndTextVerbosityLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(emptyContentResponse))
    let model = try vercelModel(transport)
    _ = try await model.generate(LanguageModelRequest(messages: [.user("Hello")], reasoning: "medium"))
    _ = try await model.generate(LanguageModelRequest(
        messages: [.user("Hello")],
        reasoning: "medium",
        providerOptions: ["vercel": ["reasoningEffort": "low", "textVerbosity": "high"]]
    ))
    let requests = await transport.requests()
    let first = try decodeJSONBody(try #require(requests[0].body))
    let second = try decodeJSONBody(try #require(requests[1].body))
    #expect(first["reasoning_effort"] == "medium")
    #expect(second["reasoning_effort"] == "low")
    #expect(second["verbosity"] == "high")
    #expect(second["reasoningEffort"] == nil)
    #expect(second["textVerbosity"] == nil)
}

@Test func vercelWarnsAboutTopKLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(emptyContentResponse))
    let result = try await vercelModel(transport).generate(LanguageModelRequest(messages: [.user("Hello")], topK: 1))
    #expect(result.warnings == [AIWarning(type: "unsupported", feature: "topK")])
}

@Test func vercelAcceptsEmptyAndNullAssistantContentLikeUpstream() async throws {
    let transport = RecordingTransport(responses: [
        jsonResponse(emptyContentResponse),
        jsonResponse(#"{"choices":[{"message":{"role":"assistant","content":null},"finish_reason":"stop"}]}"#)
    ])
    let model = try vercelModel(transport)
    let empty = try await model.generate(LanguageModelRequest(messages: [.user("Hello")]))
    let null = try await model.generate(LanguageModelRequest(messages: [.user("Hello")]))
    #expect(empty.content.isEmpty)
    #expect(empty.text == "")
    #expect(null.content.isEmpty)
    #expect(null.finishReason == "stop")
}

@Test func vercelStreamWithoutFinishReasonReportsErrorLikeUpstream() async throws {
    let transport = RecordingTransport(response: sseResponse("""
    data: {"id":"c1","created":1,"model":"v0-1.5-md","choices":[{"delta":{"content":"Hi"},"finish_reason":null}]}

    data: [DONE]
    """))
    var errors = 0
    var finish: String?
    for try await part in try vercelModel(transport).stream(LanguageModelRequest(messages: [.user("Hello")])) {
        if case .error = part { errors += 1 }
        if case let .finishMetadata(reason, _, _) = part { finish = reason }
    }
    #expect(errors == 1)
    #expect(finish == "error")
}
