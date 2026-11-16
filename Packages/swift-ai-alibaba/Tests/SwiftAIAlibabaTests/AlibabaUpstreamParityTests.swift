@testable import SwiftAIAlibaba
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translations of @ai-sdk/alibaba 2.0.91 matching-release tests:
// convert-to-alibaba-chat-messages.test.ts, get-cache-control.test.ts,
// alibaba-prepare-tools.test.ts, alibaba-chat-language-model.test.ts,
// alibaba-provider.test.ts, alibaba-video-model.test.ts,
// convert-alibaba-usage.test.ts.

private let ephemeral: JSONValue = ["type": "ephemeral"]
private let cacheOptions: [String: JSONValue] = ["alibaba": ["cacheControl": ["type": "ephemeral"]]]
private let shouldNotUse: [String: JSONValue] = ["alibaba": ["cacheControl": ["type": "should-not-use"]]]
private let weatherResult: JSONValue = ["type": "json", "value": ["temperature": 72, "condition": "sunny"]]
private let weatherResultText = #"{"condition":"sunny","temperature":72}"#

private func convert(_ messages: [AIMessage], preserveThinking: Bool = false) throws -> [JSONValue] {
    try alibabaMessages(messages, preserveThinking: preserveThinking).messages
}

private func textPart(_ text: String, cache: JSONValue? = nil) -> JSONValue {
    var object: [String: JSONValue] = ["type": "text", "text": .string(text)]
    if let cache { object["cache_control"] = cache }
    return .object(object)
}

private func weatherToolResult(id: String = "call-1", providerMetadata: [String: JSONValue] = [:]) -> AIContentPart {
    .toolResult(AIToolResult(toolCallID: id, toolName: "get_weather", result: weatherResult, modelOutput: weatherResult, providerMetadata: providerMetadata))
}

// MARK: - convert-to-alibaba-chat-messages.test.ts

@Test func alibabaConvertUsesArrayFormatForSingleTextUserMessage() throws {
    #expect(try convert([.user("Hello")]) == [["role": "user", "content": [textPart("Hello")]]])
}

@Test func alibabaConvertUsesArrayFormatForMultiPartUserMessageWithImage() throws {
    let result = try convert([AIMessage(role: .user, content: [
        .text("What is in this image?"),
        .file(mimeType: "image/png", data: Data([0, 1, 2, 3]))
    ])])
    #expect(result == [[
        "role": "user",
        "content": [
            textPart("What is in this image?"),
            ["type": "image_url", "image_url": ["url": "data:image/png;base64,AAECAw=="]]
        ]
    ]])
}

@Test func alibabaConvertsAssistantMessageWithToolCalls() throws {
    let result = try convert([.assistant(toolCalls: [
        AIToolCall(id: "call-1", name: "get_weather", arguments: #"{"location":"San Francisco"}"#)
    ])])
    #expect(result == [[
        "role": "assistant",
        "content": .null,
        "tool_calls": [[
            "id": "call-1",
            "type": "function",
            "function": ["name": "get_weather", "arguments": #"{"location":"San Francisco"}"#]
        ]]
    ]])
}

@Test func alibabaConvertsToolResults() throws {
    let result = try convert([AIMessage(role: .tool, content: [weatherToolResult()])])
    // JSON object keys are sorted because Swift JSON objects are unordered.
    #expect(result == [["role": "tool", "tool_call_id": "call-1", "content": .string(weatherResultText)]])
}

@Test func alibabaConvertConcatenatesAssistantTextWithoutSeparator() throws {
    let result = try convert([AIMessage(role: .assistant, content: [.text("Hello, "), .text("world")])])
    #expect(result == [["role": "assistant", "content": "Hello, world"]])
}

@Test func alibabaConvertEmitsContentNullForPreservedReasoningOnlyMessageWithMessageCacheControl() throws {
    let result = try convert([
        AIMessage(role: .assistant, content: [.reasoning("Hidden reasoning.")], providerMetadata: cacheOptions),
        .user("Continue.")
    ], preserveThinking: true)
    #expect(result == [
        ["role": "assistant", "content": .null, "reasoning_content": "Hidden reasoning."],
        ["role": "user", "content": [textPart("Continue.")]]
    ])
}

@Test func alibabaConvertRetainsCachedContentBlockForToolCallOnlyMessage() throws {
    let result = try convert([
        AIMessage(role: .assistant, content: [
            .toolCall(AIToolCall(id: "call-1", name: "get_weather", arguments: #"{"location":"San Francisco"}"#))
        ], providerMetadata: cacheOptions)
    ], preserveThinking: true)
    #expect(result == [[
        "role": "assistant",
        "content": [textPart("", cache: ephemeral)],
        "tool_calls": [[
            "id": "call-1",
            "type": "function",
            "function": ["name": "get_weather", "arguments": #"{"location":"San Francisco"}"#]
        ]]
    ]])
}

@Test func alibabaConvertInjectsCacheControlIntoSystemMessage() throws {
    let result = try convert([AIMessage(role: .system, content: [.text("You are a helpful assistant.")], providerMetadata: cacheOptions)])
    #expect(result == [["role": "system", "content": [textPart("You are a helpful assistant.", cache: ephemeral)]]])
}

@Test func alibabaConvertInjectsCacheControlIntoSingleTextUserMessage() throws {
    let result = try convert([AIMessage(role: .user, content: [.text("Hello")], providerMetadata: cacheOptions)])
    #expect(result == [["role": "user", "content": [textPart("Hello", cache: ephemeral)]]])
}

@Test func alibabaConvertUsesPartLevelCacheControlForSinglePartUserMessage() throws {
    let result = try convert([AIMessage(role: .user, content: [.text("Hello", providerMetadata: cacheOptions)])])
    #expect(result == [["role": "user", "content": [textPart("Hello", cache: ephemeral)]]])
}

@Test func alibabaConvertPrefersPartLevelOverMessageLevelCacheControlForUserMessage() throws {
    let result = try convert([AIMessage(role: .user, content: [.text("Hello", providerMetadata: cacheOptions)], providerMetadata: shouldNotUse)])
    #expect(result == [["role": "user", "content": [textPart("Hello", cache: ephemeral)]]])
}

@Test func alibabaConvertUsesPartLevelAndMessageLevelCacheControlForMultiPartUserMessage() throws {
    let image: JSONValue = ["type": "image_url", "image_url": ["url": "data:image/png;base64,AAECAw=="], "cache_control": ephemeral]
    let partLevel = try convert([AIMessage(role: .user, content: [
        .text("What is in this image?"),
        .file(mimeType: "image/png", data: Data([0, 1, 2, 3]), providerMetadata: cacheOptions)
    ])])
    #expect(partLevel == [["role": "user", "content": [textPart("What is in this image?"), image]]])

    let messageLevel = try convert([AIMessage(role: .user, content: [
        .text("What is in this image?"),
        .file(mimeType: "image/png", data: Data([0, 1, 2, 3]))
    ], providerMetadata: cacheOptions)])
    #expect(messageLevel == [["role": "user", "content": [textPart("What is in this image?"), image]]])
}

@Test func alibabaConvertInjectsCacheControlIntoAssistantMessage() throws {
    let result = try convert([AIMessage(role: .assistant, content: [.text("Hello, how can I help?")], providerMetadata: cacheOptions)])
    #expect(result == [["role": "assistant", "content": [textPart("Hello, how can I help?", cache: ephemeral)]]])
}

@Test func alibabaConvertInjectsCacheControlIntoToolMessages() throws {
    let expected: [JSONValue] = [[
        "role": "tool",
        "tool_call_id": "call-1",
        "content": [textPart(weatherResultText, cache: ephemeral)]
    ]]
    #expect(try convert([AIMessage(role: .tool, content: [weatherToolResult()], providerMetadata: cacheOptions)]) == expected)
    #expect(try convert([AIMessage(role: .tool, content: [weatherToolResult(providerMetadata: cacheOptions)])]) == expected)
    #expect(try convert([AIMessage(role: .tool, content: [weatherToolResult(providerMetadata: cacheOptions)], providerMetadata: shouldNotUse)]) == expected)
}

@Test func alibabaConvertAppliesMessageLevelCacheControlToLastPartOfMultiPartToolMessage() throws {
    let time: AIContentPart = .toolResult(AIToolResult(
        toolCallID: "call-2",
        toolName: "get_time",
        result: ["type": "text", "value": "2:30 PM"],
        modelOutput: ["type": "text", "value": "2:30 PM"]
    ))
    let result = try convert([AIMessage(role: .tool, content: [weatherToolResult(), time], providerMetadata: cacheOptions)])
    #expect(result == [
        ["role": "tool", "tool_call_id": "call-1", "content": .string(weatherResultText)],
        ["role": "tool", "tool_call_id": "call-2", "content": [textPart("2:30 PM", cache: ephemeral)]]
    ])
}

@Test func alibabaConvertUsesPartLevelCacheControlForMultiPartToolMessage() throws {
    let time: AIContentPart = .toolResult(AIToolResult(
        toolCallID: "call-2",
        toolName: "get_time",
        result: ["type": "text", "value": "2:30 PM"],
        modelOutput: ["type": "text", "value": "2:30 PM"]
    ))
    let result = try convert([AIMessage(role: .tool, content: [weatherToolResult(providerMetadata: cacheOptions), time])])
    #expect(result == [
        ["role": "tool", "tool_call_id": "call-1", "content": [textPart(weatherResultText, cache: ephemeral)]],
        ["role": "tool", "tool_call_id": "call-2", "content": "2:30 PM"]
    ])
}

@Test func alibabaConvertThrowsForFilePartsWithProviderReferences() throws {
    #expect(throws: AIError.invalidArgument(argument: "messages", message: "'file parts with provider references' functionality not supported.")) {
        _ = try convert([AIMessage(role: .user, content: [
            .providerReference(mimeType: "image/png", reference: ["alibaba": "file-ref-123"])
        ])])
    }
}

@Test func alibabaConvertResolvesTopLevelOnlyImageMediaTypes() throws {
    let png = try #require(Data(base64Encoded: "iVBORw0KGgo="))
    for mediaType in ["image/png", "image", "image/*"] {
        let result = try convert([AIMessage(role: .user, content: [.file(mimeType: mediaType, data: png)])])
        #expect(result.first?["content"]?[0] == ["type": "image_url", "image_url": ["url": "data:image/png;base64,iVBORw0KGgo="]])
    }
    let url = try convert([AIMessage(role: .user, content: [.imageURL("https://example.com/x.png")])])
    #expect(url.first?["content"]?[0] == ["type": "image_url", "image_url": ["url": "https://example.com/x.png"]])
}

// MARK: - get-cache-control.test.ts

@Test func alibabaCacheControlValidatorExtractsAndWarnsAfterFourBreakpoints() {
    var validator = AlibabaCacheControlValidator()
    #expect(validator.cacheControl(from: cacheOptions) == ephemeral)
    #expect(validator.cacheControl(from: ["alibaba": [:]]) == nil)
    for _ in 0..<3 { _ = validator.cacheControl(from: cacheOptions) }
    #expect(validator.warnings.isEmpty)
    #expect(validator.cacheControl(from: cacheOptions) == ephemeral)
    #expect(validator.warnings == [
        AIWarning(type: "other", message: "Max breakpoint limit exceeded. Only the last 4 cache markers will take effect.")
    ])
}

// MARK: - alibaba-prepare-tools.test.ts

@Test func alibabaPrepareToolsMapsFunctionToolsAndStrictMode() {
    let prepared = alibabaTools(from: [
        "testFunction": [
            "type": "object",
            "properties": ["value": ["type": "string"]],
            "description": "A test function",
            "strict": true
        ],
        "looseFunction": [
            "type": "object",
            "properties": [:],
            "strict": false
        ],
        "plainFunction": [
            "type": "object",
            "properties": [:]
        ]
    ])
    #expect(prepared.warnings.isEmpty)
    #expect(prepared.tools == [
        ["type": "function", "function": ["name": "looseFunction", "parameters": ["type": "object", "properties": [:]], "strict": false]],
        ["type": "function", "function": ["name": "plainFunction", "parameters": ["type": "object", "properties": [:]]]],
        ["type": "function", "function": [
            "name": "testFunction",
            "description": "A test function",
            "parameters": ["type": "object", "properties": ["value": ["type": "string"]]],
            "strict": true
        ]]
    ])
}

@Test func alibabaPrepareToolsWarnsForProviderDefinedTools() {
    let prepared = alibabaTools(from: ["web_search": ["type": "provider", "id": "openai.web_search_preview", "args": [:]]])
    #expect(prepared.tools.isEmpty)
    #expect(prepared.warnings == [AIWarning(type: "unsupported", feature: "provider-defined tool openai.web_search_preview")])
}

@Test func alibabaPrepareToolChoiceMapsKnownTypesAndThrowsForUnknown() throws {
    #expect(try alibabaToolChoice(from: "auto") == "auto")
    #expect(try alibabaToolChoice(from: ["type": "required"]) == "required")
    #expect(try alibabaToolChoice(from: "none") == "none")
    #expect(try alibabaToolChoice(from: ["type": "tool", "toolName": "testFunction"]) == ["type": "function", "function": ["name": "testFunction"]])
    #expect(throws: AIError.invalidArgument(argument: "toolChoice", message: "'tool choice type: unsupported' functionality not supported.")) {
        _ = try alibabaToolChoice(from: ["type": "unsupported"])
    }
}

@Test func alibabaOmitsToolsAndToolChoiceWhenToolsAreEmpty() async throws {
    let transport = RecordingTransport(response: jsonResponse(alibabaTextFixture))
    let model = try alibabaTestProvider(transport).languageModel("qwen-plus")
    _ = try await model.generate(LanguageModelRequest(messages: [.user("Hello")], toolChoice: "auto"))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["tools"] == nil)
    #expect(body["tool_choice"] == nil)
}

// MARK: - alibaba-chat-language-model.test.ts

private let alibabaTextFixture = #"{"choices":[{"message":{"content":"Hello there","role":"assistant"},"finish_reason":"stop","index":0,"logprobs":null}],"object":"chat.completion","usage":{"prompt_tokens":18,"completion_tokens":1064,"total_tokens":1082,"prompt_tokens_details":{"cached_tokens":0}},"created":1770764844,"system_fingerprint":null,"model":"qwen3-max","id":"chatcmpl-2655c1fe-749c-96df-b204-e413daa7caee"}"#

private func alibabaTestProvider(_ transport: RecordingTransport, includeUsage: Bool = true) throws -> AlibabaProvider {
    try AIProviders.alibaba(configuration: AlibabaProviderSettings(apiKey: "test-api-key", transport: transport, includeUsage: includeUsage))
}

@Test func alibabaSendsUpstreamRequestBodyForTextPrompt() async throws {
    let transport = RecordingTransport(response: jsonResponse(alibabaTextFixture))
    let model = try alibabaTestProvider(transport).languageModel("qwen-plus")
    let result = try await model.generate(LanguageModelRequest(messages: [.user("Hello")]))

    let request = try #require(await transport.requests().first)
    #expect(request.url.absoluteString == "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions")
    #expect(try decodeJSONBody(try #require(request.body)) == [
        "model": "qwen-plus",
        "messages": [["role": "user", "content": [textPart("Hello")]]]
    ])
    #expect(result.text == "Hello there")
    #expect(result.finishReason == "stop")
    #expect(result.responseMetadata.id == "chatcmpl-2655c1fe-749c-96df-b204-e413daa7caee")
    #expect(result.responseMetadata.modelID == "qwen3-max")
    #expect(result.responseMetadata.timestamp == Date(timeIntervalSince1970: 1770764844))
}

@Test func alibabaExtractsToolCallContent() async throws {
    let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"","role":"assistant","tool_calls":[{"function":{"arguments":"{\"location\": \"San Francisco\"}","name":"weather"},"id":"call_962bfd2ab8f54b89a1161356","index":0,"type":"function"}]},"finish_reason":"tool_calls","index":0,"logprobs":null}],"object":"chat.completion","usage":{"prompt_tokens":295,"completion_tokens":22,"total_tokens":317,"prompt_tokens_details":{"cached_tokens":0}},"created":1770764857,"system_fingerprint":null,"model":"qwen3-max","id":"chatcmpl-bc7fc58d-c03f-9c9f-af73-91bea326c99f"}"#))
    let result = try await alibabaTestProvider(transport).languageModel("qwen-plus").generate(LanguageModelRequest(messages: [.user("Hello")]))
    #expect(result.toolCalls.map(\.id) == ["call_962bfd2ab8f54b89a1161356"])
    #expect(result.toolCalls.first?.name == "weather")
    #expect(result.toolCalls.first?.arguments == #"{"location": "San Francisco"}"#)
    #expect(result.finishReason == "tool-calls")
    #expect(result.usage == TokenUsage(
        inputTokens: 295, outputTokens: 22, totalTokens: 317,
        inputTokensNoCache: 295, inputTokensCacheRead: 0, inputTokensCacheWrite: 0,
        outputTextTokens: 22, outputReasoningTokens: 0,
        rawValue: ["prompt_tokens": 295, "completion_tokens": 22, "total_tokens": 317, "prompt_tokens_details": ["cached_tokens": 0]]
    ))
}

@Test func alibabaExtractsUsageWithReasoningTokens() async throws {
    let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"3","reasoning_content":"count","role":"assistant"},"finish_reason":"stop","index":0}],"usage":{"prompt_tokens":24,"completion_tokens":1668,"total_tokens":1692,"completion_tokens_details":{"reasoning_tokens":1353},"prompt_tokens_details":{"cached_tokens":0}},"created":1770764942,"model":"qwen3-max","id":"chatcmpl-reasoning"}"#))
    let result = try await alibabaTestProvider(transport).languageModel("qwen-plus").generate(LanguageModelRequest(messages: [.user("Hello")]))
    #expect(result.reasoning == "count")
    #expect(result.usage?.inputTokens == 24)
    #expect(result.usage?.inputTokensNoCache == 24)
    #expect(result.usage?.inputTokensCacheRead == 0)
    #expect(result.usage?.inputTokensCacheWrite == 0)
    #expect(result.usage?.outputTokens == 1668)
    #expect(result.usage?.outputTextTokens == 315)
    #expect(result.usage?.outputReasoningTokens == 1353)
}

@Test func alibabaPreservesUnmappedUsageFieldsThroughRaw() async throws {
    let transport = RecordingTransport(response: jsonResponse(#"{"id":"chatcmpl-cache-type-test","object":"chat.completion","created":1770764844,"model":"qwen-plus","choices":[{"index":0,"message":{"role":"assistant","content":"Hello"},"finish_reason":"stop"}],"usage":{"prompt_tokens":100,"completion_tokens":50,"total_tokens":150,"prompt_tokens_details":{"cached_tokens":80,"cache_creation_input_tokens":0,"cache_type":"ephemeral"},"completion_tokens_details":{"reasoning_tokens":10}}}"#))
    let result = try await alibabaTestProvider(transport).languageModel("qwen-plus").generate(LanguageModelRequest(messages: [.user("Hello")]))
    #expect(result.usage?.rawValue?["prompt_tokens_details"]?["cache_type"]?.stringValue == "ephemeral")
}

@Test func alibabaOmitsReasoningOnlyResponseFromFollowUpRequest() async throws {
    let transport = RecordingTransport(response: jsonResponse(#"{"id":"reasoning-only-response","choices":[{"index":0,"message":{"role":"assistant","content":null,"reasoning_content":"Hidden reasoning."},"finish_reason":"length"}]}"#))
    let model = try alibabaTestProvider(transport).languageModel("qwen-plus")

    // Upstream returns the reasoning part instead of failing on null content.
    let first = try await model.generate(LanguageModelRequest(messages: [.user("Think before answering.")]))
    #expect(first.reasoning == "Hidden reasoning.")
    #expect(first.text == "")
    #expect(first.finishReason == "length")
    #expect(first.usage == TokenUsage())

    _ = try await model.generate(LanguageModelRequest(messages: [
        .user("Think before answering."),
        AIMessage(role: .assistant, content: [.reasoning("Hidden reasoning.")]),
        .user("Continue.")
    ]))
    let body = try decodeJSONBody(try #require(await transport.requests()[1].body))
    #expect(body["messages"] == [
        ["role": "user", "content": [textPart("Think before answering.")]],
        ["role": "user", "content": [textPart("Continue.")]]
    ])
}

@Test func alibabaUsesJSONSchemaModeOnlyForSupportedModels() async throws {
    let schema: JSONValue = ["type": "object", "properties": ["city": ["type": "string"]], "required": ["city"], "additionalProperties": false]
    let transport = RecordingTransport(response: jsonResponse(alibabaTextFixture))
    let provider = try alibabaTestProvider(transport)

    let supported = try await provider.languageModel("qwen3.8-flash").generate(LanguageModelRequest(
        messages: [.user("Hello")],
        responseFormat: .json(schema: schema)
    ))
    var body = try decodeJSONBody(try #require(await transport.requests()[0].body))
    #expect(body["response_format"] == ["type": "json_schema", "json_schema": ["name": "response", "schema": schema]])
    #expect(body["messages"] == [["role": "user", "content": [textPart("Hello")]]])
    #expect(supported.warnings.isEmpty)

    let fallback = try await provider.languageModel("deepseek-v4.1-flash").generate(LanguageModelRequest(
        messages: [.user("Hello")],
        responseFormat: .json(schema: schema)
    ))
    body = try decodeJSONBody(try #require(await transport.requests()[1].body))
    #expect(body["response_format"] == ["type": "json_object"])
    let system = try #require(body["messages"]?[0]?["content"]?.stringValue)
    #expect(body["messages"]?[0]?["role"] == "system")
    #expect(system.hasPrefix("JSON schema:\n"))
    #expect(system.hasSuffix("\nYou MUST answer with a JSON object that matches the JSON schema above."))
    #expect(fallback.warnings == [AIWarning(
        type: "compatibility",
        feature: "responseFormat JSON schema",
        message: "Alibaba does not support JSON Schema output for model deepseek-v4.1-flash. JSON Object mode is used instead. The schema was injected into the system message and will only be validated locally."
    )])

    let schemaless = try await provider.languageModel("qwen-plus").generate(LanguageModelRequest(
        messages: [.user("Hello")],
        responseFormat: .json(schema: nil)
    ))
    body = try decodeJSONBody(try #require(await transport.requests()[2].body))
    #expect(body["response_format"] == ["type": "json_object"])
    #expect(body["messages"]?[0] == ["role": "system", "content": "You MUST answer with JSON."])
    #expect(schemaless.warnings.isEmpty)
}

@Test func alibabaMapsTopLevelReasoningLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(alibabaTextFixture))
    let model = try alibabaTestProvider(transport).languageModel("qwen-plus")

    _ = try await model.generate(LanguageModelRequest(messages: [.user("Hello")], reasoning: "high"))
    _ = try await model.generate(LanguageModelRequest(messages: [.user("Hello")], reasoning: "none"))
    _ = try await model.generate(LanguageModelRequest(messages: [.user("Hello")], reasoning: "none", providerOptions: ["alibaba": ["enableThinking": true]]))
    _ = try await model.generate(LanguageModelRequest(messages: [.user("Hello")]))
    _ = try await model.generate(LanguageModelRequest(messages: [.user("Hello")], reasoning: "high", providerOptions: ["alibaba": ["preserveThinking": true]]))

    let bodies = try await transport.requests().map { try decodeJSONBody(try #require($0.body)) }
    #expect(bodies[0]["enable_thinking"] == true)
    #expect(bodies[0]["thinking_budget"]?.intValue == 9830)
    #expect(bodies[1]["enable_thinking"] == false)
    #expect(bodies[1]["thinking_budget"] == nil)
    #expect(bodies[2]["enable_thinking"] == true)
    #expect(bodies[3]["enable_thinking"] == nil)
    #expect(bodies[3]["thinking_budget"] == nil)
    #expect(bodies[3]["preserve_thinking"] == nil)
    #expect(bodies[4]["enable_thinking"] == true)
    #expect(bodies[4]["preserve_thinking"] == true)
}

@Test func alibabaPreserveThinkingDefaultsAndOptOutLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(alibabaTextFixture))
    let provider = try alibabaTestProvider(transport)
    let prompt: [AIMessage] = [
        .user("Think before answering."),
        AIMessage(role: .assistant, content: [.reasoning("Hidden reasoning."), .text("Visible answer.")]),
        .user("Continue.")
    ]

    _ = try await provider.languageModel("qwen3.7-max").generate(LanguageModelRequest(messages: prompt))
    _ = try await provider.languageModel("qwen3.7-max").generate(LanguageModelRequest(messages: prompt, providerOptions: ["alibaba": ["preserveThinking": false]]))
    _ = try await provider.languageModel("qwen-plus").generate(LanguageModelRequest(messages: prompt, providerOptions: ["alibaba": ["preserveThinking": true]]))

    let bodies = try await transport.requests().map { try decodeJSONBody(try #require($0.body)) }
    let preserved: JSONValue = ["role": "assistant", "content": "Visible answer.", "reasoning_content": "Hidden reasoning."]
    #expect(bodies[0]["preserve_thinking"] == true)
    #expect(bodies[0]["messages"]?[1] == preserved)
    #expect(bodies[1]["preserve_thinking"] == false)
    #expect(bodies[1]["messages"]?[1] == ["role": "assistant", "content": "Visible answer."])
    #expect(bodies[2]["preserve_thinking"] == true)
    #expect(bodies[2]["messages"]?[1] == preserved)
}

@Test func alibabaKeepsSameRoundReasoningWithToolCalls() async throws {
    let transport = RecordingTransport(response: jsonResponse(alibabaTextFixture))
    _ = try await alibabaTestProvider(transport).languageModel("qwen-plus").generate(LanguageModelRequest(
        messages: [
            .user("Weather in San Francisco?"),
            AIMessage(role: .assistant, content: [
                .reasoning("Need to check the weather."),
                .toolCall(AIToolCall(id: "call-1", name: "get_weather", arguments: #"{"location":"San Francisco"}"#))
            ]),
            AIMessage(role: .tool, content: [.toolResult(AIToolResult(
                toolCallID: "call-1",
                toolName: "get_weather",
                result: ["type": "text", "value": "Sunny, 72F."],
                modelOutput: ["type": "text", "value": "Sunny, 72F."]
            ))])
        ],
        providerOptions: ["alibaba": ["preserveThinking": false]]
    ))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["messages"]?.arrayValue?.contains([
        "role": "assistant",
        "content": .null,
        "reasoning_content": "Need to check the weather.",
        "tool_calls": [[
            "id": "call-1",
            "type": "function",
            "function": ["name": "get_weather", "arguments": #"{"location":"San Francisco"}"#]
        ]]
    ]) == true)
}

@Test func alibabaSendsCacheBreakpointWarningsBeforeToolWarnings() async throws {
    let transport = RecordingTransport(response: jsonResponse(alibabaTextFixture))
    let messages = (0..<5).map { AIMessage(role: .user, content: [.text("m\($0)")], providerMetadata: cacheOptions) }
    let result = try await alibabaTestProvider(transport).languageModel("qwen-plus").generate(LanguageModelRequest(
        messages: messages,
        frequencyPenalty: 0.1,
        tools: ["search": ["type": "provider", "id": "alibaba.search"]]
    ))
    #expect(result.warnings == [
        AIWarning(type: "unsupported", feature: "frequencyPenalty"),
        AIWarning(type: "other", message: "Max breakpoint limit exceeded. Only the last 4 cache markers will take effect."),
        AIWarning(type: "unsupported", feature: "provider-defined tool alibaba.search")
    ])
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["messages"]?[4]?["content"]?[0]?["cache_control"] == ephemeral)
}

private func collect(_ stream: AsyncThrowingStream<LanguageStreamPart, Error>) async throws -> [LanguageStreamPart] {
    var parts: [LanguageStreamPart] = []
    for try await part in stream { parts.append(part) }
    return parts
}

@Test func alibabaStreamEndingsMapFinishReasonsLikeUpstream() async throws {
    let first = #"data: {"id":"response-1","object":"chat.completion.chunk","created":1,"model":"test-model","choices":[{"index":0,"delta":{"content":"Partial answer"},"finish_reason":null}]}"# + "\n\n"
    let cases: [(String, String, Int)] = [
        ("", "interrupted", 0),
        (#"data: {"choices":[{"index":0,"delta":{},"finish_reason":"unknown_reason"}]}"# + "\n\n", "other", 0),
        ("data: {invalid-json}\n\n", "error", 1)
    ]
    for (ending, unified, errorCount) in cases {
        let transport = RecordingTransport(response: sseResponse(first + ending))
        let parts = try await collect(try alibabaTestProvider(transport).languageModel("qwen-plus").stream(LanguageModelRequest(messages: [.user("Hello")])))
        #expect(parts.contains { if case let .textDeltaPart(_, delta, _) = $0 { delta == "Partial answer" } else { false } })
        #expect(parts.filter { if case .error = $0 { true } else { false } }.count == errorCount)
        let finishes = parts.compactMap { part -> String? in
            if case let .finishMetadata(reason, _, _) = part { return reason ?? "nil" }
            return nil
        }
        #expect(finishes == [unified])
    }
}

@Test func alibabaStreamsToolCallFixtureLikeUpstreamSnapshot() async throws {
    let chunks = [
        #"{"choices":[{"delta":{"content":null,"tool_calls":[{"index":0,"id":"call_eee11723464a4b9eb8cee71d","type":"function","function":{"name":"weather","arguments":""}}],"role":"assistant"},"finish_reason":null,"index":0,"logprobs":null}],"object":"chat.completion.chunk","usage":null,"created":1770764938,"system_fingerprint":null,"model":"qwen3-max","id":"chatcmpl-8e243c57-23b3-9db2-a02e-e3c53929c368"}"#,
        #"{"choices":[{"delta":{"content":null,"tool_calls":[{"index":0,"id":"","type":"function","function":{"arguments":"{\"location\": \"San Francisco"}}]},"finish_reason":null,"index":0,"logprobs":null}],"object":"chat.completion.chunk","usage":null,"created":1770764938,"system_fingerprint":null,"model":"qwen3-max","id":"chatcmpl-8e243c57-23b3-9db2-a02e-e3c53929c368"}"#,
        #"{"choices":[{"delta":{"content":null,"tool_calls":[{"index":0,"id":"","type":"function","function":{"arguments":"\"}"}}]},"finish_reason":null,"index":0,"logprobs":null}],"object":"chat.completion.chunk","usage":null,"created":1770764938,"system_fingerprint":null,"model":"qwen3-max","id":"chatcmpl-8e243c57-23b3-9db2-a02e-e3c53929c368"}"#,
        #"{"choices":[{"delta":{"tool_calls":[{"function":{"arguments":""},"index":0,"id":"","type":"function"}]},"index":0}],"object":"chat.completion.chunk","usage":null,"created":1770764938,"system_fingerprint":null,"model":"qwen3-max","id":"chatcmpl-8e243c57-23b3-9db2-a02e-e3c53929c368"}"#,
        #"{"choices":[{"finish_reason":"tool_calls","delta":{},"index":0,"logprobs":null}],"object":"chat.completion.chunk","usage":null,"created":1770764938,"system_fingerprint":null,"model":"qwen3-max","id":"chatcmpl-8e243c57-23b3-9db2-a02e-e3c53929c368"}"#,
        #"{"choices":[],"object":"chat.completion.chunk","usage":{"prompt_tokens":295,"completion_tokens":22,"total_tokens":317,"prompt_tokens_details":{"cached_tokens":0}},"created":1770764938,"system_fingerprint":null,"model":"qwen3-max","id":"chatcmpl-8e243c57-23b3-9db2-a02e-e3c53929c368"}"#
    ]
    let transport = RecordingTransport(response: sseResponse(chunks.map { "data: \($0)\n\n" }.joined() + "data: [DONE]\n\n"))
    let parts = try await collect(try alibabaTestProvider(transport).languageModel("qwen-plus").stream(LanguageModelRequest(messages: [.user("Hello")])))

    var events: [String] = []
    for part in parts {
        switch part {
        case let .streamStart(warnings): events.append("stream-start:\(warnings.count)")
        case let .responseMetadata(metadata): events.append("response-metadata:\(metadata.id ?? ""):\(metadata.modelID ?? ""):\(Int(metadata.timestamp?.timeIntervalSince1970 ?? 0))")
        case let .toolInputStart(id, name, _, _, _, _): events.append("tool-input-start:\(id):\(name)")
        case let .toolInputDelta(id, delta, _): events.append("tool-input-delta:\(id):\(delta)")
        case let .toolInputEnd(id, _): events.append("tool-input-end:\(id)")
        case let .toolCall(call): events.append("tool-call:\(call.id):\(call.name):\(call.arguments)")
        case let .finishMetadata(reason, usage, _): events.append("finish:\(reason ?? ""):\(usage?.inputTokensNoCache ?? -1):\(usage?.outputTextTokens ?? -1)")
        default: events.append("other")
        }
    }
    #expect(events == [
        "stream-start:0",
        "response-metadata:chatcmpl-8e243c57-23b3-9db2-a02e-e3c53929c368:qwen3-max:1770764938",
        "tool-input-start:call_eee11723464a4b9eb8cee71d:weather",
        #"tool-input-delta:call_eee11723464a4b9eb8cee71d:{"location": "San Francisco"#,
        #"tool-input-delta:call_eee11723464a4b9eb8cee71d:"}"#,
        "tool-input-delta:call_eee11723464a4b9eb8cee71d:",
        "tool-input-end:call_eee11723464a4b9eb8cee71d",
        #"tool-call:call_eee11723464a4b9eb8cee71d:weather:{"location": "San Francisco"}"#,
        "finish:tool-calls:295:22"
    ])
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["stream"] == true)
    #expect(body["stream_options"] == ["include_usage": true])
}

@Test func alibabaStreamKeepsReasoningActiveWhenDeltasIncludeEmptyToolCalls() async throws {
    let transport = RecordingTransport(response: sseResponse(#"""
    data: {"id":"chatcmpl-test","object":"chat.completion.chunk","created":1,"model":"test-model","choices":[{"index":0,"delta":{"role":"assistant","content":"","reasoning_content":"Think ","tool_calls":[]},"finish_reason":null}]}

    data: {"id":"chatcmpl-test","object":"chat.completion.chunk","created":1,"model":"test-model","choices":[{"index":0,"delta":{"content":"","reasoning_content":"more...","tool_calls":[]},"finish_reason":null}]}

    data: {"id":"chatcmpl-test","object":"chat.completion.chunk","created":1,"model":"test-model","choices":[{"index":0,"delta":{"content":"Hello","reasoning_content":"","tool_calls":[]},"finish_reason":"stop"}]}

    data: [DONE]

    """#))
    let parts = try await collect(try alibabaTestProvider(transport).languageModel("qwen-plus").stream(LanguageModelRequest(messages: [.user("Hello")])))
    let reasoning = parts.compactMap { part -> String? in
        switch part {
        case let .reasoningStart(id, _): return "start:\(id)"
        case let .reasoningDeltaPart(id, delta, _): return "delta:\(id):\(delta)"
        case let .reasoningEnd(id, _): return "end:\(id)"
        default: return nil
        }
    }
    let id = try #require(reasoning.first?.dropFirst("start:".count))
    #expect(reasoning == ["start:\(id)", "delta:\(id):Think ", "delta:\(id):more...", "end:\(id)"])
}

@Test func alibabaStreamGeneratesDistinctReasoningIDsPerBlock() async throws {
    let transport = RecordingTransport(response: sseResponse(#"""
    data: {"choices":[{"index":0,"delta":{"reasoning_content":"a"},"finish_reason":null}]}

    data: {"choices":[{"index":0,"delta":{"content":"b"},"finish_reason":null}]}

    data: {"choices":[{"index":0,"delta":{"reasoning_content":"c"},"finish_reason":"stop"}]}

    """#))
    let parts = try await collect(try alibabaTestProvider(transport).languageModel("qwen-plus").stream(LanguageModelRequest(messages: [.user("Hello")])))
    let starts = parts.compactMap { part -> String? in
        if case let .reasoningStart(id, _) = part { return id }
        return nil
    }
    #expect(starts.count == 2)
    #expect(Set(starts).count == 2)
}

@Test func alibabaStreamOmitsStreamOptionsWhenIncludeUsageIsDisabled() async throws {
    let transport = RecordingTransport(response: sseResponse("data: [DONE]\n\n"))
    _ = try await collect(try alibabaTestProvider(transport, includeUsage: false).languageModel("qwen-plus").stream(LanguageModelRequest(messages: [.user("Hello")])))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["stream"] == true)
    #expect(body["stream_options"] == nil)
}

@Test func alibabaToolParametersExcludeSwiftToolMetadata() async throws {
    let transport = RecordingTransport(response: jsonResponse(alibabaTextFixture))
    let tool = AITool(name: "weather", description: "Get weather", parameters: ["type": "object", "properties": ["city": ["type": "string"]]], providerOptions: ["alibaba": ["x": true]], strict: false, inputExamples: [["city": "Paris"]]) { _ in .null }
    _ = try await alibabaTestProvider(transport).languageModel("qwen-plus").generate(LanguageModelRequest(
        messages: [.user("Hello")],
        tools: ["weather": tool.schema]
    ))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["tools"] == [[
        "type": "function",
        "function": [
            "name": "weather",
            "description": "Get weather",
            "parameters": ["type": "object", "properties": ["city": ["type": "string"]]],
            "strict": false
        ]
    ]])
}

// MARK: - alibaba-provider.test.ts

@Test func alibabaProviderUsesUpstreamDefaultAndCustomNativeBaseURLs() async throws {
    let embeddingResponse = jsonResponse(#"{"output":{"embeddings":[{"embedding":[0.1],"text_index":0}]},"usage":{"total_tokens":1},"request_id":"req"}"#)
    let defaultTransport = RecordingTransport(response: embeddingResponse)
    _ = try await AIProviders.alibaba(configuration: AlibabaProviderSettings(apiKey: "k", baseURL: "https://proxy.example.com/v1", transport: defaultTransport))
        .embeddingModel("text-embedding-v4").embed(EmbeddingRequest(values: ["a"]))
    #expect(await defaultTransport.requests().first?.url.absoluteString == "https://dashscope-intl.aliyuncs.com/api/v1/services/embeddings/text-embedding/text-embedding")

    let customTransport = RecordingTransport(response: embeddingResponse)
    _ = try await AIProviders.alibaba(configuration: AlibabaProviderSettings(apiKey: "k", transport: customTransport, embeddingBaseURL: "https://dashscope.aliyuncs.com/api/v1/"))
        .embeddingModel("text-embedding-v4").embed(EmbeddingRequest(values: ["a"]))
    #expect(await customTransport.requests().first?.url.absoluteString == "https://dashscope.aliyuncs.com/api/v1/services/embeddings/text-embedding/text-embedding")

    let videoResponses = [
        jsonResponse(#"{"output":{"task_status":"PENDING","task_id":"task-1"}}"#),
        jsonResponse(#"{"output":{"task_id":"task-1","task_status":"SUCCEEDED","video_url":"https://example.com/v.mp4"}}"#)
    ]
    let videoTransport = RecordingTransport(responses: videoResponses)
    _ = try await AIProviders.alibaba(configuration: AlibabaProviderSettings(apiKey: "k", transport: videoTransport, videoBaseURL: "https://dashscope.aliyuncs.com"))
        .videoModel("wan2.6-t2v").generateVideo(VideoGenerationRequest(prompt: "p", providerOptions: ["alibaba": ["pollIntervalMs": 1]]))
    let videoRequests = await videoTransport.requests()
    #expect(videoRequests.map(\.url.absoluteString) == [
        "https://dashscope.aliyuncs.com/api/v1/services/aigc/video-generation/video-synthesis",
        "https://dashscope.aliyuncs.com/api/v1/tasks/task-1"
    ])
}

// MARK: - convert-alibaba-usage.test.ts

@Test func alibabaUsageDistributesCacheTokens() {
    let usage = alibabaUsage(from: ["usage": [
        "prompt_tokens": 100,
        "completion_tokens": 50,
        "total_tokens": 150,
        "prompt_tokens_details": ["cached_tokens": 80, "cache_creation_input_tokens": 20],
        "completion_tokens_details": ["reasoning_tokens": 10]
    ]])
    #expect(usage?.inputTokensNoCache == 0)
    #expect(usage?.inputTokensCacheRead == 80)
    #expect(usage?.inputTokensCacheWrite == 20)
    #expect(usage?.outputTextTokens == 40)
    #expect(usage?.outputReasoningTokens == 10)
    #expect(alibabaUsage(from: ["usage": .null]) == nil)
    #expect(alibabaUsage(from: [:]) == nil)
}

// MARK: - alibaba-video-model.test.ts

private func videoTransport(status: String = #"{"output":{"task_id":"task-abc-123","task_status":"SUCCEEDED","video_url":"https://dashscope-result.oss.aliyuncs.com/output/video-001.mp4","actual_prompt":"An enhanced prompt with more cinematic details"},"usage":{"duration":5.0,"output_video_duration":5,"SR":1080,"size":"1920x1080"},"request_id":"req-002"}"#) -> RecordingTransport {
    RecordingTransport(responses: [
        jsonResponse(#"{"output":{"task_status":"PENDING","task_id":"task-abc-123"},"request_id":"req-001"}"#),
        jsonResponse(status)
    ])
}

private let fastPoll: [String: JSONValue] = ["alibaba": ["pollIntervalMs": 1, "pollTimeoutMs": 1_000]]

@Test func alibabaVideoWarnsOnResolutionOutsideWan3TiersInUpstreamOrder() async throws {
    let transport = videoTransport()
    let result = try await AIProviders.alibaba(configuration: AlibabaProviderSettings(apiKey: "k", transport: transport))
        .videoModel("wan3.0-video")
        .generateVideo(VideoGenerationRequest(prompt: "p", resolution: "640x360", fps: 24, count: 2, providerOptions: fastPoll))
    #expect(result.warnings == [
        AIWarning(type: "unsupported", feature: "resolution", message: "wan3 models only support the 480P, 720P, 1080P resolution tiers. The resolution \"640x360\" was ignored."),
        AIWarning(type: "unsupported", feature: "fps", message: "Alibaba video models do not support custom FPS."),
        AIWarning(type: "unsupported", feature: "n", message: "Alibaba video models only support generating 1 video per call.")
    ])
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["parameters"]?["resolution"] == nil)
}

@Test func alibabaVideoWarningsFollowUpstreamBuildOrder() async throws {
    let transport = videoTransport()
    let result = try await AIProviders.alibaba(configuration: AlibabaProviderSettings(apiKey: "k", transport: transport))
        .videoModel("wan2.6-t2v")
        .generateVideo(VideoGenerationRequest(
            prompt: "p",
            aspectRatio: "16:9",
            frameImages: [VideoFrameImage(image: ImageInputFile(url: "https://example.com/last.png"), frameType: .lastFrame)],
            inputReferences: [ImageInputFile(url: "https://example.com/ref.png")],
            providerOptions: fastPoll
        ))
    #expect(result.warnings.map(\.feature) == ["frameImages", "inputReferences", "aspectRatio"])
}

@Test func alibabaVideoWarnsForWan27AudioProviderOption() async throws {
    let transport = videoTransport()
    let result = try await AIProviders.alibaba(configuration: AlibabaProviderSettings(apiKey: "k", transport: transport))
        .videoModel("wan2.7-t2v")
        .generateVideo(VideoGenerationRequest(prompt: "p", providerOptions: ["alibaba": ["audio": false, "pollIntervalMs": 1]]))
    #expect(result.warnings == [AIWarning(type: "unsupported", feature: "generateAudio", message: "wan2.7 models always generate audio. The audio option was ignored.")])
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["parameters"]?["audio"] == nil)
}

@Test func alibabaVideoWarnsPerSkippedReferenceAndDetectsVideoURLsByExtension() async throws {
    let transport = videoTransport()
    let result = try await AIProviders.alibaba(configuration: AlibabaProviderSettings(apiKey: "k", transport: transport))
        .videoModel("wan3.0-video")
        .generateVideo(VideoGenerationRequest(
            prompt: "p",
            inputReferences: [
                ImageInputFile(url: "https://example.com/clip.MP4?sig=1"),
                ImageInputFile(url: "https://cdn.mp4host.example.com/still.png"),
                ImageInputFile(data: Data([1]), mediaType: "video/mp4"),
                ImageInputFile(data: Data([2]), mediaType: "video/mp4")
            ],
            providerOptions: fastPoll
        ))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["input"]?["media"] == [
        ["type": "reference_video", "url": "https://example.com/clip.MP4?sig=1"],
        ["type": "reference_image", "url": "https://cdn.mp4host.example.com/still.png"]
    ])
    let skipped = AIWarning(type: "unsupported", feature: "inputReferences", message: "Alibaba reference-to-video requires URL references for videos. Non-URL video reference was skipped.")
    #expect(result.warnings == [skipped, skipped])
}

@Test func alibabaVideoReportsFailedTaskWithUpstreamMessage() async throws {
    let transport = videoTransport(status: #"{"output":{"task_id":"task-abc-123","task_status":"FAILED","message":"Content policy violation"},"request_id":"req-failed"}"#)
    await #expect(throws: AIError.invalidResponse(provider: "alibaba.video", message: "Video generation failed. Task ID: task-abc-123. Content policy violation")) {
        _ = try await AIProviders.alibaba(configuration: AlibabaProviderSettings(apiKey: "k", transport: transport))
            .videoModel("wan2.6-t2v")
            .generateVideo(VideoGenerationRequest(prompt: "p", providerOptions: fastPoll))
    }
}

@Test func alibabaVideoThrowsWhenNoTaskIDReturned() async throws {
    let transport = RecordingTransport(response: jsonResponse(#"{"output":null,"request_id":"req-003"}"#))
    do {
        _ = try await AIProviders.alibaba(configuration: AlibabaProviderSettings(apiKey: "k", transport: transport))
            .videoModel("wan2.6-t2v")
            .generateVideo(VideoGenerationRequest(prompt: "p", providerOptions: fastPoll))
        Issue.record("Expected an error")
    } catch let AIError.invalidResponse(_, message) {
        #expect(message.hasPrefix("No task_id returned from Alibaba API. Response: "))
    }
}

@Test func alibabaVideoIncludesProviderMetadataInCompletedResult() async throws {
    let result = try await AIProviders.alibaba(configuration: AlibabaProviderSettings(apiKey: "k", transport: videoTransport()))
        .videoModel("wan2.6-t2v")
        .generateVideo(VideoGenerationRequest(prompt: "p", providerOptions: fastPoll))
    #expect(result.providerMetadata["alibaba"] == [
        "taskId": "task-abc-123",
        "videoUrl": "https://dashscope-result.oss.aliyuncs.com/output/video-001.mp4",
        "actualPrompt": "An enhanced prompt with more cinematic details",
        "usage": ["duration": 5.0, "outputVideoDuration": 5, "resolution": 1080, "size": "1920x1080"]
    ])
}

@Test func alibabaVideoMediaOverrideMapsOnlyUpstreamFields() async throws {
    let transport = videoTransport()
    _ = try await AIProviders.alibaba(configuration: AlibabaProviderSettings(apiKey: "k", transport: transport))
        .videoModel("wan3.0-video")
        .generateVideo(VideoGenerationRequest(prompt: "p", providerOptions: ["alibaba": [
            "media": [
                ["type": "reference_audio", "url": "https://example.com/a.wav", "referenceVoice": "narrator", "extra": 1],
                ["type": "reference_image", "url": "https://example.com/i.png", "referenceVoice": .null]
            ],
            "pollIntervalMs": 1
        ]]))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["input"]?["media"] == [
        ["type": "reference_audio", "url": "https://example.com/a.wav", "reference_voice": "narrator"],
        ["type": "reference_image", "url": "https://example.com/i.png"]
    ])
}

@Test func alibabaStreamEmitsRawPartForUnparsableChunk() async throws {
    let transport = RecordingTransport(response: sseResponse("data: {invalid-json}\n\ndata: [DONE]\n\n"))
    let parts = try await collect(try alibabaTestProvider(transport).languageModel("qwen-plus").stream(LanguageModelRequest(messages: [.user("Hello")], includeRawChunks: true)))
    #expect(parts.contains { if case .raw(.null) = $0 { true } else { false } })
}

// MARK: - alibaba-embedding-model.test.ts

private func embeddingFixture(reverse: Bool = false, usage: Bool = true) -> AIHTTPResponse {
    let items = [#"{"embedding":[0.1,0.2,0.3],"text_index":0}"#, #"{"embedding":[0.4,0.5,0.6],"text_index":1}"#]
    let ordered = reverse ? items.reversed() : items
    return jsonResponse(#"{"output":{"embeddings":["# + ordered.joined(separator: ",") + "]}" + (usage ? #","usage":{"total_tokens":20}}"# : "}"))
}

@Test func alibabaEmbeddingMapsDimensionsWithProviderOverride() async throws {
    let cases: [(Int?, JSONValue?, Int?)] = [(nil, nil, nil), (256, nil, 256), (nil, 512, 512), (256, 512, 512)]
    for (dimensions, providerDimension, expected) in cases {
        let transport = RecordingTransport(response: embeddingFixture())
        var options: [String: JSONValue] = [:]
        if let providerDimension { options["alibaba"] = ["dimension": providerDimension] }
        _ = try await alibabaTestProvider(transport).embeddingModel("text-embedding-v4").embed(EmbeddingRequest(
            values: ["sunny day at the beach", "rainy day in the city"],
            dimensions: dimensions,
            providerOptions: options
        ))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["parameters"]?["dimension"]?.intValue == expected)
    }
}

@Test func alibabaEmbeddingSortsByTextIndexAndMapsUsage() async throws {
    let reversed = try await alibabaTestProvider(RecordingTransport(response: embeddingFixture(reverse: true)))
        .embeddingModel("text-embedding-v4").embed(EmbeddingRequest(values: ["a", "b"]))
    #expect(reversed.embeddings == [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]])
    #expect(reversed.usage?.totalTokens == 20)

    let withoutUsage = try await alibabaTestProvider(RecordingTransport(response: embeddingFixture(usage: false)))
        .embeddingModel("text-embedding-v4").embed(EmbeddingRequest(values: ["a", "b"]))
    #expect(withoutUsage.usage == nil)
}
