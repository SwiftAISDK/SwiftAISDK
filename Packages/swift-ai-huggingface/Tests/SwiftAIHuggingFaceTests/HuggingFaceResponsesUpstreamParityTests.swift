@testable import SwiftAIHuggingFace
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translated from packages/huggingface/src/responses/huggingface-responses-language-model.test.ts
// (@ai-sdk/huggingface 2.0.93). Fixtures and expected outcomes are kept; Swift result
// shapes replace the TypeScript snapshots.

private let basicResponse = #"{"id":"resp_67c97c0203188190a025beb4a75242bc","model":"deepseek-ai/DeepSeek-V3-0324","object":"response","created_at":1741257730,"status":"completed","error":null,"instructions":null,"max_output_tokens":null,"metadata":null,"tool_choice":"auto","tools":[],"temperature":1.0,"top_p":1.0,"incomplete_details":null,"usage":{"input_tokens":12,"output_tokens":25,"total_tokens":37},"output":[{"id":"msg_67c97c02656c81908e080dfdf4a03cd1","type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"Hello! How can I help you today?"}]}],"output_text":"Hello! How can I help you today?"}"#

private let emptyOutputResponse = #"{"id":"resp_test","model":"moonshotai/Kimi-K2-Instruct","object":"response","created_at":1741257730,"status":"completed","error":null,"instructions":null,"max_output_tokens":null,"metadata":null,"tool_choice":"auto","tools":[],"temperature":1.0,"top_p":1.0,"incomplete_details":null,"usage":null,"output":[],"output_text":"Test response"}"#

private func hfModel(_ transport: RecordingTransport, _ modelID: String = "deepseek-ai/DeepSeek-V3-0324") throws -> any LanguageModel {
    try AIProviders.huggingFace(configuration: HuggingFaceProviderSettings(apiKey: "APIKEY", transport: transport)).languageModel(modelID)
}

private func sse(_ chunks: [String]) -> AIHTTPResponse {
    AIHTTPResponse(statusCode: 200, headers: ["content-type": "text/event-stream"], body: Data(chunks.map { $0 + "\n\n" }.joined().utf8))
}

private func collect(_ stream: AsyncThrowingStream<LanguageStreamPart, Error>) async throws -> [LanguageStreamPart] {
    var parts: [LanguageStreamPart] = []
    for try await part in stream { parts.append(part) }
    return parts
}

/// Upstream exposes the request body on the result, not as a stream part.
private func describe(_ parts: [LanguageStreamPart]) -> [String] {
    parts.compactMap { part in
        switch part {
        case let .streamStart(warnings): return "stream-start:\(warnings.count)"
        case .requestMetadata: return nil
        case let .responseMetadata(metadata):
            return "response-metadata:\(metadata.id ?? "-"):\(metadata.modelID ?? "-"):\(Int(metadata.timestamp?.timeIntervalSince1970 ?? -1))"
        case let .textStart(id, metadata): return "text-start:\(id):\(metadata["huggingface"]?["itemId"]?.stringValue ?? "-")"
        case let .textDeltaPart(id, delta, metadata): return "text-delta:\(id):\(delta)\(metadata.isEmpty ? "" : ":meta")"
        case let .textEnd(id, metadata): return "text-end:\(id)\(metadata.isEmpty ? "" : ":meta")"
        case let .reasoningStart(id, metadata): return "reasoning-start:\(id):\(metadata["huggingface"]?["itemId"]?.stringValue ?? "-")"
        case let .reasoningDeltaPart(id, delta, metadata): return "reasoning-delta:\(id):\(delta)\(metadata.isEmpty ? "" : ":meta")"
        case let .reasoningEnd(id, metadata): return "reasoning-end:\(id)\(metadata.isEmpty ? "" : ":meta")"
        case let .toolInputStart(id, name, _, _, _, _): return "tool-input-start:\(id):\(name)"
        case let .toolInputEnd(id, _): return "tool-input-end:\(id)"
        case let .toolCall(call): return "tool-call:\(call.id):\(call.name):\(call.arguments)"
        case let .toolResult(result): return "tool-result:\(result.toolCallID):\(result.toolName):\(result.result.stringValue ?? "-")"
        case .error: return "error"
        case let .finishMetadata(reason, _, metadata):
            return "finish:\(reason ?? "-"):\(metadata["huggingface"]?["responseId"]?.stringValue ?? "null")"
        default: return "other"
        }
    }
}

private func finishUsage(_ parts: [LanguageStreamPart]) -> TokenUsage?? {
    for part in parts { if case let .finishMetadata(_, usage, _) = part { return .some(usage) } }
    return .none
}

// MARK: - doGenerate

@Test func huggingFaceGenerateTextKeepsItemIDLikeUpstream() async throws {
    let result = try await hfModel(RecordingTransport(response: jsonResponse(basicResponse))).generate(LanguageModelRequest(messages: [.user("Hello")]))
    #expect(result.content == [
        .text("Hello! How can I help you today?", providerMetadata: ["huggingface": ["itemId": "msg_67c97c02656c81908e080dfdf4a03cd1"]])
    ])
}

@Test func huggingFaceGenerateExtractsUsageLikeUpstream() async throws {
    let result = try await hfModel(RecordingTransport(response: jsonResponse(basicResponse))).generate(LanguageModelRequest(messages: [.user("Hello")]))
    #expect(result.usage == TokenUsage(
        inputTokens: 12, outputTokens: 25, totalTokens: 37,
        inputTokensNoCache: 12, inputTokensCacheRead: 0,
        outputTextTokens: 25, outputReasoningTokens: 0,
        rawValue: ["input_tokens": 12, "output_tokens": 25, "total_tokens": 37]
    ))
}

@Test func huggingFaceGenerateReadsOutputArrayWhenOutputTextIsMissing() async throws {
    let body = #"{"id":"resp_test","model":"deepseek-ai/DeepSeek-V3-0324","object":"response","created_at":1741257730,"status":"completed","error":null,"instructions":null,"max_output_tokens":null,"metadata":null,"tool_choice":"auto","tools":[],"temperature":1.0,"top_p":1.0,"incomplete_details":null,"usage":null,"output":[{"id":"msg_test","type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"Extracted from output array"}]}],"output_text":null}"#
    let result = try await hfModel(RecordingTransport(response: jsonResponse(body))).generate(LanguageModelRequest(messages: [.user("Hello")]))
    #expect(result.content == [.text("Extracted from output array", providerMetadata: ["huggingface": ["itemId": "msg_test"]])])
}

@Test func huggingFaceGenerateHandlesMissingUsageAndIgnoresOutputText() async throws {
    let result = try await hfModel(RecordingTransport(response: jsonResponse(emptyOutputResponse))).generate(LanguageModelRequest(messages: [.user("Hello")]))
    #expect(result.usage == nil)
    // Upstream builds content only from `output`; `output_text` is not used.
    #expect(result.content.isEmpty)
    #expect(result.text == "")
    #expect(result.finishReason == "stop")
}

@Test func huggingFaceGenerateSendsModelSettingsAndInputLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(basicResponse))
    _ = try await hfModel(transport).generate(LanguageModelRequest(
        messages: [.system("You are a helpful assistant."), .user("Hello")],
        temperature: 0.5,
        topP: 0.3,
        maxOutputTokens: 100
    ))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body == [
        "model": "deepseek-ai/DeepSeek-V3-0324",
        "temperature": 0.5,
        "top_p": 0.3,
        "max_output_tokens": 100,
        "stream": false,
        "input": [
            ["role": "system", "content": "You are a helpful assistant."],
            ["role": "user", "content": [["type": "input_text", "text": "Hello"]]]
        ]
    ])
}

@Test func huggingFaceGenerateWarnsAboutUnsupportedSettingsLikeUpstream() async throws {
    let result = try await hfModel(RecordingTransport(response: jsonResponse(basicResponse))).generate(LanguageModelRequest(
        messages: [.user("Hello")],
        topK: 10,
        presencePenalty: 0.5,
        frequencyPenalty: 0.3,
        seed: 123,
        stopSequences: ["stop"]
    ))
    #expect(result.warnings == [
        AIWarning(type: "unsupported", feature: "topK"),
        AIWarning(type: "unsupported", feature: "seed"),
        AIWarning(type: "unsupported", feature: "presencePenalty"),
        AIWarning(type: "unsupported", feature: "frequencyPenalty"),
        AIWarning(type: "unsupported", feature: "stopSequences")
    ])
}

@Test func huggingFaceGenerateEmitsSourcesAfterAnnotatedTextLikeUpstream() async throws {
    let body = #"{"id":"resp_test_annotations","model":"deepseek-ai/DeepSeek-V3-0324","object":"response","created_at":1741257730,"status":"completed","error":null,"instructions":null,"max_output_tokens":null,"metadata":null,"tool_choice":"auto","tools":[],"temperature":1.0,"top_p":1.0,"incomplete_details":null,"usage":{"input_tokens":20,"output_tokens":50,"total_tokens":70},"output":[{"id":"msg_test_annotations","type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"Here are some recent articles about AI.","annotations":[{"type":"url_citation","url":"https://example.com/article1","title":"AI Developments Article"},{"type":"url_citation","url":"https://test.com/article2","title":"Industry Trends Report"}]}]}],"output_text":null}"#
    let result = try await hfModel(RecordingTransport(response: jsonResponse(body))).generate(LanguageModelRequest(messages: [.user("Hello")]))
    #expect(result.content.count == 3)
    #expect(result.content.first == .text("Here are some recent articles about AI.", providerMetadata: ["huggingface": ["itemId": "msg_test_annotations"]]))
    #expect(result.sources.map(\.url) == ["https://example.com/article1", "https://test.com/article2"])
    #expect(result.sources.map(\.title) == ["AI Developments Article", "Industry Trends Report"])
    #expect(result.sources.allSatisfy { $0.sourceType == "url" })
    #expect(Set(result.sources.map(\.id)).count == 2)
}

@Test func huggingFaceGenerateOrdersMCPToolsBeforeAnnotatedTextLikeUpstream() async throws {
    let body = #"{"id":"resp_mcp_test","model":"deepseek-ai/DeepSeek-V3-0324","object":"response","created_at":1741257730,"status":"completed","error":null,"instructions":null,"max_output_tokens":null,"metadata":null,"tool_choice":"auto","tools":[],"temperature":1.0,"top_p":1.0,"incomplete_details":null,"usage":{"input_tokens":50,"output_tokens":100,"total_tokens":150},"output":[{"id":"mcp_search_test","type":"mcp_call","server_label":"web_search","name":"search","arguments":"{\"query\": \"San Francisco tech events\"}","output":"Found 25 tech events in San Francisco"},{"id":"msg_mcp_response","type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"Based on the search results.","annotations":[{"type":"url_citation","url":"https://techevents.com/sf-ai","title":"SF AI Conference 2025"},{"type":"url_citation","url":"https://eventbrite.com/sf-startups","title":"SF Startup Meetups"}]}]}],"output_text":null}"#
    let result = try await hfModel(RecordingTransport(response: jsonResponse(body))).generate(LanguageModelRequest(messages: [.user("Hello")]))
    #expect(result.content.count == 5)
    guard case let .toolCall(call) = result.content[0], case let .toolResult(toolResult) = result.content[1] else {
        Issue.record("Expected MCP tool call and result first"); return
    }
    #expect(call.id == "mcp_search_test")
    #expect(call.name == "search")
    #expect(call.arguments == #"{"query": "San Francisco tech events"}"#)
    #expect(call.providerExecuted)
    #expect(toolResult.toolCallID == "mcp_search_test")
    #expect(toolResult.toolName == "search")
    #expect(toolResult.result == "Found 25 tech events in San Francisco")
    #expect(toolResult.providerMetadata.isEmpty)
    #expect(result.content[2] == .text("Based on the search results.", providerMetadata: ["huggingface": ["itemId": "msg_mcp_response"]]))
    #expect(result.sources.map(\.url) == ["https://techevents.com/sf-ai", "https://eventbrite.com/sf-startups"])
}

@Test func huggingFaceGenerateTurnsBodyErrorIntoNonRetryableAPICallError() async throws {
    let body = #"{"id":"resp_err","model":"m","object":"response","created_at":1,"status":"failed","error":{"message":"Model is overloaded"},"output":[]}"#
    do {
        _ = try await hfModel(RecordingTransport(response: jsonResponse(body))).generate(LanguageModelRequest(messages: [.user("Hello")]))
        Issue.record("Expected an error")
    } catch let AIError.apiCall(error) {
        #expect(error.statusCode == 400)
        #expect(error.message == "Model is overloaded")
        #expect(error.isRetryable == false)
        #expect(error.responseBody == body)
        #expect(error.url == "https://router.huggingface.co/v1/responses")
    }
}

// MARK: - message conversion

@Test func huggingFaceConvertsUserImagesLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(emptyOutputResponse))
    _ = try await hfModel(transport).generate(LanguageModelRequest(messages: [
        AIMessage(role: .user, content: [
            .text("What do you see?"),
            .file(mimeType: "image/jpeg", data: Data(base64Encoded: "AQIDBA==")!, filename: nil)
        ])
    ]))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["input"]?[0]?["content"] == [
        ["type": "input_text", "text": "What do you see?"],
        ["type": "input_image", "image_url": "data:image/jpeg;base64,AQIDBA=="]
    ])
}

@Test func huggingFaceConvertsAssistantMessagesLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(emptyOutputResponse))
    _ = try await hfModel(transport).generate(LanguageModelRequest(messages: [
        .user("Hello"),
        AIMessage(role: .assistant, content: [.text("Hi there!")]),
        .user("How are you?")
    ]))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["input"] == [
        ["role": "user", "content": [["type": "input_text", "text": "Hello"]]],
        ["role": "assistant", "content": [["type": "output_text", "text": "Hi there!"]]],
        ["role": "user", "content": [["type": "input_text", "text": "How are you?"]]]
    ])
}

@Test func huggingFaceAssistantToolPartsAreSkippedWithoutWarningsAndReasoningIsSentLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(emptyOutputResponse))
    let result = try await hfModel(transport).generate(LanguageModelRequest(messages: [
        AIMessage(role: .assistant, content: [
            .toolCall(AIToolCall(id: "test", name: "test", arguments: "{}")),
            .reasoning("thinking...")
        ])
    ]))
    #expect(result.warnings.isEmpty)
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["input"] == [
        ["role": "assistant", "content": [["type": "output_text", "text": "thinking..."]]]
    ])
}

@Test func huggingFaceWarnsAboutToolMessagesLikeUpstream() async throws {
    let result = try await hfModel(RecordingTransport(response: jsonResponse(emptyOutputResponse))).generate(LanguageModelRequest(messages: [
        AIMessage(role: .tool, content: [.toolResult(AIToolResult(toolCallID: "test", toolName: "test", result: "test"))])
    ]))
    #expect(result.warnings == [AIWarning(type: "unsupported", feature: "tool messages")])
}

// MARK: - tool calls, structured output, reasoning, provider options, tool preparation

@Test func huggingFaceGenerateHandlesFunctionCallOutputsLikeUpstream() async throws {
    let body = #"{"id":"resp_tool_test","model":"deepseek-ai/DeepSeek-V3-0324","object":"response","created_at":1741257730,"status":"completed","error":null,"instructions":null,"max_output_tokens":null,"metadata":null,"tool_choice":"auto","tools":[],"temperature":1.0,"top_p":1.0,"incomplete_details":null,"usage":{"input_tokens":50,"output_tokens":30,"total_tokens":80},"output":[{"id":"fc_test","type":"function_call","call_id":"call_123","name":"getWeather","arguments":"{\"location\": \"New York\"}","output":"{\"temperature\": \"72°F\", \"condition\": \"sunny\"}"},{"id":"msg_after_tool","type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"The weather in New York is 72°F and sunny."}]}],"output_text":null}"#
    let result = try await hfModel(RecordingTransport(response: jsonResponse(body))).generate(LanguageModelRequest(messages: [.user("Hello")]))
    #expect(result.content.count == 3)
    guard case let .toolCall(call) = result.content[0], case let .toolResult(toolResult) = result.content[1] else {
        Issue.record("Expected tool call then tool result"); return
    }
    #expect(call.id == "call_123")
    #expect(call.name == "getWeather")
    #expect(call.arguments == #"{"location": "New York"}"#)
    #expect(call.providerExecuted == false)
    #expect(toolResult.toolCallID == "call_123")
    #expect(toolResult.result == #"{"temperature": "72°F", "condition": "sunny"}"#)
    #expect(result.content[2] == .text("The weather in New York is 72°F and sunny.", providerMetadata: ["huggingface": ["itemId": "msg_after_tool"]]))
}

@Test func huggingFaceSendsTextFormatForStructuredOutputLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(emptyOutputResponse))
    let model = try hfModel(transport, "moonshotai/Kimi-K2-Instruct")
    _ = try await model.generate(LanguageModelRequest(
        messages: [.user("Hello")],
        responseFormat: .json(schema: ["type": "object", "properties": ["name": ["type": "string"], "age": ["type": "number"]], "required": ["name", "age"]])
    ))
    _ = try await model.generate(LanguageModelRequest(
        messages: [.user("Hello")],
        responseFormat: .json(schema: ["type": "object", "properties": ["name": ["type": "string"]]], name: "person_profile", description: "A person profile with basic information")
    ))
    let requests = await transport.requests()
    let first = try decodeJSONBody(try #require(requests[0].body))
    let second = try decodeJSONBody(try #require(requests[1].body))
    #expect(first["text"] == ["format": [
        "type": "json_schema",
        "strict": false,
        "name": "response",
        "schema": ["type": "object", "properties": ["name": ["type": "string"], "age": ["type": "number"]], "required": ["name", "age"]]
    ]])
    #expect(second["text"]?["format"]?["name"] == "person_profile")
    #expect(second["text"]?["format"]?["description"] == "A person profile with basic information")
}

@Test func huggingFaceGenerateKeepsReasoningBeforeTextLikeUpstream() async throws {
    let body = #"{"id":"resp_reasoning","model":"deepseek-ai/DeepSeek-R1","object":"response","created_at":1741257730,"status":"completed","error":null,"instructions":null,"max_output_tokens":null,"metadata":null,"tool_choice":"auto","tools":[],"temperature":1.0,"top_p":1.0,"incomplete_details":null,"usage":{"input_tokens":10,"output_tokens":50,"total_tokens":60},"output":[{"id":"reasoning_1","type":"reasoning","content":[{"type":"reasoning_text","text":"Let me think about this problem step by step..."}]},{"id":"msg_after_reasoning","type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"The answer is 42."}]}],"output_text":null}"#
    let result = try await hfModel(RecordingTransport(response: jsonResponse(body)), "deepseek-ai/DeepSeek-R1").generate(LanguageModelRequest(messages: [.user("Hello")]))
    #expect(result.content == [
        .reasoning("Let me think about this problem step by step...", providerMetadata: ["huggingface": ["itemId": "reasoning_1"]]),
        .text("The answer is 42.", providerMetadata: ["huggingface": ["itemId": "msg_after_reasoning"]])
    ])
}

@Test func huggingFaceSendsProviderSpecificOptionsLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(emptyOutputResponse))
    _ = try await hfModel(transport).generate(LanguageModelRequest(
        messages: [.user("Hello")],
        responseFormat: .json(schema: ["type": "object"]),
        providerOptions: ["huggingface": ["metadata": ["key": "value"], "instructions": "Be concise", "strictJsonSchema": true]]
    ))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["metadata"] == ["key": "value"])
    #expect(body["instructions"] == "Be concise")
    #expect(body["text"]?["format"]?["strict"] == true)
}

@Test func huggingFacePreparesToolsLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(emptyOutputResponse))
    _ = try await hfModel(transport).generate(LanguageModelRequest(
        messages: [.user("Hello")],
        tools: ["getWeather": [
            "description": "Get weather information",
            "type": "object",
            "properties": ["location": ["type": "string"]],
            "required": ["location"]
        ]],
        toolChoice: ["type": "tool", "toolName": "getWeather"]
    ))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["tools"] == [[
        "type": "function",
        "name": "getWeather",
        "description": "Get weather information",
        "parameters": ["type": "object", "properties": ["location": ["type": "string"]], "required": ["location"]]
    ]])
    #expect(body["tool_choice"] == ["type": "function", "function": ["name": "getWeather"]])
}

@Test(arguments: ["auto", "required", "none"])
func huggingFaceForwardsToolChoiceLikeUpstream(_ choice: String) async throws {
    let transport = RecordingTransport(response: jsonResponse(emptyOutputResponse))
    _ = try await hfModel(transport).generate(LanguageModelRequest(
        messages: [.user("Hello")],
        tools: ["test": ["type": "object"]],
        toolChoice: ["type": .string(choice)]
    ))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["tool_choice"] == .string(choice))
    #expect(body["tools"] == [["type": "function", "name": "test", "parameters": ["type": "object"]]])
}

@Test func huggingFaceKeepsEmptyToolListWhenOnlyProviderToolsAreDeclared() async throws {
    let transport = RecordingTransport(response: jsonResponse(emptyOutputResponse))
    let result = try await hfModel(transport).generate(LanguageModelRequest(
        messages: [.user("Hello")],
        tools: ["web": ["type": "provider", "id": "huggingface.web"]],
        toolChoice: ["type": "auto"]
    ))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["tools"] == [])
    #expect(body["tool_choice"] == "auto")
    #expect(result.warnings == [AIWarning(type: "unsupported", feature: "provider-defined tool huggingface.web")])
}

// MARK: - doStream

@Test func huggingFaceStreamForwardsToolChoiceNoneWithTools() async throws {
    let transport = RecordingTransport(response: sse([
        #"data:{"type":"response.completed","response":{"id":"resp_test","status":"completed","incomplete_details":null,"usage":null},"sequence_number":1}"#
    ]))
    _ = try await collect(try hfModel(transport, "test-model").stream(LanguageModelRequest(
        messages: [.user("Hello")],
        tools: ["test": ["type": "object"]],
        toolChoice: ["type": "none"]
    )))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["tool_choice"] == "none")
    #expect(body["tools"] == [["type": "function", "name": "test", "parameters": ["type": "object"]]])
}

@Test(arguments: [false, true])
func huggingFaceStreamHandlesTruncatedStream(_ withError: Bool) async throws {
    var chunks = [
        #"data: {"type":"response.created","response":{"id":"r1","created_at":1,"model":"test-model","status":"in_progress"}}"#,
        #"data: {"type":"response.output_text.delta","item_id":"msg1","output_index":0,"content_index":0,"delta":"Partial answer","sequence_number":1}"#
    ]
    if withError { chunks.append("data: {invalid-json}") }
    let parts = try await collect(try hfModel(RecordingTransport(response: sse(chunks)), "test-model").stream(LanguageModelRequest(messages: [.user("Hello")])))
    let described = describe(parts)
    #expect(described.contains("text-delta:msg1:Partial answer"))
    #expect(described.filter { $0 == "error" }.count == (withError ? 1 : 0))
    #expect(described.filter { $0.hasPrefix("finish:") } == ["finish:\(withError ? "error" : "interrupted"):r1"])
}

@Test func huggingFaceStreamsTextDeltasLikeUpstream() async throws {
    let transport = RecordingTransport(response: sse([
        #"data:{"type":"response.created","response":{"id":"resp_test","object":"response","created_at":1741269019,"status":"in_progress","model":"deepseek-ai/DeepSeek-V3-0324"}}"#,
        #"data:{"type":"response.in_progress","response":{"id":"resp_test","object":"response","created_at":1741269019,"status":"in_progress"}}"#,
        #"data:{"type":"response.output_item.added","output_index":0,"item":{"id":"msg_test","type":"message","role":"assistant","status":"in_progress","content":[]},"sequence_number":1}"#,
        #"data:{"type":"response.output_text.delta","item_id":"msg_test","output_index":0,"content_index":0,"delta":"Hello,","sequence_number":2}"#,
        #"data:{"type":"response.output_text.delta","item_id":"msg_test","output_index":0,"content_index":0,"delta":" World!","sequence_number":3}"#,
        #"data:{"type":"response.output_item.done","output_index":0,"item":{"id":"msg_test","type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"Hello, World!"}]},"sequence_number":4}"#,
        #"data:{"type":"response.completed","response":{"id":"resp_test","model":"deepseek-ai/DeepSeek-V3-0324","object":"response","created_at":1741269112,"status":"completed","incomplete_details":null,"usage":{"input_tokens":12,"output_tokens":25,"total_tokens":37},"output":[{"id":"msg_test","type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"Hello, World!"}]}]},"sequence_number":5}"#
    ]))
    let parts = try await collect(try hfModel(transport).stream(LanguageModelRequest(messages: [.user("Hello")])))
    #expect(describe(parts) == [
        "stream-start:0",
        "response-metadata:resp_test:deepseek-ai/DeepSeek-V3-0324:1741269019",
        "text-start:msg_test:msg_test",
        "text-delta:msg_test:Hello,",
        "text-delta:msg_test: World!",
        "text-end:msg_test",
        "finish:stop:resp_test"
    ])
    #expect(finishUsage(parts) == .some(TokenUsage(
        inputTokens: 12, outputTokens: 25, totalTokens: 37,
        inputTokensNoCache: 12, inputTokensCacheRead: 0,
        outputTextTokens: 25, outputReasoningTokens: 0,
        rawValue: ["input_tokens": 12, "output_tokens": 25, "total_tokens": 37]
    )))
}

@Test func huggingFaceStreamWithoutUsageLikeUpstream() async throws {
    let parts = try await collect(try hfModel(RecordingTransport(response: sse([
        #"data:{"type":"response.output_item.added","output_index":0,"item":{"id":"msg_test","type":"message","role":"assistant","status":"in_progress"},"sequence_number":1}"#,
        #"data:{"type":"response.output_text.delta","item_id":"msg_test","output_index":0,"content_index":0,"delta":"Hi!","sequence_number":2}"#,
        #"data:{"type":"response.output_item.done","output_index":0,"item":{"id":"msg_test","type":"message","role":"assistant","status":"completed"},"sequence_number":3}"#,
        #"data:{"type":"response.completed","response":{"id":"resp_test","status":"completed","incomplete_details":null,"usage":null},"sequence_number":4}"#
    ]))).stream(LanguageModelRequest(messages: [.user("Hello")])))
    #expect(finishUsage(parts) == .some(nil))
}

@Test func huggingFaceStreamIgnoresNonMessageItemsLikeUpstream() async throws {
    let parts = try await collect(try hfModel(RecordingTransport(response: sse([
        #"data:{"type":"response.output_item.added","output_index":0,"item":{"id":"mcp_test","type":"mcp_list_tools","server_label":"test"},"sequence_number":1}"#,
        #"data:{"type":"response.output_item.done","output_index":0,"item":{"id":"mcp_test","type":"mcp_list_tools","server_label":"test"},"sequence_number":2}"#,
        #"data:{"type":"response.completed","response":{"id":"resp_test","status":"completed","incomplete_details":null},"sequence_number":3}"#
    ]))).stream(LanguageModelRequest(messages: [.user("Hello")])))
    #expect(describe(parts) == ["stream-start:0", "finish:stop:resp_test"])
}

@Test func huggingFaceStreamReportsMalformedChunksLikeUpstream() async throws {
    let parts = try await collect(try hfModel(RecordingTransport(response: sse([
        #"data:{"type":"response.output_item.added","output_index":0,"item":{"id":"msg_test","type":"message","role":"assistant"},"sequence_number":1}"#,
        "data:invalid json}"
    ]))).stream(LanguageModelRequest(messages: [.user("Hello")])))
    let described = describe(parts)
    #expect(described.contains("error"))
    #expect(described.last == "finish:error:null")
}

@Test func huggingFaceStreamPreservesResponseFailedAndErrorEventsLikeUpstream() async throws {
    let failed = #"{"type":"response.failed","response":{"error":{"code":"429","message":"Rate limit reached"}},"sequence_number":1}"#
    let flat = #"{"type":"error","code":"503","message":"Service unavailable","param":null,"sequence_number":1}"#
    for (event, type, message, code) in [(failed, "response.failed", "Rate limit reached", "429"), (flat, "error", "Service unavailable", "503")] {
        let parts = try await collect(try hfModel(RecordingTransport(response: sse(["data:" + event]))).stream(LanguageModelRequest(messages: [.user("Hello")])))
        let errors = parts.compactMap(\.streamProviderError)
        #expect(errors.count == 1)
        #expect(errors.first?.message == message)
        #expect(errors.first?.type == type)
        #expect(errors.first?.code == .string(code))
        #expect(errors.first?.data == (try decodeJSONBody(Data(event.utf8))))
        #expect(describe(parts).last == "finish:error:null")
    }
}

@Test func huggingFaceSendsStreamingRequestLikeUpstream() async throws {
    let transport = RecordingTransport(response: sse([
        #"data:{"type":"response.completed","response":{"id":"resp_test","status":"completed"},"sequence_number":1}"#
    ]))
    _ = try await collect(try hfModel(transport).stream(LanguageModelRequest(messages: [.user("Hello")], temperature: 0.7)))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body == [
        "model": "deepseek-ai/DeepSeek-V3-0324",
        "temperature": 0.7,
        "stream": true,
        "input": [["role": "user", "content": [["type": "input_text", "text": "Hello"]]]]
    ])
}

@Test func huggingFaceStreamsToolCallsLikeUpstream() async throws {
    let parts = try await collect(try hfModel(RecordingTransport(response: sse([
        #"data:{"type":"response.created","response":{"id":"resp_tool_stream","object":"response","created_at":1741269019,"status":"in_progress","model":"deepseek-ai/DeepSeek-V3-0324"}}"#,
        #"data:{"type":"response.output_item.added","output_index":0,"item":{"id":"fc_stream","type":"function_call","call_id":"call_456","name":"calculator","arguments":""},"sequence_number":1}"#,
        #"data:{"type":"response.function_call_arguments.delta","item_id":"fc_stream","output_index":0,"delta":"{\"operation\"","sequence_number":2}"#,
        #"data:{"type":"response.function_call_arguments.delta","item_id":"fc_stream","output_index":0,"delta":": \"add\", \"a\": 5, \"b\": 3}","sequence_number":3}"#,
        #"data:{"type":"response.output_item.done","output_index":0,"item":{"id":"fc_stream","type":"function_call","call_id":"call_456","name":"calculator","arguments":"{\"operation\": \"add\", \"a\": 5, \"b\": 3}","output":"8"},"sequence_number":4}"#,
        #"data:{"type":"response.completed","response":{"id":"resp_tool_stream","status":"completed","usage":{"input_tokens":20,"output_tokens":15,"total_tokens":35}},"sequence_number":5}"#
    ]))).stream(LanguageModelRequest(messages: [.user("Hello")])))
    #expect(describe(parts) == [
        "stream-start:0",
        "response-metadata:resp_tool_stream:deepseek-ai/DeepSeek-V3-0324:1741269019",
        "tool-input-start:call_456:calculator",
        "tool-input-end:call_456",
        #"tool-call:call_456:calculator:{"operation": "add", "a": 5, "b": 3}"#,
        "tool-result:call_456:calculator:8",
        "finish:stop:resp_tool_stream"
    ])
    #expect(finishUsage(parts)??.inputTokensNoCache == 20)
}

@Test func huggingFaceStreamsReasoningLikeUpstream() async throws {
    let parts = try await collect(try hfModel(RecordingTransport(response: sse([
        #"data:{"type":"response.created","response":{"id":"resp_reasoning_stream","object":"response","created_at":1741269019,"status":"in_progress","model":"deepseek-ai/DeepSeek-R1"}}"#,
        #"data:{"type":"response.output_item.added","output_index":0,"item":{"id":"reasoning_stream","type":"reasoning"},"sequence_number":1}"#,
        #"data:{"type":"response.reasoning_text.delta","item_id":"reasoning_stream","output_index":0,"content_index":0,"delta":"Thinking about","sequence_number":2}"#,
        #"data:{"type":"response.reasoning_text.delta","item_id":"reasoning_stream","output_index":0,"content_index":0,"delta":" the problem...","sequence_number":3}"#,
        #"data:{"type":"response.reasoning_text.done","item_id":"reasoning_stream","output_index":0,"content_index":0,"text":"Thinking about the problem...","sequence_number":4}"#,
        #"data:{"type":"response.output_item.done","output_index":0,"item":{"id":"reasoning_stream","type":"reasoning","content":[{"type":"reasoning_text","text":"Thinking about the problem..."}]},"sequence_number":5}"#,
        #"data:{"type":"response.output_item.added","output_index":1,"item":{"id":"msg_stream","type":"message","role":"assistant"},"sequence_number":6}"#,
        #"data:{"type":"response.output_text.delta","item_id":"msg_stream","output_index":1,"content_index":0,"delta":"The solution is","sequence_number":7}"#,
        #"data:{"type":"response.output_text.delta","item_id":"msg_stream","output_index":1,"content_index":0,"delta":" simple.","sequence_number":8}"#,
        #"data:{"type":"response.output_item.done","output_index":1,"item":{"id":"msg_stream","type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"The solution is simple."}]},"sequence_number":9}"#,
        #"data:{"type":"response.completed","response":{"id":"resp_reasoning_stream","status":"completed","usage":{"input_tokens":10,"output_tokens":20,"total_tokens":30}},"sequence_number":10}"#
    ])), "deepseek-ai/DeepSeek-R1").stream(LanguageModelRequest(messages: [.user("Hello")])))
    #expect(describe(parts) == [
        "stream-start:0",
        "response-metadata:resp_reasoning_stream:deepseek-ai/DeepSeek-R1:1741269019",
        "reasoning-start:reasoning_stream:reasoning_stream",
        "reasoning-delta:reasoning_stream:Thinking about",
        "reasoning-delta:reasoning_stream: the problem...",
        "reasoning-end:reasoning_stream",
        "text-start:msg_stream:msg_stream",
        "text-delta:msg_stream:The solution is",
        "text-delta:msg_stream: simple.",
        "text-end:msg_stream",
        "finish:stop:resp_reasoning_stream"
    ])
}

@Test func huggingFaceStreamDoesNotEmitRawChunksLikeUpstream() async throws {
    let parts = try await collect(try hfModel(RecordingTransport(response: sse([
        #"data:{"type":"response.completed","response":{"id":"resp_test","status":"completed"},"sequence_number":1}"#
    ]))).stream(LanguageModelRequest(messages: [.user("Hello")], includeRawChunks: true)))
    #expect(!parts.contains { if case .raw = $0 { return true }; return false })
}
