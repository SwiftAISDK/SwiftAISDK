import Foundation
import Testing
@testable import SwiftAISDK

@Suite("WeeklyOpenAI20261018")
struct WeeklyOpenAI20261018Tests {
    private let response = jsonResponse(#"{"id":"resp","status":"completed","output_text":"ok"}"#)
    private let functionDefinition: JSONValue = [
        "type": "function", "name": "list_issues", "description": "List issues",
        "parameters": ["type": "object", "properties": [:], "additionalProperties": false], "strict": true
    ]

    @Test(arguments: ["openai", "azure"])
    func additionalToolsFollowOrdinaryResultsAtEachInsertionPoint(_ provider: String) throws {
        let first = AIToolResult(toolCallID: "search-1", toolName: "search", result: ["type": "json", "value": [["connection": "github"]]],
                                 providerMetadata: [provider: ["additionalTools": .array([functionDefinition])]])
        let second = AIToolResult(toolCallID: "other", toolName: "other", result: ["type": "text", "value": "other result"])
        var warnings: [AIWarning] = []
        var approvals: Set<String> = []
        let message = AIMessage(role: .tool, content: [.toolResult(first), .toolResult(second), .toolResult(first)])
        let input = try openAIResponsesInputMessageJSON(message, store: false, processedApprovalIDs: &approvals, providerID: provider, warnings: &warnings)
        #expect(input.map { $0["type"] } == ["function_call_output", "additional_tools", "function_call_output", "function_call_output", "additional_tools"])
        #expect(input[1] == ["type": "additional_tools", "role": "developer", "tools": .array([functionDefinition])])
        #expect(input[0]["output"]?.stringValue == #"[{"connection":"github"}]"#)
        #expect(input[2]["output"] == "other result")
        #expect(input[1] == input[4])
        #expect(warnings.isEmpty)
    }

    @Test func additionalToolsRejectMalformedStrictDefinitionsAndIgnoreEmptyLists() throws {
        let malformed: [JSONValue] = [
            .null, "invalid", [["type": "function", "name": "missing_parameters"]],
            [["type": "function", "name": "", "parameters": [:]]],
            [["type": "function", "name": "f", "parameters": [:], "strict": "yes"]],
            [["type": "function", "name": "f", "parameters": [:], "unsupported": true]]
        ]
        for value in malformed {
            let result = AIToolResult(toolCallID: "call", toolName: "search", result: "ok", providerMetadata: ["openai": ["additionalTools": value]])
            #expect(throws: AIError.self) { try openAIResponsesAdditionalTools(result, providerID: "openai") }
        }
        let empty = AIToolResult(toolCallID: "call", toolName: "search", result: "ok", providerMetadata: ["openai": ["additionalTools": []]])
        #expect(try openAIResponsesAdditionalTools(empty, providerID: "openai") == [])
    }

    @Test func azureUsesItsOwnAdditionalToolsAndCitationMetadataNamespace() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"id":"resp","status":"completed","output":[{"type":"message","id":"msg","content":[{"type":"output_text","text":"Answer","annotations":[{"type":"file_citation","file_id":"file-1","filename":"one.pdf","index":0}]}]}]}"#))
        let model = try AIProviders.azure(resourceName: "test-resource", settings: .init(apiKey: "key", transport: transport)).languageModel("gpt-4.1")
        let history = AIToolResult(toolCallID: "call", toolName: "search", result: "ok", providerMetadata: ["azure": ["additionalTools": .array([functionDefinition])]])
        let result = try await model.generate(.init(messages: [AIMessage(role: .tool, content: [.toolResult(history)])]))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["input"]?[1] == ["type": "additional_tools", "role": "developer", "tools": .array([functionDefinition])])
        #expect(result.content.flatMap(\.citations).first?.source.providerMetadata["azure"]?["fileId"] == "file-1")
        #expect(result.sources.first?.providerMetadata["azure"]?["type"] == "file_citation")
    }

    @Test func historyLoadedFunctionsAreOmittedButRemainValidForCallParsing() async throws {
        let tools: [String: JSONValue] = [
            "search": ["type": "object"],
            "list_issues": ["type": "object", "providerOptions": ["openai": ["omitFromRequestTools": true, "outputSchema": ["type": "object"]]]]
        ]
        let prepared = try openAIResponsesTools(from: tools)
        #expect(prepared.tools.map { $0["name"] } == ["search"])
        #expect(prepared.outputSchemaToolNames.contains("list_issues"))
        #expect(openAIResponsesFunctionToolNames(from: tools).contains("list_issues"))
        let transport = RecordingTransport(response: response)
        let model = try AIProviders.openAI(settings: .init(apiKey: "key", transport: transport)).languageModel("gpt-4.1")
        await #expect(throws: AIError.self) {
            _ = try await model.generate(.init(messages: [.user("Issues")], tools: tools, toolChoice: ["type": "tool", "toolName": "list_issues"]))
        }
        #expect(await transport.requests().isEmpty)
        var warnings: [AIWarning] = []
        let allowed = try openAIResponsesAllowedToolsChoice(from: ["toolNames": ["search", "list_issues"]], tools: tools, warnings: &warnings)
        #expect(allowed["tools"] == [["type": "function", "name": "search"]])
        #expect(warnings.first?.message?.contains("omitted from the request") == true)
        #expect(throws: AIError.self) {
            try openAIResponsesAllowedToolsChoice(from: ["toolNames": ["list_issues"]], tools: tools, warnings: &warnings)
        }
    }

    @Test func onlyHistoryLoadedFunctionsSendAnEmptyToolsArray() async throws {
        let transport = RecordingTransport(response: response)
        let model = try AIProviders.openAI(settings: .init(apiKey: "key", transport: transport)).languageModel("gpt-4.1")
        _ = try await model.generate(.init(messages: [.user("Issues")], tools: ["loaded": ["type": "object", "providerOptions": ["openai": ["omitFromRequestTools": true]]]], toolChoice: "auto"))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["tools"] == [])
        #expect(body["tool_choice"] == "auto")
    }

    @Test(arguments: [false, true])
    func prunedReasoningReplaysAssistantContentInsteadOfAnInvalidReference(_ includeReasoning: Bool) async throws {
        let transport = RecordingTransport(response: response)
        let model = try AIProviders.openAI(settings: .init(apiKey: "key", transport: transport)).languageModel("gpt-5-mini")
        var content: [AIContentPart] = includeReasoning ? [.reasoning("Thinking", providerMetadata: ["openai": ["itemId": "rs_1"]])] : []
        content += [.text("Hello", providerMetadata: ["openai": ["itemId": "msg_1"]]), .text("Again", providerMetadata: ["openai": ["itemId": "msg_1"]])]
        _ = try await model.generate(.init(messages: [AIMessage(role: .assistant, content: content)]))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        if includeReasoning {
            #expect(body["input"] == [["type": "item_reference", "id": "rs_1"], ["type": "item_reference", "id": "msg_1"]])
        } else {
            #expect(body["input"] == [["role": "assistant", "content": "Hello"], ["role": "assistant", "content": "Again"]])
        }
    }

    @Test(arguments: ["search", "openPage", "findInPage"])
    func webSearchHistoryReconstructsStorageDisabledActions(_ actionType: String) async throws {
        let action: JSONValue = actionType == "search"
            ? ["type": "search", "queries": ["news"], "query": "news"]
            : ["type": .string(actionType), "url": "https://example.com", "pattern": "news"]
        let result = AIToolResult(toolCallID: "search-call", toolName: "news", result: ["type": "json", "value": ["action": action, "sources": [["type": "url", "url": "https://example.com"]]]], providerMetadata: ["openai": ["itemId": "ws_1"]])
        for store in [false, true] {
            let transport = RecordingTransport(response: response)
            let model = try AIProviders.openAI(settings: .init(apiKey: "key", transport: transport)).languageModel("gpt-4.1")
            let generated = try await model.generate(.init(messages: [AIMessage(role: .assistant, content: [.toolResult(result)])], tools: ["news": ["type": "provider", "id": "openai.web_search", "name": "news", "args": [:]]], providerOptions: ["openai": ["store": .bool(store)]]))
            let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
            #expect(body["input"]?[0]?["id"] == "ws_1")
            #expect(body["input"]?[0]?["type"] == (store ? "item_reference" : "web_search_call"))
            if !store {
                let expected = actionType == "openPage" ? "open_page" : actionType == "findInPage" ? "find_in_page" : "search"
                #expect(body["input"]?[0]?["action"]?["type"] == .string(expected))
            }
            #expect(generated.warnings.isEmpty)
        }
    }

    @Test func webSearchMalformedHistoryRetainsTheCompatibilityWarning() async throws {
        let transport = RecordingTransport(response: response)
        let model = try AIProviders.openAI(settings: .init(apiKey: "key", transport: transport)).languageModel("gpt-4.1")
        let result = try await model.generate(.init(messages: [AIMessage(role: .assistant, content: [.toolResult(AIToolResult(toolCallID: "ws", toolName: "web_search", result: ["sources": []]))])], providerOptions: ["openai": ["store": false]]))
        #expect(result.warnings.contains { $0.message?.contains("not sent to the API") == true })
    }

    @Test(arguments: ["web_search_call", "file_search_call"])
    func citationsRemainAttachedWhileRetrievedSourcesAreSeparate(_ retrievalType: String) async throws {
        let annotation: JSONValue = retrievalType == "web_search_call"
            ? ["type": "url_citation", "url": "https://example.com/cited", "title": "Cited", "start_index": 2, "end_index": 6]
            : ["type": "file_citation", "file_id": "cited-file", "filename": "cited.pdf", "index": 0]
        let retrieval: JSONValue = retrievalType == "web_search_call"
            ? ["type": "web_search_call", "id": "ws", "status": "completed", "action": ["type": "search", "query": "question", "sources": [["type": "url", "url": "https://example.com/retrieved"]]]]
            : ["type": "file_search_call", "id": "fs", "status": "completed", "queries": ["question"], "results": [
                ["file_id": "retrieved-file", "filename": "retrieved.pdf", "attributes": [:], "score": 1, "text": "One"],
                ["file_id": "retrieved-file", "filename": "retrieved.pdf", "attributes": [:], "score": 0.9, "text": "Two"]]]
        let message: JSONValue = ["type": "message", "id": "msg", "role": "assistant", "content": [["type": "output_text", "text": "Answer", "annotations": .array([annotation])]]]
        let raw: JSONValue = ["id": "resp", "status": "completed", "output": .array([message, retrieval])]
        let transport = RecordingTransport(response: jsonResponse(String(decoding: try encodeJSONBody(raw), as: UTF8.self)))
        let model = try AIProviders.openAI(settings: .init(apiKey: "key", transport: transport)).languageModel("gpt-4.1")
        let result = try await model.generate(.init(messages: [.user("Answer")]))
        #expect(result.sources.count == 1)
        #expect(result.sources.first?.url == (retrievalType == "web_search_call" ? "https://example.com/retrieved" : nil))
        #expect(result.content.flatMap(\.citations).count == 1)
        let citation = try #require(result.content.flatMap(\.citations).first)
        #expect(citation.source.id == (retrievalType == "web_search_call" ? "https://example.com/cited" : "cited-file"))
        #expect(citation.startIndex == (retrievalType == "web_search_call" ? 2 : nil))
        if case let .citedText(_, _, metadata) = result.content.first {
            #expect(metadata["openai"]?["annotations"] == .array([annotation]))
        } else { Issue.record("Missing text citation metadata") }
        if retrievalType == "file_search_call" { #expect(result.sources.first?.providerMetadata["openai"]?["type"] == "file_search") }

        // Retrieval deliberately arrives after the completed text block.
        let events: [JSONValue] = [
            ["type": "response.output_item.added", "output_index": 0, "item": ["type": "message", "id": "msg"]],
            ["type": "response.output_text.annotation.added", "annotation": annotation],
            ["type": "response.output_item.done", "output_index": 0, "item": ["type": "message", "id": "msg"]],
            ["type": "response.output_item.done", "output_index": 1, "item": retrieval]
        ]
        let parts = try await stream(events)
        let sources = parts.compactMap { if case let .source(source) = $0 { source } else { nil } }
        #expect(sources.count == 1)
        #expect(sources.first?.url == result.sources.first?.url)
        #expect(sources.first?.filename == result.sources.first?.filename)
        #expect(parts.flatMap(\.citations) == [citation])
        let textEndMetadata = parts.compactMap { part -> [String: JSONValue]? in
            if case let .textEndWithCitations(_, _, metadata) = part { metadata } else { nil }
        }.first
        #expect(textEndMetadata?["openai"]?["annotations"] == .array([annotation]))
    }

    @Test func citationsKeepUTF16OffsetsAndSeparateTextBlocksAndExcludeFilePaths() async throws {
        let annotations: [JSONValue] = [
            ["type": "url_citation", "url": "https://example.com/first", "title": "Café", "start_index": 2, "end_index": 6],
            ["type": "container_file_citation", "file_id": "file-2", "filename": "two.txt", "container_id": "container", "start_index": 12, "end_index": 16],
            ["type": "file_path", "file_id": "output", "index": 0]
        ]
        var events: [JSONValue] = []
        for (index, annotation) in annotations.enumerated() {
            events += [
                ["type": "response.output_item.added", "output_index": .number(Double(index)), "item": ["type": "message", "id": .string("msg-\(index)")]],
                ["type": "response.output_text.annotation.added", "annotation": annotation],
                ["type": "response.output_item.done", "output_index": .number(Double(index)), "item": ["type": "message", "id": .string("msg-\(index)")]]
            ]
        }
        let parts = try await stream(events)
        let citations = parts.flatMap(\.citations)
        #expect(citations.map(\.startIndex) == [2, 12])
        #expect(citations.map(\.endIndex) == [6, 16])
        #expect(citations.map(\.source.id) == ["https://example.com/first", "file-2"])
        #expect(parts.compactMap { if case let .source(source) = $0 { source } else { nil } }.count == 3)
    }

    @Test func customToolInputStreamingDeclaresTextEncoding() async throws {
        let parts = try await stream([
            ["type": "response.output_item.added", "output_index": 0, "item": ["type": "custom_tool_call", "id": "ct", "call_id": "call", "name": "code", "input": ""]],
            ["type": "response.custom_tool_call_input.delta", "item_id": "ct", "output_index": 0, "delta": "print(1)"],
            ["type": "response.output_item.done", "output_index": 0, "item": ["type": "custom_tool_call", "id": "ct", "call_id": "call", "name": "code", "input": "print(1)"]]
        ])
        #expect(parts.compactMap(\.inputEncoding) == [.text])
        #expect(parts.contains(.toolInputDelta(id: "call", delta: "print(1)")))
        let call = try #require(parts.compactMap { if case let .toolCall(call) = $0 { call } else { nil } }.first)
        #expect(try decodeJSONBody(Data(call.arguments.utf8)) == "print(1)")
    }

    @Test(arguments: ["application/pdf", "image/png", "video/mp4"])
    func compatibleProviderReferencesPreserveConfiguredIdentityAndMetadata(_ mediaType: String) throws {
        let reference = AIContentPart.providerReference(mimeType: mediaType, reference: ["custom-provider": "file-123", "openai": "other"], providerMetadata: ["openaiCompatible": ["customOption": "value"]])
        let message = try OpenAICompatibleChatModel.messageJSON(AIMessage(role: .user, content: [reference]), providerID: "custom-provider.chat")
        #expect(message["content"]?[0] == ["type": "file", "file": ["file_id": "file-123"], "customOption": "value"])
        #expect(throws: AINoSuchProviderReferenceError.self) {
            try OpenAICompatibleChatModel.messageJSON(AIMessage(role: .user, content: [.providerReference(mimeType: mediaType, reference: ["openai": "other"])]), providerID: "custom-provider.chat")
        }
        let toolResult = AIToolResult(toolCallID: "call", toolName: "read", result: ["type": "content", "value": [["type": "file", "mediaType": .string(mediaType), "data": ["type": "reference", "reference": ["custom-provider": "file-123"]], "providerOptions": ["openaiCompatible": ["customOption": "value"]]]]])
        let toolMessage = try OpenAICompatibleChatModel.messageJSON(AIMessage(role: .tool, content: [.toolResult(toolResult)]), providerID: "custom-provider.chat", supportsMultiPartToolContent: true)
        #expect(toolMessage["content"]?[0] == message["content"]?[0])
    }

    @Test(arguments: [false, true])
    func compatibleImagesDownloadMixedURLResultsWithCredentialAndAbortBoundaries(_ editing: Bool) async throws {
        let transport = RecordingTransport(responses: [
            jsonResponse(#"{"data":[{"b64_json":"YWJj"},{"url":"https://api.example.com/image.png"},{"url":"https://cdn.example.com/image.png"}]}"#),
            AIHTTPResponse(statusCode: 200, headers: [:], body: Data("first".utf8)),
            AIHTTPResponse(statusCode: 200, headers: [:], body: Data("second".utf8))
        ])
        let provider = try AIProviders.openAICompatible(name: "custom", baseURL: "https://api.example.com", apiKey: "key", headers: ["X-Provider": "configured"], transport: transport)
        let signal = AIAbortSignal()
        let result = try await provider.imageModel("image-model").generateImage(.init(prompt: "Cat", files: editing ? [.init(data: Data([1]), mediaType: "image/png")] : [], headers: ["X-Request": "value"], abortSignal: signal))
        #expect(result.base64Images == ["YWJj", Data("first".utf8).base64EncodedString(), Data("second".utf8).base64EncodedString()])
        let requests = await transport.requests()
        #expect(requests.count == 3)
        #expect(requests[0].url.path == (editing ? "/images/edits" : "/images/generations"))
        #expect(requests[1].headers["authorization"] == "Bearer key")
        #expect(requests[1].headers["x-provider"] == "configured")
        #expect(normalizeHeaders(requests[1].headers)["x-request"] == "value")
        #expect(requests[2].headers["authorization"] == nil)
        #expect(requests[2].headers["x-provider"] == nil)
        #expect(requests[1].abortSignal === signal)
        #expect(requests[2].abortSignal === signal)
    }

    @Test func compatibleImagesRejectMissingImageDataBeforeDownloading() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"data":[{}]}"#))
        let provider = try AIProviders.openAICompatible(name: "custom", baseURL: "https://api.example.com", apiKey: "key", transport: transport)
        await #expect(throws: AIError.self) { _ = try await provider.imageModel("image").generateImage(.init(prompt: "Cat")) }
        #expect(await transport.requests().count == 1)
    }

    @Test func compatibleImagesPreferBase64AndPreserveItWithoutDownloads() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"data":[{"b64_json":"AQID","url":"https://example.com/unused.png"}]}"#))
        let provider = try AIProviders.openAICompatible(name: "custom", baseURL: "https://api.example.com", apiKey: "key", transport: transport)
        #expect(try await provider.imageModel("image").generateImage(.init(prompt: "Cat")).base64Images == ["AQID"])
        #expect(await transport.requests().count == 1)
    }

    @Test(arguments: [false, true])
    func compatibleImagesRejectPrivateURLsAndRedirectsBeforeFetching(_ redirected: Bool) async throws {
        let firstURL = redirected ? "https://cdn.example.com/image.png" : "http://127.0.0.1/image.png"
        let transport = RecordingTransport(responses: [
            jsonResponse("{\"data\":[{\"url\":\"\(firstURL)\"}]}"),
            AIHTTPResponse(statusCode: 302, headers: ["location": "http://127.0.0.1/image.png"], body: Data())
        ])
        let provider = try AIProviders.openAICompatible(name: "custom", baseURL: "https://api.example.com", apiKey: "key", transport: transport)
        do {
            _ = try await provider.imageModel("image").generateImage(.init(prompt: "Cat"))
            Issue.record("Expected private download URL rejection")
        } catch let AIError.invalidArgument(argument, message) {
            #expect(argument == "url")
            #expect(message.contains("127.0.0.1"))
        }
        #expect(await transport.requests().count == (redirected ? 2 : 1))
    }

    @Test func compatibleImagesAllowConfiguredSelfHostedOriginAndStripRedirectCredentials() async throws {
        let transport = RecordingTransport(responses: [
            jsonResponse(#"{"data":[{"url":"http://127.0.0.1:8000/image.png"}]}"#),
            AIHTTPResponse(statusCode: 302, headers: ["location": "https://cdn.example.com/image.png"], body: Data()),
            AIHTTPResponse(statusCode: 200, headers: [:], body: Data([1, 2, 3]))
        ])
        let provider = try AIProviders.openAICompatible(name: "custom", baseURL: "http://127.0.0.1:8000", apiKey: "key", transport: transport)
        let result = try await provider.imageModel("image").generateImage(.init(prompt: "Cat", headers: ["x-api-key": "custom-key"]))
        #expect(result.base64Images == ["AQID"])
        let requests = await transport.requests()
        #expect(requests[1].headers["authorization"] == "Bearer key")
        #expect(requests[1].headers["x-api-key"] == "custom-key")
        #expect(requests[2].headers["authorization"] == nil)
        #expect(requests[2].headers["x-api-key"] == nil)
    }

    @Test func compatibleImagesPropagateDownloadStatusErrors() async throws {
        let transport = RecordingTransport(responses: [jsonResponse(#"{"data":[{"url":"https://cdn.example.com/image.png"}]}"#), AIHTTPResponse(statusCode: 404, headers: [:], body: Data("Not found".utf8))])
        let provider = try AIProviders.openAICompatible(name: "custom", baseURL: "https://api.example.com", apiKey: "key", transport: transport)
        do {
            _ = try await provider.imageModel("image").generateImage(.init(prompt: "Cat"))
            Issue.record("Expected failed image download")
        } catch {
            #expect((error as? AIError)?.apiCallError?.statusCode == 404)
        }
    }

    @Test func compatibleImagesPropagateCancellationDuringDownload() async throws {
        let controller = AIAbortController()
        let transport = WeeklyOpenAIImageAbortTransport(controller: controller)
        let provider = try AIProviders.openAICompatible(name: "custom", baseURL: "https://api.example.com", apiKey: "key", transport: transport)
        await #expect(throws: AIAbortError.self) { _ = try await provider.imageModel("image").generateImage(.init(prompt: "Cat", abortSignal: controller.signal)) }
        #expect(controller.signal.isAborted)
    }

    @Test(arguments: ["openai/gpt-oss-240b", "future/browser-model", "new-model"])
    func groqFutureModelsKeepBrowserAndFunctionTools(_ modelID: String) {
        let tools = groqTools(from: ["browser": GroqTools.browserSearch(), "weather": ["type": "object"]], modelID: modelID)
        #expect(tools.tools.count == 2)
        #expect(tools.warnings.isEmpty)
        let legacy = groqTools(from: ["browser": GroqTools.browserSearch()], modelID: "gemma2-9b-it")
        #expect(legacy.tools.isEmpty)
        #expect(legacy.warnings.first?.message == "Browser search is not supported on model gemma2-9b-it.")
    }

    @Test(arguments: ["magistral-large-latest", "mistral-large-5", "future-reasoning-model"])
    func mistralFutureModelsForwardReasoningAndProviderOverrides(_ modelID: String) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"ok"},"finish_reason":"stop"}]}"#))
        let model = try AIProviders.mistral(settings: .init(apiKey: "key", transport: transport)).languageModel(modelID)
        for override in [false, true] {
            let result = try await model.generate(.init(messages: [.user("Answer")], reasoning: "high", providerOptions: override ? ["mistral": ["reasoningEffort": "none"]] : [:]))
            let body = try decodeJSONBody(try #require(await transport.requests().last?.body))
            #expect(body["reasoning_effort"] == (override ? "none" : "high"))
            #expect(!result.warnings.contains { $0.feature == "reasoning" })
        }
        #expect(!mistralSupportsReasoningEffort("mistral-large-latest"))
    }

    @Test(arguments: ["moonshot-v1-8k", "moonshot-v1-custom", "custom-model-id"])
    func moonshotAllModelsSendStructuredOutputSchemas(_ modelID: String) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"{}"},"finish_reason":"stop"}]}"#))
        let model = try AIProviders.moonshotAI(settings: .init(apiKey: "key", transport: transport)).languageModel(modelID)
        let result = try await model.generate(.init(messages: [.user("JSON")], responseFormat: .json(schema: ["type": "object"])))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["response_format"]?["type"] == "json_schema")
        #expect(result.warnings.isEmpty)
    }

    @Test(arguments: ["deepseek-v5-pro", "deepseek-v10-flash", "deepseek-next", "provider/deepseek-v5-pro"])
    func deepSeekFutureIDsUseCurrentReasoningProtocol(_ modelID: String) async throws {
        #expect(deepSeekIsV4Model(modelID))
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"ok"},"finish_reason":"stop"}]}"#))
        let model = try AIProviders.deepSeek(settings: .init(apiKey: "key", transport: transport)).languageModel(modelID)
        _ = try await model.generate(.init(messages: [.assistant("Earlier"), .user("Continue"), .assistant("Last")]))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["messages"]?[0]?["reasoning_content"] == "")
        #expect(body["messages"]?[2]?["reasoning_content"] == "")
    }

    @Test(arguments: ["deepseek-chat", "deepseek-reasoner", "deepseek-v3.2", "provider/deepseek-v2.5", "foo.deepseek-v3.2-exp"])
    func deepSeekLegacyIDsRetainTheOldProtocol(_ modelID: String) {
        #expect(!deepSeekIsV4Model(modelID))
    }

    private func stream(_ events: [JSONValue]) async throws -> [LanguageStreamPart] {
        let sse = try events.map { "data: \(String(decoding: try encodeJSONBody($0), as: UTF8.self))\n\n" }.joined()
        let transport = RecordingTransport(response: sseResponse(sse))
        let model = try AIProviders.openAI(settings: .init(apiKey: "key", transport: transport)).languageModel("gpt-4.1")
        var parts: [LanguageStreamPart] = []
        for try await part in model.stream(.init(messages: [.user("Answer")])) { parts.append(part) }
        return parts
    }
}

private actor WeeklyOpenAIImageAbortTransport: FixtureDownloadTransport {
    let controller: AIAbortController
    init(controller: AIAbortController) { self.controller = controller }
    func send(_ request: AIHTTPRequest) async throws -> AIHTTPResponse {
        if request.method == "GET" {
            controller.abort(reason: "Cancelled image download")
            try request.abortSignal?.throwIfAborted()
        }
        return jsonResponse(#"{"data":[{"url":"https://cdn.example.com/image.png"}]}"#)
    }
}
