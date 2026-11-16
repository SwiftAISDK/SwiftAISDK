@testable import SwiftAIMistral
import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Testing

// Translations of @ai-sdk/mistral 4.0.87 tests (convert-to-mistral-chat-messages.test.ts,
// mistral-prepare-tools.test.ts, mistral-chat-language-model.test.ts) covering behavior that
// previously diverged.

private let mistralTextResponse = """
{"id":"cmpl-1","object":"chat.completion","created":1711113008,"model":"mistral-small-latest","choices":[{"index":0,"message":{"role":"assistant","content":"Hello"},"finish_reason":"stop"}],"usage":{"prompt_tokens":4,"completion_tokens":1,"total_tokens":5}}
"""

private let mistralPNGBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

private func mistralModel(_ transport: RecordingTransport) throws -> any LanguageModel {
    try AIProviders.mistral(configuration: MistralProviderSettings(apiKey: "test-api-key", transport: transport))
        .languageModel("mistral-small-latest")
}

private func mistralRequestBody(_ transport: RecordingTransport) async throws -> JSONValue {
    try decodeJSONBody(try #require(await transport.requests().first?.body))
}

@Test(arguments: ["image", "image/*"])
func mistralUpstreamDetectsPartialImageMediaTypes(mediaType: String) async throws {
    let transport = RecordingTransport(response: jsonResponse(mistralTextResponse))
    _ = try await mistralModel(transport).generate(LanguageModelRequest(messages: [
        AIMessage(role: .user, content: [.data(mimeType: mediaType, data: try #require(Data(base64Encoded: mistralPNGBase64)))])
    ]))
    let body = try await mistralRequestBody(transport)
    #expect(body["messages"]?[0]?["content"]?[0] == [
        "type": "image_url",
        "image_url": .string("data:image/png;base64,\(mistralPNGBase64)")
    ])
}

@Test func mistralUpstreamResolvesTopLevelApplicationMediaTypeToPDF() async throws {
    let transport = RecordingTransport(response: jsonResponse(mistralTextResponse))
    let pdf = Data("%PDF-1.4 test".utf8)
    _ = try await mistralModel(transport).generate(LanguageModelRequest(messages: [
        AIMessage(role: .user, content: [.data(mimeType: "application", data: pdf)])
    ]))
    let body = try await mistralRequestBody(transport)
    #expect(body["messages"]?[0]?["content"]?[0] == [
        "type": "document_url",
        "document_url": .string("data:application/pdf;base64,\(pdf.base64EncodedString())")
    ])
}

@Test func mistralUpstreamMapsToolOutputsAndSkipsApprovalOnlyMessages() async throws {
    let transport = RecordingTransport(response: jsonResponse(mistralTextResponse))
    _ = try await mistralModel(transport).generate(LanguageModelRequest(messages: [
        AIMessage(role: .tool, content: [
            .toolResult(AIToolResult(toolCallID: "a", toolName: "weather", result: "sunny")),
            .toolResult(AIToolResult(toolCallID: "b", toolName: "weather", result: ["ignored": true], modelOutput: ["type": "json", "value": ["url": "https://example.com/a"]]))
        ]),
        AIMessage(role: .tool, content: [
            .toolApprovalResponse(AIToolApprovalResponse(id: "approval-1", approved: true))
        ])
    ]))
    let body = try await mistralRequestBody(transport)
    #expect(body["messages"] == [
        ["role": "tool", "name": "weather", "tool_call_id": "a", "content": "sunny"],
        ["role": "tool", "name": "weather", "tool_call_id": "b", "content": #"{"url":"https://example.com/a"}"#]
    ])
}

@Test func mistralUpstreamSendsEmptyToolsWhenOnlyProviderToolsArePresent() async throws {
    let transport = RecordingTransport(response: jsonResponse(mistralTextResponse))
    let result = try await mistralModel(transport).generate(LanguageModelRequest(
        messages: [.user("Hello")],
        tools: ["search": ["type": "provider", "id": "openai.web_search", "args": [:]]],
        toolChoice: "required",
        providerOptions: ["mistral": ["parallelToolCalls": false]]
    ))
    let body = try await mistralRequestBody(transport)
    #expect(body["tools"] == [])
    #expect(body["tool_choice"] == "any")
    #expect(body["parallel_tool_calls"] == false)
    #expect(result.warnings.map(\.feature) == ["provider-defined tool openai.web_search"])
}

@Test func mistralUpstreamStreamsThinkingBeforeTextWithinAChunk() async throws {
    let transport = RecordingTransport(response: sseResponse("""
    data: {"id":"c1","object":"chat.completion.chunk","created":1750537996,"model":"magistral-small-latest","choices":[{"index":0,"delta":{"role":"assistant","content":[{"type":"thinking","thinking":[{"type":"text","text":"Let me think"}]},{"type":"text","text":"Answer"}]},"finish_reason":null}]}

    data: {"id":"c1","object":"chat.completion.chunk","created":1750537996,"model":"magistral-small-latest","choices":[{"index":0,"delta":{"content":""},"finish_reason":"stop"}],"usage":{"prompt_tokens":4,"completion_tokens":2,"total_tokens":6}}

    data: [DONE]

    """))
    var sequence: [String] = []
    for try await part in try mistralModel(transport).stream(LanguageModelRequest(messages: [.user("Hello")])) {
        switch part {
        case .reasoningStart: sequence.append("reasoning-start")
        case let .reasoningDeltaPart(_, delta, _): sequence.append("reasoning-delta:\(delta)")
        case .reasoningEnd: sequence.append("reasoning-end")
        case .textStart: sequence.append("text-start")
        case let .textDeltaPart(_, delta, _): sequence.append("text-delta:\(delta)")
        case .textEnd: sequence.append("text-end")
        case let .finishMetadata(reason, _, _): sequence.append("finish:\(reason ?? "nil")")
        default: break
        }
    }
    #expect(sequence == [
        "reasoning-start", "reasoning-delta:Let me think", "reasoning-end",
        "text-start", "text-delta:Answer", "text-end", "finish:stop"
    ])
}

/// mistral-prepare-tools / mistral-conversation-prepare-tools send `tool.inputSchema`
/// as `parameters` with description and strict at the function level.
@Test func mistralFunctionToolMetadataStaysOutOfParameters() {
    let tools: [String: JSONValue] = ["lookup": [
        "type": "object", "properties": ["q": ["type": "string"]],
        "description": "Look up", "strict": true,
        "providerOptions": ["mistral": ["flag": true]], "inputExamples": [["input": ["q": "a"]]]
    ]]
    let expected: JSONValue = ["type": "function", "function": [
        "name": "lookup", "description": "Look up", "strict": true,
        "parameters": ["type": "object", "properties": ["q": ["type": "string"]]]
    ]]
    #expect(mistralTools(from: tools).tools == [expected])
    #expect(mistralConversationPrepareTools(tools, choice: nil).tools == [expected])
}
