import Foundation
import Testing
@testable import SwiftAISDK

@Suite("WeeklyLanguage20261025")
struct WeeklyLanguage20261025Tests {
    private func model(_ name: String, transport: RecordingTransport) throws -> any LanguageModel {
        let settings = ProviderSettings(apiKey: "offline-key", transport: transport)
        switch name {
        case "alibaba": return try AIProviders.alibaba(settings: settings).languageModel("qwen-plus")
        case "cohere": return try AIProviders.cohere(settings: settings).languageModel("command-a-03-2025")
        case "deepseek": return try AIProviders.deepSeek(settings: settings).languageModel("deepseek-chat")
        case "groq": return try AIProviders.groq(settings: settings).languageModel("llama-3.3-70b-versatile")
        case "mistral": return try AIProviders.mistral(settings: settings).languageModel("mistral-small-latest")
        case "moonshotai": return try AIProviders.moonshotAI(settings: settings).languageModel("kimi-k3")
        case "completion": return try AIProviders.openAI(settings: settings).completion("gpt-3.5-turbo-instruct")
        case "chat": return try AIProviders.openAI(settings: settings).chat("gpt-4o")
        case "xai": return try AIProviders.xAI(settings: settings).responses("grok-4")
        case "open-responses": return try AIProviders.openResponses(name: "custom", url: "https://example.test/v1", settings: settings).languageModel("model")
        case "huggingface": return try AIProviders.huggingFace(settings: settings).languageModel("test-model")
        case "perplexity": return try AIProviders.perplexity(settings: settings).languageModel("openai/gpt-5")
        default: return try AIProviders.openAI(settings: settings).responses("gpt-4o")
        }
    }

    private func parts(_ model: any LanguageModel, request: LanguageModelRequest = .init(messages: [.user("Hello")])) async throws -> [LanguageStreamPart] {
        var result: [LanguageStreamPart] = []
        for try await part in model.stream(request) { result.append(part) }
        return result
    }

    private func finish(_ values: [LanguageStreamPart]) -> [String] {
        values.compactMap { if case let .finishMetadata(reason, _, _) = $0 { reason } else { nil } }
    }

    @Test(arguments: ["alibaba", "deepseek", "groq", "mistral", "moonshotai", "chat", "completion"], ["missing", "unknown", "invalid"])
    func chatStreamsDistinguishCutoffFromUnknownAndInvalid(_ provider: String, _ ending: String) async throws {
        let first = #"{"id":"r1","object":"chat.completion.chunk","created":1,"model":"test-model","choices":[{"index":0,"delta":{"content":"Partial answer"},"text":"Partial answer","finish_reason":null}]}"#
        let last = ending == "invalid" ? "data: {invalid-json}" : ending == "unknown"
            ? #"data: {"choices":[{"index":0,"delta":{},"text":"","finish_reason":"unknown_reason"}]}"# : ""
        let transport = RecordingTransport(response: sseResponse("data: " + first + "\n\n" + last))
        let output = try await parts(model(provider, transport: transport))
        #expect(finish(output) == [ending == "missing" ? "interrupted" : ending == "invalid" ? "error" : "other"])
        #expect(output.filter { if case .error = $0 { true } else { false } }.count == (ending == "invalid" ? 1 : 0))
        #expect(output.contains { if case let .textDeltaPart(_, text, _) = $0 { text == "Partial answer" } else { false } })
    }

    @Test(arguments: ["openai", "open-responses", "xai", "huggingface", "perplexity"], [false, true])
    func responseStreamsReportTruncationAndParseErrors(_ provider: String, _ invalid: Bool) async throws {
        let delta = #"data: {"type":"response.output_text.delta","item_id":"msg1","output_index":0,"content_index":0,"sequence_number":1,"delta":"Partial answer"}"#
        let transport = RecordingTransport(response: sseResponse(delta + (invalid ? "\n\ndata: {invalid-json}" : "")))
        let output = try await parts(model(provider, transport: transport))
        #expect(finish(output) == [invalid ? "error" : "interrupted"])
        #expect(output.filter { if case .error = $0 { true } else { false } }.count == (invalid ? 1 : 0))
    }

    @Test(arguments: [false, true])
    func cohereDistinguishesTruncationFromError(_ invalid: Bool) async throws {
        let delta = #"data: {"type":"content-delta","index":0,"delta":{"message":{"content":{"text":"Partial answer"}}}}"#
        let transport = RecordingTransport(response: sseResponse(delta + (invalid ? "\n\ndata: {invalid-json}" : "")))
        #expect(try await finish(parts(model("cohere", transport: transport))) == [invalid ? "error" : "interrupted"])
    }

    @Test func genericCompatibleRetainsItsMissingFinishValidation() async throws {
        let transport = RecordingTransport(response: sseResponse(#"data: {"choices":[{"delta":{"content":"partial"}}]}"#))
        let target = try AIProviders.openAICompatible(name: "custom", baseURL: "https://example.test", transport: transport).chat("test")
        let output = try await parts(target)
        #expect(finish(output) == ["error"])
        #expect(output.contains { if case let .error(message, _) = $0 { message.contains("without a finish reason") } else { false } })
    }

    @Test func explicitResponsesTerminalEventsRemainRecognized() async throws {
        for provider in ["xai", "perplexity"] {
            let transport = RecordingTransport(response: sseResponse(#"data: {"type":"response.completed","response":{"id":"r1","object":"response","model":"test-model","created_at":1,"status":"","output":[]}}"#))
            let output = try await parts(model(provider, transport: transport))
            #expect(finish(output) == ["other"], "Provider: \(provider)")
        }
    }

    @Test(arguments: [false, true])
    func bedrockCutoffRetainsUsageAndClosesText(_ completed: Bool) async throws {
        var events = [(eventType: "contentBlockDelta", payload: #"{"contentBlockIndex":0,"delta":{"text":"Partial answer"}}"#)]
        if completed { events.append((eventType: "messageStop", payload: #"{"stopReason":"end_turn"}"#)) }
        events.append((eventType: "metadata", payload: #"{"usage":{"inputTokens":3,"outputTokens":2,"totalTokens":5}}"#))
        let transport = RecordingTransport(response: amazonEventStreamResponse(events))
        let target = try AIProviders.amazonBedrock(settings: .init(region: "us-east-1", apiKey: "offline-key", transport: transport)).languageModel("anthropic.claude-3-haiku-20240307-v1:0")
        let output = try await parts(target)
        #expect(finish(output) == [completed ? "stop" : "interrupted"])
        #expect(output.contains(.textEnd(id: "0")))
        #expect(output.contains { if case let .finishMetadata(_, usage, _) = $0 { usage?.inputTokens == 3 } else { false } })
    }

    private func anthropicEvents(_ text: String, stop: Bool = false, reason: String? = nil, id: String = "msg1") throws -> String {
        var events: [JSONValue] = [
            ["type": "message_start", "message": ["id": .string(id), "type": "message", "role": "assistant", "content": .array([JSONValue]()), "model": "claude-3-haiku-20240307", "stop_reason": .null, "usage": ["input_tokens": 10, "output_tokens": 1]]],
            ["type": "content_block_start", "index": 0, "content_block": ["type": "text", "text": ""]],
            ["type": "content_block_delta", "index": 0, "delta": ["type": "text_delta", "text": .string(text)]]
        ]
        if let reason { events.append(["type": "message_delta", "delta": ["stop_reason": .string(reason)], "usage": ["output_tokens": 3]]) }
        if stop { events.append(["type": "message_stop"]) }
        return try events.map { "data: " + String(decoding: try encodeJSONBody($0), as: UTF8.self) }.joined(separator: "\n\n")
    }

    @Test(arguments: ["", "Partial answer"], [false, true])
    func anthropicRequiresPartialOutputBeforeInterruptedFinish(_ text: String, _ stop: Bool) async throws {
        let transport = RecordingTransport(response: sseResponse(try anthropicEvents(text, stop: stop, reason: "end_turn")))
        let target = try AIProviders.anthropic(settings: .init(apiKey: "offline-key", transport: transport)).languageModel("claude-3-haiku-20240307")
        let output = try await parts(target)
        #expect(finish(output) == (stop ? ["stop"] : text.isEmpty ? [] : ["interrupted"]))
    }

    @Test func anthropicNativeResponseEndsAtFirstMessageStop() async throws {
        let events = try anthropicEvents("First answer", stop: true, reason: "end_turn") + "\n\n" + anthropicEvents("Partial answer", id: "msg2")
        let transport = RecordingTransport(response: sseResponse(events))
        let target = try AIProviders.anthropic(settings: .init(apiKey: "offline-key", transport: transport)).languageModel("claude-3-haiku-20240307")
        let output = try await parts(target)
        #expect(finish(output) == ["stop"])
        let terminals = output.compactMap { part -> (TokenUsage?, [String: JSONValue])? in
            if case let .finishMetadata(_, usage, metadata) = part { (usage, metadata) } else { nil }
        }
        #expect(terminals.count == 1)
        #expect(terminals.first?.0?.inputTokens == 10)
        #expect(terminals.first?.0?.outputTokens == 3)
        #expect(!output.contains { if case let .textDeltaPart(_, text, _) = $0 { text == "Partial answer" } else { false } })
    }

    @Test(arguments: [false, true], ["empty", "partial", "complete", "request-error"])
    func googleContinuedResponseResetsFinishInEventOrder(_ vertex: Bool, _ ending: String) async throws {
        let first = sseResponse(#"data: {"candidates":[{"content":{"parts":[{"text":"Hello"}]},"finishReason":"CONTINUATION","continuationToken":"token-1"}],"usageMetadata":{"promptTokenCount":10,"candidatesTokenCount":5}}"#)
        let last: AIHTTPResponse
        if ending == "request-error" { last = AIHTTPResponse(statusCode: 400, body: Data(#"{"error":{"message":"Invalid continuation token"}}"#.utf8)) }
        else if ending == "empty" { last = sseResponse("") }
        else {
            var candidate: [String: JSONValue] = ["content": ["parts": [["text": ", world"]]]]
            if ending == "complete" { candidate["finishReason"] = "STOP" }
            last = sseResponse("data: " + String(decoding: try encodeJSONBody(["candidates": [.object(candidate)], "usageMetadata": ["promptTokenCount": 20, "candidatesTokenCount": 2]]), as: UTF8.self))
        }
        let transport = RecordingTransport(responses: [first, last])
        let target: any LanguageModel = try vertex
            ? AIProviders.googleVertex(settings: .init(apiKey: "key", transport: transport)).languageModel("gemini-4-argon")
            : AIProviders.google(settings: .init(apiKey: "key", transport: transport)).languageModel("gemini-4-argon")
        let output = try await parts(target)
        #expect(finish(output) == [ending == "complete" ? "stop" : ending == "request-error" ? "length" : "interrupted"])
        #expect(await transport.requests().count == 2)
        #expect(output.contains { if case let .finishMetadata(_, usage, _) = $0 { usage?.inputTokens == (ending == "complete" || ending == "partial" ? 30 : 10) } else { false } })
    }

    @Test(arguments: ["in_progress", "requires_action", "completed", "cancelled", "unknown"])
    func googleInteractionsRecognizesLastStatusWithoutCompletion(_ status: String) async throws {
        let transport = RecordingTransport(response: sseResponse("data: {\"event_type\":\"interaction.status_update\",\"status\":\"\(status)\"}"))
        let target = try AIProviders.google(settings: .init(apiKey: "key", transport: transport)).interactionsModel("gemini-2.5-flash")
        let expected = status == "in_progress" ? "interrupted" : status == "requires_action" ? "tool-calls" : status == "completed" ? "stop" : "other"
        #expect(try await finish(parts(target)) == [expected])
    }

    @Test func googlePartialArgumentsKeepEmptyContainersAndTerminators() throws {
        var accumulator = GoogleJSONResponseArgumentAccumulator()
        let fields: [JSONValue] = [
            ["jsonPath": "$.id", "stringValue": "x"], ["jsonPath": "$.emptyArr[]"],
            ["jsonPath": "$.emptyObj"], ["jsonPath": "$.emptyStr", "stringValue": ""],
            ["jsonPath": "$.nested.tags[]"], ["jsonPath": "$.zero", "numberValue": 0],
            ["jsonPath": "$.no", "boolValue": false], ["jsonPath": "$.no"], ["jsonPath": "$"],
            ["jsonPath": "$.pending", "willContinue": true]
        ]
        var text = fields.map { accumulator.apply([$0]) }.joined()
        text += accumulator.finish()
        let parsed = try decodeJSONBody(Data(text.utf8))
        #expect(parsed == ["id": "x", "emptyArr": .array([JSONValue]()), "emptyObj": .object([:]), "emptyStr": "", "nested": ["tags": .array([JSONValue]())], "zero": 0, "no": false])
        #expect(text == accumulator.jsonText)
    }

    @Test(arguments: [false, true])
    func googleFunctionAndResponseToolsPreserveNestedEmptyArguments(_ responseTool: Bool) throws {
        var calls = GoogleGenerateContentStreamingToolCalls(jsonResponseToolName: responseTool ? "response" : nil)
        var parts = calls.apply(functionCall: ["name": responseTool ? "response" : "lookup", "id": "call1", "partialArgs": [["jsonPath": "$.nested.tags[]"], ["jsonPath": "$.emptyObject"]]], rawValue: .object([:]))
        parts += calls.finishedParts()
        let toolCall = try #require(parts.compactMap { part -> AIToolCall? in if case let .toolCall(call) = part { call } else { nil } }.last)
        #expect(try decodeJSONBody(Data(toolCall.arguments.utf8)) == ["nested": ["tags": .array([JSONValue]())], "emptyObject": .object([:])])
        let json = parts.compactMap { part -> String? in if case let .toolInputDelta(_, delta, _) = part { delta } else { nil } }.joined()
        #expect(json == toolCall.arguments)
    }

    @Test(arguments: ["reasoning", "tool-input"], ["", "partial"])
    func anthropicEmptyAndPartialReasoningOrToolInputRemainDistinct(_ channel: String, _ delta: String) async throws {
        let start: JSONValue = channel == "reasoning" ? ["type": "thinking", "thinking": ""] : ["type": "tool_use", "id": "call1", "name": "lookup", "input": .object([:])]
        let payload: JSONValue = channel == "reasoning" ? ["type": "thinking_delta", "thinking": .string(delta)] : ["type": "input_json_delta", "partial_json": .string(delta)]
        let events: [JSONValue] = [
            ["type": "message_start", "message": ["id": "msg", "content": .array([JSONValue]()), "model": "claude-3-haiku-20240307", "usage": ["input_tokens": 1, "output_tokens": 1]]],
            ["type": "content_block_start", "index": 0, "content_block": start],
            ["type": "content_block_delta", "index": 0, "delta": payload]
        ]
        let body = try events.map { "data: " + String(decoding: try encodeJSONBody($0), as: UTF8.self) }.joined(separator: "\n\n")
        let transport = RecordingTransport(response: sseResponse(body))
        let model = try AIProviders.anthropic(settings: .init(apiKey: "key", transport: transport)).languageModel("claude-3-haiku-20240307")
        let output = try await parts(model)
        #expect(finish(output) == (delta.isEmpty ? [] : ["interrupted"]))
    }

    @Test func googleParserFailureAfterExplicitFinishRetainsProviderReason() async throws {
        let transport = RecordingTransport(response: sseResponse(#"data: {"candidates":[{"content":{"parts":[{"text":"done"}]},"finishReason":"STOP"}]}"# + "\n\ndata: {invalid-json}"))
        let model = try AIProviders.google(settings: .init(apiKey: "key", transport: transport)).languageModel("gemini-2.5-flash")
        let output = try await parts(model)
        #expect(finish(output) == ["stop"])
        #expect(output.filter { if case .error = $0 { true } else { false } }.count == 1)
    }

    @Test func googleInteractionsParseFailuresAndStatusAliasesFinishPrecisely() async throws {
        for (body, expected) in [
            (#"data: {"event_type":"interaction.in_progress"}"#, "interrupted"),
            (#"data: {"event_type":"interaction.requires_action"}"#, "tool-calls"),
            (#"data: {invalid-json}"#, "error"),
            (#"data: {"event_type":"interaction.completed","interaction":{"id":"i1"}}"#, "other")
        ] {
            let transport = RecordingTransport(response: sseResponse(body))
            let model = try AIProviders.google(settings: .init(apiKey: "key", transport: transport)).interactionsModel("gemini-2.5-flash")
            let output = try await parts(model)
            #expect(finish(output) == [expected])
        }
    }

    @Test func googleEmptyContainersCanReceiveChildrenAndIgnoreArrayTerminators() throws {
        var accumulator = GoogleJSONResponseArgumentAccumulator()
        let entries: [JSONValue] = [
            ["jsonPath": "$.recipe"], ["jsonPath": "$.recipe.name", "stringValue": "Lasagna"],
            ["jsonPath": "$.recipe.steps[]"], ["jsonPath": "$.recipe.steps[0]", "stringValue": "Cook.", "willContinue": true],
            ["jsonPath": "$.recipe.steps[0]"], ["jsonPath": "$.recipe.steps[]"]
        ]
        for entry in entries { _ = accumulator.apply([entry]) }
        _ = accumulator.finish()
        #expect(try decodeJSONBody(Data(accumulator.jsonText.utf8)) == ["recipe": ["name": "Lasagna", "steps": ["Cook."]]])
    }
}
