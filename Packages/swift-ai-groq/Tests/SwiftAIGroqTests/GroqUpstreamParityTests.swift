@testable import SwiftAIGroq
import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Testing

// Translations of @ai-sdk/groq 4.0.84 tests (convert-to-groq-chat-messages.test.ts,
// groq-chat-language-model.test.ts, groq-prepare-tools.test.ts) covering request and
// response behavior that previously diverged.

private let groqTextResponse = """
{"id":"chatcmpl-1","created":1711115037,"model":"gemma2-9b-it","choices":[{"index":0,"message":{"role":"assistant","content":"Hello"},"finish_reason":"stop"}],"usage":{"prompt_tokens":4,"completion_tokens":1,"total_tokens":5}}
"""

// 1x1 PNG.
private let groqPNGBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

private func groqModel(_ transport: RecordingTransport, _ modelID: String = "gemma2-9b-it") throws -> any LanguageModel {
    try AIProviders.groq(configuration: GroqProviderSettings(apiKey: "test-api-key", transport: transport))
        .languageModel(modelID)
}

private func groqRequestBody(_ transport: RecordingTransport) async throws -> JSONValue {
    try decodeJSONBody(try #require(await transport.requests().first?.body))
}

// MARK: - convert-to-groq-chat-messages.test.ts

@Test func groqUpstreamSendsReasoningPartsOfAssistantMessages() async throws {
    let transport = RecordingTransport(response: jsonResponse(groqTextResponse))
    _ = try await groqModel(transport).generate(LanguageModelRequest(messages: [
        AIMessage(role: .assistant, content: [
            .reasoning("I think the tool will return the correct value."),
            .toolCall(AIToolCall(id: "quux", name: "thwomp", arguments: #"{"foo":"bar123"}"#))
        ])
    ]))
    let body = try await groqRequestBody(transport)
    #expect(body["messages"] == [[
        "content": "",
        "reasoning": "I think the tool will return the correct value.",
        "role": "assistant",
        "tool_calls": [[
            "function": ["arguments": #"{"foo":"bar123"}"#, "name": "thwomp"],
            "id": "quux",
            "type": "function"
        ]]
    ]])
}

@Test func groqUpstreamOmitsReasoningFieldWithoutReasoningContent() async throws {
    let transport = RecordingTransport(response: jsonResponse(groqTextResponse))
    _ = try await groqModel(transport).generate(LanguageModelRequest(messages: [
        AIMessage(role: .assistant, content: [.text("Hello, how can I help you?")])
    ]))
    let body = try await groqRequestBody(transport)
    #expect(body["messages"] == [["content": "Hello, how can I help you?", "role": "assistant"]])
}

@Test(arguments: ["image", "image/*"])
func groqUpstreamDetectsImageSubtypeFromInlineBytes(mediaType: String) async throws {
    let transport = RecordingTransport(response: jsonResponse(groqTextResponse))
    _ = try await groqModel(transport).generate(LanguageModelRequest(messages: [
        AIMessage(role: .user, content: [
            .data(mimeType: mediaType, data: try #require(Data(base64Encoded: groqPNGBase64)))
        ])
    ]))
    let body = try await groqRequestBody(transport)
    #expect(body["messages"]?[0]?["content"]?[0] == [
        "type": "image_url",
        "image_url": ["url": .string("data:image/png;base64,\(groqPNGBase64)")]
    ])
}

@Test func groqUpstreamPassesFullImageMediaTypeThrough() async throws {
    let transport = RecordingTransport(response: jsonResponse(groqTextResponse))
    _ = try await groqModel(transport).generate(LanguageModelRequest(messages: [
        AIMessage(role: .user, content: [
            .data(mimeType: "image/png", data: try #require(Data(base64Encoded: groqPNGBase64)))
        ])
    ]))
    let body = try await groqRequestBody(transport)
    #expect(body["messages"]?[0]?["content"]?[0]?["image_url"]?["url"] == .string("data:image/png;base64,\(groqPNGBase64)"))
}

@Test func groqUpstreamMapsToolOutputTypesLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(groqTextResponse))
    _ = try await groqModel(transport).generate(LanguageModelRequest(messages: [
        AIMessage(role: .tool, content: [
            .toolApprovalResponse(AIToolApprovalResponse(id: "approval", approved: true)),
            .toolResult(AIToolResult(toolCallID: "a", toolName: "t", result: ["type": "text", "value": "plain text"])),
            .toolResult(AIToolResult(toolCallID: "b", toolName: "t", result: ["ignored": true], modelOutput: ["type": "json", "value": ["url": "https://example.com/a"]])),
            .toolResult(AIToolResult(toolCallID: "c", toolName: "t", result: ["type": "error-text", "value": "Error: boom"], isError: true)),
            .toolResult(AIToolResult(toolCallID: "d", toolName: "t", result: ["type": "execution-denied"])),
            .toolResult(AIToolResult(toolCallID: "e", toolName: "t", result: "raw string")),
            .toolResult(AIToolResult(toolCallID: "f", toolName: "t", result: ["oldStyle": 1]))
        ])
    ]))
    let body = try await groqRequestBody(transport)
    let contents = body["messages"]?.arrayValue?.map { $0["content"]?.stringValue }
    #expect(body["messages"]?.arrayValue?.map { $0["tool_call_id"]?.stringValue } == ["a", "b", "c", "d", "e", "f"])
    #expect(contents == [
        "plain text",
        #"{"url":"https://example.com/a"}"#,
        "Error: boom",
        "Tool call execution denied.",
        "raw string",
        #"{"oldStyle":1}"#
    ])
}

// MARK: - groq-chat-language-model.test.ts

@Test func groqUpstreamGenerateAcceptsResponseWithoutContent() async throws {
    let transport = RecordingTransport(response: jsonResponse("""
    {"id":"chatcmpl-1","choices":[{"index":0,"message":{"role":"assistant","content":null},"finish_reason":"stop"}]}
    """))
    let result = try await groqModel(transport).generate(LanguageModelRequest(messages: [.user("Hello")]))
    #expect(result.text == "")
    #expect(result.content.isEmpty)
    #expect(result.finishReason == "stop")
}

@Test func groqUpstreamStreamReadsUsageOnlyFromXGroq() async throws {
    let transport = RecordingTransport(response: sseResponse("""
    data: {"id":"chatcmpl-1","created":1702657020,"model":"gemma2-9b-it","choices":[{"index":0,"delta":{"role":"assistant","content":"Hi"},"finish_reason":null}]}

    data: {"id":"chatcmpl-1","created":1702657020,"model":"gemma2-9b-it","choices":[{"index":0,"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":99,"completion_tokens":99}}

    data: [DONE]

    """))
    var usage: TokenUsage?
    var finished = false
    for try await part in try groqModel(transport).stream(LanguageModelRequest(messages: [.user("Hello")])) {
        if case let .finishMetadata(_, partUsage, _) = part {
            usage = partUsage
            finished = true
        }
    }
    #expect(finished)
    #expect(usage == nil)
}

// MARK: - groq-prepare-tools.test.ts

@Test func groqUpstreamSendsEmptyToolsWhenProviderToolsAreUnsupported() async throws {
    let transport = RecordingTransport(response: jsonResponse(groqTextResponse))
    let result = try await groqModel(transport, "llama-3.3-70b-versatile").generate(LanguageModelRequest(
        messages: [.user("Hello")],
        tools: ["browser_search": GroqTools.browserSearch()],
        toolChoice: "required"
    ))
    let body = try await groqRequestBody(transport)
    #expect(body["tools"] == [])
    #expect(body["tool_choice"] == "required")
    #expect(result.warnings.map(\.feature) == ["provider-defined tool groq.browser_search"])
    #expect(result.warnings.map(\.message) == ["Browser search is not supported on model llama-3.3-70b-versatile."])
}
