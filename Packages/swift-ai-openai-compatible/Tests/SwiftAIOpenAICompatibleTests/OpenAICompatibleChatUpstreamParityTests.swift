import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIOpenAICompatible

/// Translations of `packages/openai-compatible/src/chat/openai-compatible-chat-language-model.test.ts`
/// and `openai-compatible-embedding-model.test.ts` scenarios (matching-release tests).
@Suite struct OpenAICompatibleChatUpstreamParityTests {
    private static let tool: JSONValue = [
        "type": "object",
        "properties": ["value": ["type": "string"]],
        "required": ["value"],
        "additionalProperties": false,
        "$schema": "http://json-schema.org/draft-07/schema#"
    ]

    private func provider(_ transport: RecordingTransport, supportsStructuredOutputs: Bool = false, includeUsage: Bool = false) -> OpenAICompatibleProvider {
        AIProviders.openAICompatible(configuration: .init(
            name: "test-provider",
            baseURL: "https://my.api.com/v1/",
            headers: ["Authorization": "Bearer test-api-key"],
            transport: transport,
            includeUsage: includeUsage,
            supportsStructuredOutputs: supportsStructuredOutputs
        ))
    }

    private func body(_ transport: RecordingTransport) async throws -> JSONValue {
        try decodeJSONBody(try #require(await transport.requests().first?.body))
    }

    private func jsonResponseBody(
        content: JSONValue = "",
        refusal: JSONValue = .null,
        toolCalls: JSONValue? = nil,
        usage: JSONValue = ["prompt_tokens": 4, "total_tokens": 34, "completion_tokens": 30],
        finishReason: String = "stop",
        created: Double = 1711115037
    ) -> AIHTTPResponse {
        var message: [String: JSONValue] = ["role": "assistant", "content": content, "refusal": refusal, "reasoning_content": "", "reasoning": ""]
        if let toolCalls { message["tool_calls"] = toolCalls }
        let body: JSONValue = [
            "id": "chatcmpl-95ZTZkhr0mHNKqerQfiwkuox3PHAd",
            "object": "chat.completion",
            "created": .number(created),
            "model": "grok-3",
            "choices": [["index": 0, "message": .object(message), "finish_reason": .string(finishReason)]],
            "usage": usage,
            "system_fingerprint": "fp_3bc1b5746c"
        ]
        return AIHTTPResponse(statusCode: 200, headers: ["content-type": "application/json"], body: try! encodeJSONBody(body))
    }

    private func chunks(_ lines: [String]) -> AIHTTPResponse {
        sseResponse(lines.map { "data: \($0)" }.joined(separator: "\n\n") + "\n\ndata: [DONE]")
    }

    private func collect(_ stream: AsyncThrowingStream<LanguageStreamPart, Error>) async throws -> [LanguageStreamPart] {
        var parts: [LanguageStreamPart] = []
        for try await part in stream { parts.append(part) }
        return parts
    }

    // MARK: doGenerate

    @Test func generateDistinctIDsForParallelToolCallsWithEmptyIDs() async throws {
        let transport = RecordingTransport(response: jsonResponseBody(
            toolCalls: [
                ["id": "", "type": "function", "function": ["name": "first", "arguments": #"{"value":1}"#]],
                ["id": "", "type": "function", "function": ["name": "second", "arguments": #"{"value":2}"#]]
            ],
            finishReason: "tool_calls"
        ))
        let result = try await provider(transport).chatModel("grok-3").generate(LanguageModelRequest(messages: [.user("Hello")]))
        let ids = result.toolCalls.map(\.id)
        #expect(ids.count == 2)
        #expect(ids.allSatisfy { !$0.isEmpty })
        #expect(Set(ids).count == 2)
    }

    @Test func supportPartialUsage() async throws {
        let transport = RecordingTransport(response: jsonResponseBody(usage: ["prompt_tokens": 20, "total_tokens": 20]))
        let result = try await provider(transport).chatModel("grok-3").generate(LanguageModelRequest(messages: [.user("Hello")]))
        let usage = try #require(result.usage)
        #expect(usage.inputTokens == 20)
        #expect(usage.inputTokensNoCache == 20)
        #expect(usage.inputTokensCacheRead == 0)
        #expect(usage.inputTokensCacheWrite == nil)
        #expect(usage.outputTokens == 0)
        #expect(usage.outputTextTokens == 0)
        #expect(usage.outputReasoningTokens == 0)
        #expect(usage.rawValue == ["prompt_tokens": 20, "total_tokens": 20])
    }

    @Test func extractDetailedTokenUsage() async throws {
        let transport = RecordingTransport(response: jsonResponseBody(usage: [
            "prompt_tokens": 20, "completion_tokens": 30, "total_tokens": 50,
            "prompt_tokens_details": ["cached_tokens": 5],
            "completion_tokens_details": ["reasoning_tokens": 10, "accepted_prediction_tokens": 15, "rejected_prediction_tokens": 5]
        ]))
        let result = try await provider(transport).chatModel("grok-3").generate(LanguageModelRequest(messages: [.user("Hello")]))
        let usage = try #require(result.usage)
        #expect(usage.inputTokens == 20)
        #expect(usage.inputTokensNoCache == 15)
        #expect(usage.inputTokensCacheRead == 5)
        #expect(usage.outputTokens == 30)
        #expect(usage.outputTextTokens == 20)
        #expect(usage.outputReasoningTokens == 10)
        #expect(result.providerMetadata == ["test-provider": ["acceptedPredictionTokens": 15, "rejectedPredictionTokens": 5]])
    }

    @Test func providerMetadataIsAlwaysKeyed() async throws {
        let transport = RecordingTransport(response: jsonResponse("""
        {"id":"x","created":1711115037,"model":"grok-3","choices":[{"message":{"role":"assistant","content":"Hi"},"finish_reason":"stop"}]}
        """))
        let result = try await provider(transport).chatModel("grok-3").generate(LanguageModelRequest(messages: [.user("Hello")]))
        #expect(result.providerMetadata == ["test-provider": [:]])
    }

    @Test func zeroCreatedTimestampIsTreatedAsMissing() async throws {
        let transport = RecordingTransport(response: jsonResponseBody(created: 0))
        let result = try await provider(transport).chatModel("grok-3").generate(LanguageModelRequest(messages: [.user("Hello")]))
        #expect(result.responseMetadata.timestamp == nil)
        #expect(result.responseMetadata.id == "chatcmpl-95ZTZkhr0mHNKqerQfiwkuox3PHAd")
    }

    @Test func passSettingsFromOpenAICompatibleAndDeprecatedKeys() async throws {
        let transport = RecordingTransport(response: jsonResponseBody())
        _ = try await provider(transport).chatModel("grok-3").generate(LanguageModelRequest(
            messages: [.user("Hello")], providerOptions: ["openaiCompatible": ["user": "test-user-id"]]
        ))
        #expect(try await body(transport) == ["messages": [["content": "Hello", "role": "user"]], "model": "grok-3", "user": "test-user-id"])

        let deprecated = RecordingTransport(response: jsonResponseBody())
        let result = try await provider(deprecated).chatModel("grok-3").generate(LanguageModelRequest(
            messages: [.user("Hello")], providerOptions: ["openai-compatible": ["user": "test-user-id"]]
        ))
        #expect(try await body(deprecated) == ["messages": [["content": "Hello", "role": "user"]], "model": "grok-3", "user": "test-user-id"])
        #expect(result.warnings == [AIWarning(type: "deprecated", setting: "providerOptions key 'openai-compatible'", message: "Use 'openaiCompatible' instead.")])
    }

    @Test func providerSpecificOptionsPassThroughUnchanged() async throws {
        let transport = RecordingTransport(response: jsonResponseBody())
        _ = try await provider(transport).chatModel("grok-3").generate(LanguageModelRequest(
            messages: [.user("Hello")], providerOptions: ["test-provider": ["someCustomOption": "test-value", "parallelToolCalls": false]]
        ))
        // Upstream spreads provider-namespace keys verbatim (no snake_case renaming).
        #expect(try await body(transport) == [
            "messages": [["content": "Hello", "role": "user"]], "model": "grok-3",
            "someCustomOption": "test-value", "parallelToolCalls": false
        ])

        let other = RecordingTransport(response: jsonResponseBody())
        _ = try await provider(other).chatModel("grok-3").generate(LanguageModelRequest(
            messages: [.user("Hello")], providerOptions: ["notThisProviderName": ["someCustomOption": "test-value"]]
        ))
        #expect(try await body(other) == ["messages": [["content": "Hello", "role": "user"]], "model": "grok-3"])

        // Only typed options are read from the openaiCompatible namespace.
        let compatible = RecordingTransport(response: jsonResponseBody())
        _ = try await provider(compatible).chatModel("grok-3").generate(LanguageModelRequest(
            messages: [.user("Hello")], providerOptions: ["openaiCompatible": ["someCustomOption": "ignored"]]
        ))
        #expect(try await body(compatible) == ["messages": [["content": "Hello", "role": "user"]], "model": "grok-3"])
    }

    @Test func preferCamelCaseOptionsOverRawNameOptionsAndKeyMetadata() async throws {
        let transport = RecordingTransport(response: jsonResponseBody(content: "Hello!"))
        let result = try await provider(transport).chatModel("grok-3").generate(LanguageModelRequest(
            messages: [.user("Hello")],
            providerOptions: ["test-provider": ["someCustomOption": "raw-value"], "testProvider": ["someCustomOption": "camel-value"]]
        ))
        #expect(try await body(transport)["someCustomOption"] == "camel-value")
        #expect(result.providerMetadata["testProvider"] == [:])
    }

    @Test func invalidTypedProviderOptionsThrow() async throws {
        let transport = RecordingTransport(response: jsonResponseBody())
        await #expect(throws: AIError.self) {
            _ = try await provider(transport).chatModel("grok-3").generate(LanguageModelRequest(
                messages: [.user("Hello")], providerOptions: ["openaiCompatible": ["user": 1]]
            ))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func passToolsAndToolChoiceWithoutToolMetadataInParameters() async throws {
        let transport = RecordingTransport(response: jsonResponseBody())
        var schema = Self.tool.objectValue!
        schema["description"] = "Test tool"
        schema["providerOptions"] = ["test-provider": ["x": 1]]
        _ = try await provider(transport).chatModel("grok-3").generate(LanguageModelRequest(
            messages: [.user("Hello")],
            tools: ["test-tool": .object(schema)],
            toolChoice: ["type": "tool", "toolName": "test-tool"]
        ))
        let sent = try await body(transport)
        #expect(sent["tools"] == [[
            "type": "function",
            "function": ["name": "test-tool", "description": "Test tool", "parameters": Self.tool]
        ]])
        #expect(sent["tool_choice"] == ["type": "function", "function": ["name": "test-tool"]])
    }

    @Test func responseFormatSchemaWarnsWithoutStructuredOutputs() async throws {
        let transport = RecordingTransport(response: jsonResponseBody(content: #"{"value":"Spark"}"#))
        let result = try await provider(transport).chatModel("gpt-4o-2024-08-06").generate(LanguageModelRequest(
            messages: [.user("Hello")], responseFormat: .json(schema: Self.tool)
        ))
        #expect(try await body(transport) == [
            "messages": [["content": "Hello", "role": "user"]], "model": "gpt-4o-2024-08-06",
            "response_format": ["type": "json_object"]
        ])
        #expect(result.warnings == [AIWarning(type: "unsupported", feature: "responseFormat", message: "JSON response format schema is only supported with structuredOutputs")])

        let structured = RecordingTransport(response: jsonResponseBody(content: #"{"value":"Spark"}"#))
        let structuredResult = try await provider(structured, supportsStructuredOutputs: true).chatModel("gpt-4o-2024-08-06").generate(LanguageModelRequest(
            messages: [.user("Hello")], responseFormat: .json(schema: Self.tool)
        ))
        #expect(try await body(structured)["response_format"] == [
            "type": "json_schema",
            "json_schema": ["name": "response", "schema": Self.tool, "strict": true]
        ])
        #expect(structuredResult.warnings.isEmpty)
    }

    @Test func reasoningEffortPrecedenceAndRawPassthrough() async throws {
        // providerOptions reasoningEffort wins over top-level reasoning.
        let explicit = RecordingTransport(response: jsonResponseBody())
        _ = try await provider(explicit).chatModel("grok-3").generate(LanguageModelRequest(
            messages: [.user("Hello")], reasoning: "high", providerOptions: ["openaiCompatible": ["reasoningEffort": "low"]]
        ))
        #expect(try await body(explicit)["reasoning_effort"] == "low")

        // reasoningEffort null is sent as null.
        let null = RecordingTransport(response: jsonResponseBody())
        _ = try await provider(null).chatModel("grok-3").generate(LanguageModelRequest(
            messages: [.user("Hello")], reasoning: "high", providerOptions: ["openaiCompatible": ["reasoningEffort": .null]]
        ))
        #expect(try await body(null)["reasoning_effort"] == .null)

        // A raw reasoning_effort provider option is kept when no typed effort is set.
        let raw = RecordingTransport(response: jsonResponseBody())
        _ = try await provider(raw).chatModel("grok-3").generate(LanguageModelRequest(
            messages: [.user("Hello")], providerOptions: ["test-provider": ["reasoning_effort": "custom"]]
        ))
        #expect(try await body(raw)["reasoning_effort"] == "custom")

        // textVerbosity wins over raw verbosity.
        let verbosity = RecordingTransport(response: jsonResponseBody())
        _ = try await provider(verbosity).chatModel("grok-3").generate(LanguageModelRequest(
            messages: [.user("Hello")], providerOptions: ["testProvider": ["verbosity": "raw", "textVerbosity": "low"]]
        ))
        let verbosityBody = try await body(verbosity)
        #expect(verbosityBody["verbosity"] == "low")
        #expect(verbosityBody["textVerbosity"] == nil)
    }

    @Test func warningOrderMatchesUpstream() async throws {
        let transport = RecordingTransport(response: jsonResponseBody())
        let result = try await provider(transport).chatModel("grok-3").generate(LanguageModelRequest(
            messages: [.user("Hello")],
            topK: 1,
            responseFormat: .json(schema: Self.tool),
            tools: ["web": ["type": "provider", "id": "test.web"]],
            providerOptions: ["openai-compatible": [:]]
        ))
        #expect(result.warnings.map { $0.setting ?? $0.feature ?? "" } == [
            "providerOptions key 'openai-compatible'", "topK", "responseFormat", "provider-defined tool test.web"
        ])
    }

    // MARK: doStream

    @Test func streamToolDeltasWhenFunctionNameArrivesInALaterChunk() async throws {
        let transport = RecordingTransport(response: chunks([
            #"{"id":"chatcmpl-late-name","object":"chat.completion.chunk","created":1711357598,"model":"grok-3","choices":[{"index":0,"delta":{"role":"assistant","content":null},"finish_reason":null}]}"#,
            #"{"id":"chatcmpl-late-name","object":"chat.completion.chunk","created":1711357598,"model":"grok-3","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_late","type":"function","function":{"arguments":""}}]},"finish_reason":null}]}"#,
            #"{"id":"chatcmpl-late-name","object":"chat.completion.chunk","created":1711357598,"model":"grok-3","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_late","type":"function","function":{"name":"test-tool","arguments":"{\""}}]},"finish_reason":null}]}"#,
            #"{"id":"chatcmpl-late-name","object":"chat.completion.chunk","created":1711357598,"model":"grok-3","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"value"}}]},"finish_reason":null}]}"#,
            #"{"id":"chatcmpl-late-name","object":"chat.completion.chunk","created":1711357598,"model":"grok-3","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\":\"hi\"}"}}]},"finish_reason":null}]}"#,
            #"{"id":"chatcmpl-late-name","object":"chat.completion.chunk","created":1729171479,"model":"grok-3","choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":18,"completion_tokens":10,"total_tokens":28}}"#
        ]))
        let parts = try await collect(provider(transport).chatModel("grok-3").stream(LanguageModelRequest(
            messages: [.user("Hello")], tools: ["test-tool": Self.tool]
        )))
        var sequence: [String] = []
        for part in parts {
            switch part {
            case let .toolInputStart(id, name, _, _, _, _): sequence.append("start:\(id):\(name)")
            case let .toolInputDelta(id, delta, _): sequence.append("delta:\(id):\(delta)")
            case let .toolInputEnd(id, _): sequence.append("end:\(id)")
            case let .toolCall(call): sequence.append("call:\(call.id):\(call.name):\(call.arguments)")
            case let .responseMetadata(metadata): sequence.append("meta:\(metadata.id ?? ""):\(metadata.modelID ?? ""):\(Int(metadata.timestamp?.timeIntervalSince1970 ?? 0))")
            case let .finishMetadata(reason, usage, providerMetadata):
                sequence.append("finish:\(reason ?? "")")
                #expect(providerMetadata == ["test-provider": [:]])
                #expect(usage?.inputTokens == 18)
                #expect(usage?.inputTokensCacheRead == 0)
                #expect(usage?.inputTokensNoCache == 18)
                #expect(usage?.outputTextTokens == 10)
                #expect(usage?.outputReasoningTokens == 0)
            case .textStart, .textDeltaPart, .reasoningStart, .error: sequence.append("unexpected")
            default: break
            }
        }
        #expect(sequence == [
            "meta:chatcmpl-late-name:grok-3:1711357598",
            "start:call_late:test-tool",
            "delta:call_late:{\"",
            "delta:call_late:value",
            "delta:call_late:\":\"hi\"}",
            "end:call_late",
            "call:call_late:test-tool:{\"value\":\"hi\"}",
            "finish:tool-calls"
        ])
    }

    @Test func streamToolCallWhoseIndexStartsAtOne() async throws {
        let line = { (delta: String, finish: String) in
            #"{"id":"msg_sanitized","object":"chat.completion.chunk","created":0,"model":"claude-haiku-4-5-20251001","choices":[{"index":0,"delta":"# + delta + #","finish_reason":"# + finish + "}]}"
        }
        let transport = RecordingTransport(response: chunks([
            line(#"{"role":"assistant"}"#, "null"),
            line(#"{"content":"Reading"}"#, "null"),
            line(#"{"content":" it."}"#, "null"),
            line(#"{"tool_calls":[{"index":1,"id":"toolu_sanitized","type":"function","function":{"name":"read_file","arguments":""}}]}"#, "null"),
            line(#"{"tool_calls":[{"index":1,"function":{"arguments":""}}]}"#, "null"),
            line(#"{"tool_calls":[{"index":1,"function":{"arguments":"{\"pa"}}]}"#, "null"),
            line(#"{"tool_calls":[{"index":1,"function":{"arguments":"th\": \"a.txt\"}"}}]}"#, "null"),
            line("{}", #""tool_calls""#)
        ]))
        let parts = try await collect(provider(transport).chatModel("grok-3").stream(LanguageModelRequest(
            messages: [.user("Hello")], tools: ["read_file": ["type": "object", "properties": ["path": ["type": "string"]]]]
        )))
        let text = parts.compactMap { part -> String? in if case let .textDeltaPart(_, delta, _) = part { delta } else { nil } }.joined()
        #expect(text == "Reading it.")
        let calls = parts.compactMap { part -> AIToolCall? in if case let .toolCall(call) = part { call } else { nil } }
        #expect(calls.map { "\($0.id)|\($0.name)|\($0.arguments)" } == [#"toolu_sanitized|read_file|{"path": "a.txt"}"#])
        guard case .finishMetadata = parts.last else { Issue.record("last part is not finish"); return }
        // created: 0 is a placeholder timestamp.
        let metadata = parts.compactMap { part -> AIResponseMetadata? in if case let .responseMetadata(value) = part { value } else { nil } }
        #expect(metadata.first?.timestamp == nil)
    }

    @Test func keepIDLessToolCallsDistinctWhenTheIndexIsReused() async throws {
        let prefix = #"{"id":"chatcmpl-reused-index","object":"chat.completion.chunk","created":1711357598,"model":"grok-3","choices":[{"index":0,"delta":"#
        let transport = RecordingTransport(response: chunks([
            prefix + #"{"role":"assistant","tool_calls":[{"index":0,"type":"function","function":{"name":"read_file","arguments":"{\"path\":\"p0\"}"}}]},"finish_reason":null}]}"#,
            prefix + #"{"tool_calls":[{"index":0,"type":"function","function":{"name":"write_file","arguments":"{\"path\":\"p1\"}"}}]},"finish_reason":null}]}"#,
            prefix + #"{"tool_calls":[{"index":0,"type":"function","function":{"name":"read_file","arguments":"{\"path\":\"p2\"}"}}]},"finish_reason":null}]}"#,
            #"{"id":"chatcmpl-reused-index","object":"chat.completion.chunk","created":1711357598,"model":"grok-3","choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":18,"completion_tokens":10,"total_tokens":28}}"#
        ]))
        let parts = try await collect(provider(transport).chatModel("grok-3").stream(LanguageModelRequest(messages: [.user("Hello")])))
        let calls = parts.compactMap { part -> AIToolCall? in if case let .toolCall(call) = part { call } else { nil } }
        #expect(calls.map { "\($0.name)|\($0.arguments)" } == [#"read_file|{"path":"p0"}"#, #"write_file|{"path":"p1"}"#, #"read_file|{"path":"p2"}"#])
        #expect(calls.allSatisfy { !$0.id.trimmingCharacters(in: .whitespaces).isEmpty })
        #expect(Set(calls.map(\.id)).count == 3)
    }

    @Test func errorWhenStreamedToolCallNeverReceivesAFunctionName() async throws {
        let transport = RecordingTransport(response: chunks([
            #"{"id":"chatcmpl-no-name","object":"chat.completion.chunk","created":1711357598,"model":"grok-3","choices":[{"index":0,"delta":{"role":"assistant","content":null},"finish_reason":null}]}"#,
            #"{"id":"chatcmpl-no-name","object":"chat.completion.chunk","created":1711357598,"model":"grok-3","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_missing","type":"function","function":{"arguments":"{}"}}]},"finish_reason":null}]}"#,
            #"{"id":"chatcmpl-no-name","object":"chat.completion.chunk","created":1729171479,"model":"grok-3","choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":18,"completion_tokens":10,"total_tokens":28}}"#
        ]))
        do {
            _ = try await collect(provider(transport).chatModel("grok-3").stream(LanguageModelRequest(
                messages: [.user("Hello")], tools: ["test-tool": Self.tool]
            )))
            Issue.record("expected the stream to fail")
        } catch {
            #expect(String(describing: error).contains("Expected 'function.name' to be a string."))
        }
    }

    @Test func extractResponseMetadataAfterAnEmptyPlaceholderChunk() async throws {
        let transport = RecordingTransport(response: chunks([
            #"{"choices":[],"created":0,"id":"","model":"","object":""}"#,
            #"{"choices":[{"delta":{"content":"Hello","role":"assistant"},"finish_reason":null,"index":0}],"created":1700000000,"id":"chatcmpl-123","model":"actual-model-name","object":"chat.completion.chunk"}"#,
            #"{"choices":[{"delta":{},"finish_reason":"stop","index":0}],"created":1700000000,"id":"chatcmpl-123","model":"actual-model-name","object":"chat.completion.chunk"}"#,
            #"{"choices":[],"created":1700000000,"id":"chatcmpl-123","model":"actual-model-name","object":"chat.completion.chunk","usage":{"prompt_tokens":10,"completion_tokens":1,"total_tokens":11}}"#
        ]))
        let parts = try await collect(provider(transport).chatModel("grok-3").stream(LanguageModelRequest(messages: [.user("Hello")])))
        let metadata = parts.compactMap { part -> AIResponseMetadata? in if case let .responseMetadata(value) = part { value } else { nil } }
        #expect(metadata.count == 1)
        #expect(metadata.first?.id == "chatcmpl-123")
        #expect(metadata.first?.modelID == "actual-model-name")
        #expect(metadata.first?.timestamp == Date(timeIntervalSince1970: 1700000000))
    }

    @Test func emptyDeltasDoNotOpenTextAndReasoningClosesText() async throws {
        let prefix = #"{"id":"c","created":1,"model":"m","choices":[{"index":0,"delta":"#
        let transport = RecordingTransport(response: chunks([
            prefix + #"{"role":"assistant","content":"","reasoning_content":""},"finish_reason":null}]}"#,
            prefix + #"{"content":"Answer"},"finish_reason":null}]}"#,
            prefix + #"{"reasoning_content":"More"},"finish_reason":null}]}"#,
            prefix + #"{},"finish_reason":"stop"}]}"#
        ]))
        let parts = try await collect(provider(transport).chatModel("grok-3").stream(LanguageModelRequest(messages: [.user("Hello")])))
        let sequence = parts.compactMap { part -> String? in
            switch part {
            case .textStart: "text-start"
            case let .textDeltaPart(_, delta, _): "text:\(delta)"
            case .textEnd: "text-end"
            case .reasoningStart: "reasoning-start"
            case let .reasoningDeltaPart(_, delta, _): "reasoning:\(delta)"
            case .reasoningEnd: "reasoning-end"
            default: nil
            }
        }
        #expect(sequence == ["text-start", "text:Answer", "text-end", "reasoning-start", "reasoning:More", "reasoning-end"])
    }

    @Test func streamEndingWithoutFinishReasonIsAnError() async throws {
        let transport = RecordingTransport(response: chunks([
            #"{"id":"c","created":1,"model":"m","choices":[{"index":0,"delta":{"content":"Hi"},"finish_reason":null}]}"#
        ]))
        let parts = try await collect(provider(transport).chatModel("grok-3").stream(LanguageModelRequest(messages: [.user("Hello")])))
        #expect(parts.contains { if case let .error(message, _) = $0 { message == "Response stream ended without a finish reason." } else { false } })
        guard case let .finishMetadata(reason, _, providerMetadata) = parts.last else { Issue.record("missing finish"); return }
        #expect(reason == "error")
        #expect(providerMetadata == ["test-provider": [:]])
    }

    @Test func streamRespectsIncludeUsageAndRequestBody() async throws {
        let transport = RecordingTransport(response: chunks([
            #"{"id":"c","created":1,"model":"m","choices":[{"index":0,"delta":{"content":"Hi"},"finish_reason":"stop"}]}"#
        ]))
        _ = try await collect(provider(transport, includeUsage: true).chatModel("grok-3").stream(LanguageModelRequest(
            messages: [.user("Hello")], providerOptions: ["test-provider": ["stream": false]]
        )))
        #expect(try await body(transport) == [
            "messages": [["content": "Hello", "role": "user"]], "model": "grok-3",
            "stream": true, "stream_options": ["include_usage": true]
        ])
    }

    // MARK: embedding

    @Test func embeddingSendsOnlyTypedProviderOptions() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"data":[{"embedding":[0.1,0.2]}],"usage":{"prompt_tokens":8}}"#))
        let model = try provider(transport).embeddingModel("text-embedding-3-large")
        let result = try await model.embed(EmbeddingRequest(
            values: ["sunny day at the beach"],
            dimensions: 32,
            providerOptions: ["test-provider": ["dimensions": 64, "user": "u", "other": "dropped"]]
        ))
        #expect(try await body(transport) == [
            "model": "text-embedding-3-large", "input": ["sunny day at the beach"],
            "encoding_format": "float", "dimensions": 64, "user": "u"
        ])
        #expect(result.warnings == [AIWarning(type: "deprecated", setting: "providerOptions key 'test-provider'", message: "Use 'testProvider' instead.")])
    }

    // MARK: completion (openai-compatible-completion-language-model.test.ts)

    @Test func completionSupportsUnknownFinishReasonAndUsage() async throws {
        let transport = RecordingTransport(response: jsonResponse("""
        {"id":"cmpl-96cAM1v77r4jXa4qb2NSmRREV5oWB","object":"text_completion","created":1711363706,"model":"gpt-3.5-turbo-instruct","choices":[{"text":"","index":0,"finish_reason":"eos"}],"usage":{"prompt_tokens":4,"total_tokens":34,"completion_tokens":30}}
        """))
        let result = try await provider(transport).completionModel("gpt-3.5-turbo-instruct").generate(LanguageModelRequest(messages: [.user("Hello")]))
        #expect(result.finishReason == "other")
        #expect(result.usage?.inputTokens == 4)
        #expect(result.usage?.inputTokensNoCache == 4)
        #expect(result.usage?.inputTokensCacheRead == nil)
        #expect(result.usage?.outputTokens == 30)
        #expect(result.usage?.outputTextTokens == 30)
        #expect(result.usage?.outputReasoningTokens == nil)

        let filtered = RecordingTransport(response: jsonResponse(#"{"choices":[{"text":"x","index":0,"finish_reason":"content_filter"}]}"#))
        let filteredResult = try await provider(filtered).completionModel("gpt-3.5-turbo-instruct").generate(LanguageModelRequest(messages: [.user("Hello")]))
        #expect(filteredResult.finishReason == "content-filter")
        #expect(filteredResult.usage == nil)
    }

    @Test func completionStreamsTextDeltas() async throws {
        let transport = RecordingTransport(response: chunks([
            #"{"id":"cmpl-96c64EdfhOw8pjFFgVpLuT8k2MtdT","object":"text_completion","created":1711363440,"model":"gpt-3.5-turbo-instruct","choices":[{"text":"Hello","index":0,"logprobs":null,"finish_reason":null}]}"#,
            #"{"id":"cmpl-96c64EdfhOw8pjFFgVpLuT8k2MtdT","object":"text_completion","created":1711363440,"model":"gpt-3.5-turbo-instruct","choices":[{"text":",","index":0,"logprobs":null,"finish_reason":null}]}"#,
            #"{"id":"cmpl-96c64EdfhOw8pjFFgVpLuT8k2MtdT","object":"text_completion","created":1711363440,"model":"gpt-3.5-turbo-instruct","choices":[{"text":" World!","index":0,"logprobs":null,"finish_reason":null}]}"#,
            #"{"id":"cmpl-96c3yLQE1TtZCd6n6OILVmzev8M8H","object":"text_completion","created":1711363310,"model":"gpt-3.5-turbo-instruct","choices":[{"text":"","index":0,"logprobs":null,"finish_reason":"stop"}]}"#,
            #"{"id":"cmpl-96c3yLQE1TtZCd6n6OILVmzev8M8H","object":"text_completion","created":1711363310,"model":"gpt-3.5-turbo-instruct","usage":{"prompt_tokens":10,"completion_tokens":362,"total_tokens":372},"choices":[]}"#
        ]))
        let parts = try await collect(provider(transport).completionModel("gpt-3.5-turbo-instruct").stream(LanguageModelRequest(messages: [.user("Hello")])))
        let sequence = parts.compactMap { part -> String? in
            switch part {
            case let .responseMetadata(metadata): "meta:\(metadata.id ?? ""):\(metadata.modelID ?? ""):\(Int(metadata.timestamp?.timeIntervalSince1970 ?? 0))"
            case let .textStart(id, _): "start:\(id)"
            case let .textDeltaPart(id, delta, _): "delta:\(id):\(delta)"
            case let .textEnd(id, _): "end:\(id)"
            case let .finishMetadata(reason, _, metadata): "finish:\(reason ?? ""):\(metadata.isEmpty)"
            default: nil
            }
        }
        #expect(sequence == [
            "meta:cmpl-96c64EdfhOw8pjFFgVpLuT8k2MtdT:gpt-3.5-turbo-instruct:1711363440",
            "start:0", "delta:0:Hello", "delta:0:,", "delta:0: World!", "delta:0:", "end:0",
            "finish:stop:true"
        ])
        guard case let .finishMetadata(_, usage, _) = parts.last else { Issue.record("missing finish"); return }
        #expect(usage?.inputTokens == 10)
        #expect(usage?.inputTokensNoCache == 10)
        #expect(usage?.outputTokens == 362)
        #expect(usage?.outputTextTokens == 362)
        #expect(usage?.outputReasoningTokens == nil)
    }
}
