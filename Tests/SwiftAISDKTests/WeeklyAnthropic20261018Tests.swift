import Foundation
import Testing
@testable import SwiftAISDK

private let weeklyAnthropicCitations: [JSONValue] = [
    ["type": "page_location", "cited_text": "Supporting passage", "document_index": 0, "document_title": "Report", "start_page_number": 1, "end_page_number": 2],
    ["type": "char_location", "cited_text": "Supporting passage", "document_index": 0, "document_title": "Report", "start_char_index": 0, "end_char_index": 18],
    ["type": "content_block_location", "cited_text": "Supporting passage", "document_index": 0, "document_title": "Report", "start_block_index": 0, "end_block_index": 1, "file_id": "file-report"],
    ["type": "web_search_result_location", "cited_text": "Supporting passage", "title": "Report", "url": "https://example.com/report", "encrypted_index": "opaque"],
    ["type": "search_result_location", "cited_text": "Supporting passage", "title": "Report", "source": "https://example.com/report", "search_result_index": 0, "start_block_index": 0, "end_block_index": 1]
]

@Suite("WeeklyAnthropic20261018")
struct WeeklyAnthropic20261018Tests {
    private let response = jsonResponse(#"{"content":[{"type":"text","text":"ok"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}"#)
    private let schema: JSONValue = ["type": "object", "properties": ["name": ["type": "string"]], "additionalProperties": false]
    private let tools: [String: JSONValue] = ["lookup": ["type": "object", "properties": [:]], "other": ["type": "object", "properties": [:]]]

    @Test(arguments: weeklyAnthropicCitations)
    func allCitationKindsHaveGenerateStreamParity(_ citation: JSONValue) async throws {
        let generated: JSONValue = ["content": [["type": "text", "text": "Answer", "citations": .array([citation])]], "stop_reason": "end_turn", "usage": ["input_tokens": 1, "output_tokens": 1]]
        let transport = RecordingTransport(responses: [jsonResponse(try json(generated)), try stream(citation: citation)])
        let model = try AIProviders.anthropic(settings: ProviderSettings(apiKey: "key", transport: transport)).languageModel("claude-haiku-4-5")
        let request = LanguageModelRequest(messages: [AIMessage(role: .user, content: [.file(mimeType: "application/pdf", data: Data("%PDF".utf8), filename: "report.pdf", providerMetadata: ["anthropic": ["citations": ["enabled": true]]])])])
        let result = try await model.generate(request)
        var parts: [LanguageStreamPart] = []
        for try await part in model.stream(request) { parts.append(part) }
        let end = try #require(parts.first { !$0.citations.isEmpty })
        #expect(end.citations == result.citations)
        let normalized = try #require(result.citations.first)
        #expect(normalized.citedText == "Supporting passage")
        #expect(normalized.startIndex == nil && normalized.endIndex == nil)
        #expect(normalized.source.title == "Report")
        #expect(normalized.source.providerMetadata["anthropic"] == citation)
        if citation["document_index"] != nil {
            #expect(normalized.source.id == (citation["file_id"]?.stringValue ?? "0"))
            #expect(normalized.source.filename == "report.pdf")
            #expect(normalized.source.mediaType == "application/pdf")
        } else {
            #expect(normalized.source.id == "https://example.com/report")
            #expect(normalized.source.sourceType == "url")
        }
        guard case let .citedText(_, _, metadata) = result.content.first else { Issue.record("Missing cited text"); return }
        #expect(metadata["anthropic"]?["citations"] == .array([citation]))
        guard case let .textEndWithCitations(_, _, streamMetadata) = end else { Issue.record("Missing cited text end"); return }
        #expect(streamMetadata == metadata)
    }

    @Test(arguments: [false, true])
    func webSearchSourcesAvoidCitationDuplicatesAndRetainFallback(_ includeResults: Bool) async throws {
        let citation = weeklyAnthropicCitations[3]
        let resultBlock: JSONValue = ["type": "web_search_tool_result", "tool_use_id": "search", "content": includeResults ? [["type": "web_search_result", "url": "https://example.com/report", "title": "Report", "encrypted_content": "opaque", "page_age": "today"]] : []]
        let blocks: [JSONValue] = [["type": "text", "text": "Answer", "citations": .array([citation])], ["type": "server_tool_use", "id": "search", "name": "web_search", "input": ["query": "report"]], resultBlock]
        let generated: JSONValue = ["content": .array(blocks), "usage": ["input_tokens": 1, "output_tokens": 1]]
        let transport = RecordingTransport(responses: [jsonResponse(try json(generated)), try stream(citation: citation, laterResult: resultBlock)])
        let model = try AIProviders.anthropic(settings: ProviderSettings(apiKey: "key", transport: transport)).languageModel("claude-haiku-4-5")
        let result = try await model.generate(LanguageModelRequest(messages: [.user("Search")]))
        #expect(result.sources.count == 1 && result.citations.count == 1)
        var sources: [AISource] = []
        var eventOrder: [String] = []
        for try await part in model.stream(LanguageModelRequest(messages: [.user("Search")])) {
            switch part {
            case let .source(source): sources.append(source); eventOrder.append("source")
            case .textEndWithCitations: eventOrder.append("text-end")
            case .finishMetadata: eventOrder.append("finish")
            default: break
            }
        }
        #expect(sources.count == 1)
        #expect(sources[0].url == "https://example.com/report")
        #expect(sources[0].providerMetadata["anthropic"] == (includeResults ? ["pageAge": "today"] : ["citedText": "Supporting passage", "encryptedIndex": "opaque"]))
        #expect(eventOrder == ["text-end", "source", "finish"])
    }

    @Test func documentCitationIndicesSkipUncitedAndNonUserFiles() async throws {
        let citation: JSONValue = ["type": "char_location", "cited_text": "passage", "document_index": 0, "document_title": .null, "start_char_index": 0, "end_char_index": 7]
        let generated: JSONValue = ["content": [["type": "text", "text": "Answer", "citations": .array([citation])]], "usage": ["input_tokens": 1, "output_tokens": 1]]
        let transport = RecordingTransport(response: jsonResponse(try json(generated)))
        let model = try AIProviders.anthropic(settings: ProviderSettings(apiKey: "key", transport: transport)).languageModel("claude-haiku-4-5")
        let enabled: [String: JSONValue] = ["anthropic": ["citations": ["enabled": true]]]
        let result = try await model.generate(LanguageModelRequest(messages: [
            AIMessage(role: .assistant, content: [.file(mimeType: "application/pdf", data: Data("%PDF".utf8), filename: "history.pdf", providerMetadata: enabled)]),
            AIMessage(role: .user, content: [
                .file(mimeType: "application/pdf", data: Data("%PDF".utf8), filename: "uncited.pdf"),
                .providerReference(mimeType: "text/plain", reference: ["anthropic": "file-cited"], filename: "cited.txt", providerMetadata: enabled)
            ])
        ]))
        #expect(result.citations.first?.source.filename == "cited.txt")
        #expect(result.citations.first?.source.title == "cited.txt")
        #expect(result.citations.first?.source.mediaType == "text/plain")
        #expect(result.sources.first?.filename == "cited.txt")
    }

    @Test func batchCitationsDoNotGuessOriginalDocumentsOrDuplicateSearchResults() async throws {
        let status = jsonResponse(#"{"id":"batch","type":"message_batch","processing_status":"ended","request_counts":{"processing":0,"succeeded":1,"errored":0,"canceled":0,"expired":0},"created_at":"2026-10-18T00:00:00Z","expires_at":"2026-10-19T00:00:00Z","results_url":"https://api.anthropic.com/v1/messages/batches/batch/results"}"#)
        let documentCitation: JSONValue = ["type": "content_block_location", "cited_text": "block", "document_index": 7, "document_title": .null, "start_block_index": 0, "end_block_index": 1, "file_id": .null]
        let content: [JSONValue] = [["type": "text", "text": "Answer", "citations": .array([documentCitation, weeklyAnthropicCitations[3]])], ["type": "server_tool_use", "id": "search", "name": "web_search", "input": [:]], ["type": "web_search_tool_result", "tool_use_id": "search", "content": [["type": "web_search_result", "url": "https://example.com/report", "title": "Report", "encrypted_content": "opaque"]]]]
        let row: JSONValue = ["custom_id": "item", "result": ["type": "succeeded", "message": ["type": "message", "content": .array(content), "usage": ["input_tokens": 1, "output_tokens": 1]]]]
        let transport = RecordingTransport(responses: [status, jsonResponse(try json(row))])
        let model = try AIProviders.anthropic(settings: ProviderSettings(apiKey: "key", transport: transport)).batchLanguageModel("claude-haiku-4-5")
        var results: [AIBatchItemResult<TextGenerationResult>] = []
        for try await item in try await model.getBatchResults(AIBatchOperationOptions(batchID: "batch")) { results.append(item) }
        guard case let .succeeded(_, result) = results.first else { Issue.record("Batch item did not succeed"); return }
        #expect(result.citations.count == 2)
        #expect(result.citations[0].source.id == "7")
        #expect(result.citations[0].source.title == "Document 7")
        #expect(result.citations[0].source.mediaType == "text/plain")
        #expect(result.citations[0].source.filename == nil)
        #expect(result.sources.count == 1)
    }

    @Test(arguments: ["required", "tool"])
    func manualThinkingDowngradesForcedChoicesDuringGenerateAndStream(_ type: String) async throws {
        let transport = RecordingTransport(responses: [response, try stream()])
        let model = try AIProviders.anthropic(settings: ProviderSettings(apiKey: "key", transport: transport)).languageModel("claude-haiku-4-5")
        let request = LanguageModelRequest(messages: [.user("Look up")], tools: tools, toolChoice: ["type": .string(type), "toolName": "lookup"], providerOptions: ["anthropic": ["thinking": ["type": "enabled", "budgetTokens": 5000]]])
        let result = try await model.generate(request)
        var streamWarnings: [AIWarning] = []
        for try await part in model.stream(request) { if case let .streamStart(warnings) = part { streamWarnings = warnings } }
        for sent in await transport.requests() {
            let body = try decodeJSONBody(try #require(sent.body))
            #expect(body["thinking"]?["type"] == "enabled")
            #expect(body["tool_choice"] == ["type": "auto"])
            let names = Set(body["tools"]?.arrayValue?.compactMap { $0["name"]?.stringValue } ?? [])
            #expect(names == (type == "tool" ? Set(["lookup"]) : Set(["lookup", "other"])))
        }
        for warnings in [result.warnings, streamWarnings] {
            #expect(warnings.filter { $0.feature == "toolChoice" }.count == 1)
            #expect(warnings.contains { $0.message?.contains("model or thinking configuration") == true })
        }
    }

    @Test(arguments: ["disabled", "adaptive", "normalized"])
    func nonManualThinkingPreservesForcedToolChoice(_ mode: String) async throws {
        let modelID = mode == "normalized" ? "claude-haiku-5-5" : mode == "adaptive" ? "claude-sonnet-4-6" : "claude-haiku-4-5"
        let thinking: JSONValue = ["type": .string(mode == "normalized" ? "enabled" : mode)]
        let prepared = try AnthropicLanguageModel.body(for: LanguageModelRequest(messages: [.user("Use tools")], tools: tools, toolChoice: ["type": "required"], providerOptions: ["anthropic": ["thinking": thinking]]), modelID: modelID, providerID: "anthropic.messages")
        #expect(prepared.body["tool_choice"]?["type"] == "any")
        #expect(!prepared.warnings.contains { $0.feature == "toolChoice" })
    }

    @Test func noneChoiceRetainsToolsAndJSONToolThinkingUsesAutomaticChoice() throws {
        let empty = try anthropicPrepareTools(from: [:], toolChoice: ["type": "required"], rejectsForcedToolUse: true)
        #expect(empty.tools.isEmpty && empty.toolChoice == nil && empty.warnings.isEmpty)
        let none = try AnthropicLanguageModel.body(for: LanguageModelRequest(messages: [.user("No tool calls")], tools: tools, toolChoice: ["type": "none"], providerOptions: ["anthropic": ["disableParallelToolUse": true]]), modelID: "claude-haiku-4-5", providerID: "anthropic.messages")
        #expect(none.body["tools"]?.arrayValue?.count == 2)
        #expect(none.body["tool_choice"] == ["type": "none"])
        let jsonTool = try AnthropicLanguageModel.body(for: LanguageModelRequest(messages: [.user("Return JSON")], responseFormat: .json(schema: schema), tools: tools, toolChoice: ["type": "tool", "toolName": "lookup"], providerOptions: ["anthropic": ["thinking": ["type": "enabled", "budgetTokens": 5000], "structuredOutputMode": "jsonTool"]]), modelID: "claude-haiku-4-5", providerID: "anthropic.messages")
        #expect(jsonTool.body["tools"]?.arrayValue?.count == 3)
        #expect(jsonTool.body["tool_choice"] == ["type": "auto", "disable_parallel_tool_use": true])
        #expect(jsonTool.warnings.filter { $0.feature == "toolChoice" }.count == 1)
    }

    @Test(arguments: ["image/png", "application/pdf", "text/plain"], ["anthropic.messages", "anthropic-aws.messages"])
    func toolResultFilesResolveProviderReferencesAndRequireTheirProvider(_ mediaType: String, _ providerID: String) throws {
        func request(reference: JSONValue) -> LanguageModelRequest {
            LanguageModelRequest(messages: [AIMessage(role: .tool, content: [.toolResult(AIToolResult(toolCallID: "file-call", toolName: "get-file", result: ["type": "content", "value": [["type": "file", "mediaType": .string(mediaType), "data": ["type": "reference", "reference": reference]]]]))])])
        }
        let key = providerID.hasPrefix("anthropic-aws") ? "anthropic-aws" : "anthropic"
        let prepared = try AnthropicLanguageModel.body(for: request(reference: .object([key: "file-123"])), modelID: "claude-haiku-4-5", providerID: providerID)
        let block = prepared.body["messages"]?[0]?["content"]?[0]?["content"]?[0]
        #expect(block?["type"] == .string(mediaType.hasPrefix("image/") ? "image" : "document"))
        #expect(block?["source"] == ["type": "file", "file_id": "file-123"])
        #expect(prepared.betas.contains("files-api-2025-04-14"))
        let canonical = try AnthropicLanguageModel.body(for: request(reference: ["anthropic": "file-canonical"]), modelID: "claude-haiku-4-5", providerID: providerID)
        #expect(canonical.body["messages"]?[0]?["content"]?[0]?["content"]?[0]?["source"]?["file_id"] == "file-canonical")
        #expect(throws: AINoSuchProviderReferenceError.self) {
            try AnthropicLanguageModel.body(for: request(reference: ["openai": "wrong-provider"]), modelID: "claude-haiku-4-5", providerID: providerID)
        }
    }

    @Test(arguments: ["tool_search_tool_regex", "tool_search_tool_bm25"], ["json", "error-json", "default-error"])
    func toolSearchErrorTranscriptsReplayWithoutDroppingResults(_ toolName: String, _ outputType: String) throws {
        let error: JSONValue = ["type": "tool_search_tool_result_error", "errorCode": "invalid_tool_input"]
        let value = outputType == "json" ? error : outputType == "default-error" ? .string("unavailable") : .string(try json(error))
        let output: JSONValue = ["type": .string(outputType == "json" ? "json" : "error-json"), "value": value]
        let prepared = try AnthropicLanguageModel.body(for: LanguageModelRequest(messages: [AIMessage(role: .assistant, content: [.toolCall(AIToolCall(id: "search-call", name: toolName, arguments: "{}", providerExecuted: true)), .toolResult(AIToolResult(toolCallID: "search-call", toolName: toolName, result: output, providerExecuted: true, providerMetadata: ["anthropic": ["cacheControl": ["type": "ephemeral"]]]))])]), modelID: "claude-haiku-4-5", providerID: "anthropic.messages")
        let result = prepared.body["messages"]?[0]?["content"]?.arrayValue?.first { $0["type"] == "tool_search_tool_result" }
        #expect(result?["content"] == ["type": "tool_search_tool_result_error", "error_code": .string(outputType == "default-error" ? "unavailable" : "invalid_tool_input")])
        #expect(result?["cache_control"] == ["type": "ephemeral"])
        #expect(prepared.warnings.isEmpty)
    }

    @Test func requestHeaderTransformReceivesMergedHeadersAndOptionsForBothModes() async throws {
        let transport = RecordingTransport(responses: [response, try stream()])
        let model = AnthropicLanguageModel(modelID: "claude-haiku-4-5", config: ModelHTTPConfig(providerID: "anthropic.messages", baseURL: "https://api.anthropic.com/v1", headers: ["x-config": "config"], transport: transport), transformRequestHeaders: { headers, options in
            await Task.yield()
            var transformed = headers
            transformed["x-merged"] = "\(headers["x-config"] ?? "missing")/\(headers["x-request"] ?? "missing")"
            transformed["x-option"] = options["custom"]?["label"]?.stringValue
            return transformed
        })
        let request = LanguageModelRequest(messages: [.user("Hello")], tools: tools, providerOptions: ["custom": ["label": "hello"]], headers: ["x-request": "request"])
        _ = try await model.generate(request)
        for try await _ in model.stream(request) {}
        for sent in await transport.requests() {
            #expect(sent.headers["x-merged"] == "config/request")
            #expect(sent.headers["x-option"] == "hello")
            #expect(sent.headers["anthropic-beta"]?.contains("structured-outputs-2025-11-13") == true)
            #expect(sent.headers["content-type"] == "application/json")
        }
    }

    @Test(arguments: ["anthropic.claude-3-7-sonnet-20250219-v1:0", "anthropic.claude-sonnet-4-20250514-v1:0", "us.anthropic.claude-opus-4-1-20250805-v1:0", "anthropic.claude-sonnet-4-5-20250929-v1:0", "anthropic.claude-opus-4-6-v1", "meta.llama3-70b-instruct-v1:0", "arn:aws:bedrock:us-east-1:123456789012:application-inference-profile/custom"])
    func bedrockPreservesKnownAndOpaqueNativeSupport(_ modelID: String) {
        #expect(bedrockSupportsStrictToolSpec(modelID: modelID))
        #expect(bedrockSupportsNativeStructuredOutput(modelID: modelID))
    }

    @Test(arguments: ["anthropic.claude-sonnet-4-6-v1", "anthropic.claude-haiku-4-5-20251001-v1:0"])
    func bedrockStrictToolsRemainAvailableWhenNativeOutputIsUnreliable(_ modelID: String) {
        #expect(bedrockSupportsStrictToolSpec(modelID: modelID))
        #expect(!bedrockSupportsNativeStructuredOutput(modelID: modelID))
    }

    @Test(arguments: ["anthropic.claude-opus-4-7", "anthropic.claude-opus-5", "anthropic.claude-sonnet-5-5", "us.anthropic.claude-opus-6-v1:0", "global.anthropic.claude-future-v1:0", "anthropic.claude-opus-4-60-v1"])
    func bedrockUnknownClaudeModelsDoNotReceiveUnsupportedStrictFields(_ modelID: String) {
        #expect(!bedrockSupportsStrictToolSpec(modelID: modelID))
        #expect(!bedrockSupportsNativeStructuredOutput(modelID: modelID))
    }

    @Test(arguments: ["us.anthropic.claude-opus-6-v1:0", "us.anthropic.claude-opus-4-9-v1:0"], [false, true])
    func bedrockFutureClaudeUsesJSONInstructionsWithoutSyntheticTools(_ modelID: String, _ withTools: Bool) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"output":{"message":{"content":[{"text":"{\"name\":\"Test\"}"}]}},"stopReason":"end_turn","usage":{"inputTokens":1,"outputTokens":1}}"#))
        let model = try AIProviders.amazonBedrock(settings: AmazonBedrockProviderSettings(region: "us-east-1", apiKey: "key", transport: transport)).languageModel(modelID)
        let result = try await model.generate(LanguageModelRequest(messages: [.user("Return a name")], responseFormat: .json(schema: schema), tools: withTools ? ["lookup": ["type": "object", "properties": [:], "additionalProperties": false, "strict": true]] : [:]))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["additionalModelRequestFields"]?["output_config"]?["format"] == nil)
        #expect(body["system"]?.arrayValue?.contains { $0["text"]?.stringValue?.contains("You MUST answer with only a JSON object") == true } == true)
        #expect(body["toolConfig"]?["tools"]?.arrayValue?.count == (withTools ? 1 : nil))
        #expect(body["toolConfig"]?["tools"]?[0]?["toolSpec"]?["strict"] == nil)
        #expect(result.text == #"{"name":"Test"}"#)
    }

    @Test func anthropicAWSInheritsCitationsAndNoneChoiceWithSignedRequests() async throws {
        let responseValue: JSONValue = ["content": [["type": "text", "text": "Answer", "citations": .array([weeklyAnthropicCitations[3]])]], "usage": ["input_tokens": 1, "output_tokens": 1]]
        let transport = RecordingTransport(response: jsonResponse(try json(responseValue)))
        let model = try AIProviders.anthropicAWS(settings: AnthropicAWSProviderSettings(region: "us-east-1", workspaceID: "workspace", accessKeyID: "access", secretAccessKey: "secret", transport: transport)).languageModel("claude-haiku-4-5")
        let result = try await model.generate(LanguageModelRequest(messages: [.user("Hello")], tools: tools, toolChoice: ["type": "none"]))
        let sent = try #require(await transport.requests().first)
        let body = try decodeJSONBody(try #require(sent.body))
        #expect(body["tools"]?.arrayValue?.count == 2)
        #expect(body["tool_choice"] == ["type": "none"])
        #expect(result.citations.count == 1)
        #expect(sent.headers["authorization"]?.hasPrefix("AWS4-HMAC-SHA256") == true)
    }

    @Test(arguments: [false, true])
    func fetchedDocumentsResolveCitationsAcrossDirectAndBedrockStreams(_ useBedrock: Bool) async throws {
        let citation: JSONValue = ["type": "char_location", "cited_text": "passage", "document_index": 0, "document_title": .null, "start_char_index": 0, "end_char_index": 7]
        let fetch: JSONValue = ["type": "web_fetch_tool_result", "tool_use_id": "fetch", "content": ["type": "web_fetch_result", "url": "https://example.com/report", "retrieved_at": .null, "content": ["type": "document", "title": "Fetched report", "source": ["type": "text", "media_type": "text/plain", "data": "passage"]]]]
        let events: [JSONValue] = [
            ["type": "message_start", "message": ["id": "message", "usage": ["input_tokens": 1, "output_tokens": 0]]],
            ["type": "content_block_start", "index": 0, "content_block": ["type": "server_tool_use", "id": "fetch", "name": "web_fetch", "input": ["url": "https://example.com/report"]]],
            ["type": "content_block_stop", "index": 0],
            ["type": "content_block_start", "index": 1, "content_block": fetch],
            ["type": "content_block_stop", "index": 1],
            ["type": "content_block_start", "index": 2, "content_block": ["type": "text", "text": ""]],
            ["type": "content_block_delta", "index": 2, "delta": ["type": "text_delta", "text": "Answer"]],
            ["type": "content_block_delta", "index": 2, "delta": ["type": "citations_delta", "citation": citation]],
            ["type": "content_block_stop", "index": 2],
            ["type": "message_delta", "delta": ["stop_reason": "end_turn"], "usage": ["output_tokens": 1]],
            ["type": "message_stop"]
        ]
        let streamResponse: AIHTTPResponse
        if useBedrock {
            streamResponse = amazonEventStreamResponse(try events.map { event in
                (eventType: "chunk", payload: try json(["bytes": .string(try encodeJSONBody(event).base64EncodedString())]))
            })
        } else {
            streamResponse = sseResponse(try events.map { "data: \(try json($0))\n\n" }.joined())
        }
        let generated: JSONValue = ["content": [["type": "server_tool_use", "id": "fetch", "name": "web_fetch", "input": [:]], fetch, ["type": "text", "text": "Answer", "citations": .array([citation])]], "usage": ["input_tokens": 1, "output_tokens": 1]]
        let transport = RecordingTransport(responses: [jsonResponse(try json(generated)), streamResponse])
        let model: any LanguageModel
        if useBedrock {
            model = try AIProviders.amazonBedrockAnthropic(settings: AmazonBedrockProviderSettings(region: "us-east-1", apiKey: "key", transport: transport)).messages("anthropic.claude-haiku-4-5-20251001-v1:0")
        } else {
            model = try AIProviders.anthropic(settings: ProviderSettings(apiKey: "key", transport: transport)).languageModel("claude-haiku-4-5")
        }
        let result = try await model.generate(LanguageModelRequest(messages: [.user("Fetch")]))
        var citations: [AICitation] = []
        var sources: [AISource] = []
        for try await part in model.stream(LanguageModelRequest(messages: [.user("Fetch")])) {
            citations += part.citations
            if case let .source(source) = part { sources.append(source) }
        }
        #expect(citations == result.citations)
        #expect(citations.first?.source.title == "Fetched report")
        #expect(citations.first?.source.mediaType == "text/plain")
        #expect(sources.count == 1 && sources.first?.title == "Fetched report")
    }

    private func json(_ value: JSONValue) throws -> String { String(decoding: try encodeJSONBody(value), as: UTF8.self) }

    private func stream(citation: JSONValue? = nil, laterResult: JSONValue? = nil) throws -> AIHTTPResponse {
        var events: [JSONValue] = [["type": "message_start", "message": ["id": "message", "usage": ["input_tokens": 1, "output_tokens": 0]]], ["type": "content_block_start", "index": 0, "content_block": ["type": "text", "text": ""]], ["type": "content_block_delta", "index": 0, "delta": ["type": "text_delta", "text": "Answer"]]]
        if let citation { events.append(["type": "content_block_delta", "index": 0, "delta": ["type": "citations_delta", "citation": citation]]) }
        events.append(["type": "content_block_stop", "index": 0])
        if let laterResult { events.append(["type": "content_block_start", "index": 1, "content_block": laterResult]) }
        events += [["type": "message_delta", "delta": ["stop_reason": "end_turn"], "usage": ["output_tokens": 1]], ["type": "message_stop"]]
        return sseResponse(try events.map { "data: \(try json($0))\n\n" }.joined())
    }
}
