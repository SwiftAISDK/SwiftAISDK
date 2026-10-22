import Foundation
import Testing
@testable import SwiftAISDK

@Suite("WeeklyOpenAI20261023")
struct WeeklyOpenAI20261023Tests {
    @Test(arguments: [false, true], ["responses", "chat", "completion"])
    func azureSeparatesDeploymentRoutingFromModelCapabilities(_ deploymentURLs: Bool, _ surface: String) async throws {
        let raw: JSONValue = surface == "responses"
            ? ["id": "response", "model": "returned-model", "status": "completed", "output": [["type": "message", "id": "msg", "role": "assistant", "content": [["type": "output_text", "text": "ok"]]]]]
            : ["id": "response", "model": "returned-model", "choices": [["index": 0, "text": "ok", "message": ["content": "ok"], "finish_reason": "stop"]]]
        let streamEvent: JSONValue = surface == "responses"
            ? ["type": "response.completed", "response": raw]
            : ["id": "response", "model": "returned-model", "choices": [["index": 0, "text": "ok", "delta": ["content": "ok"], "finish_reason": "stop"]]]
        let transport = RecordingTransport(responses: [try response(raw), try events([streamEvent])])
        let provider = try AIProviders.azure(resourceName: "test-resource", useDeploymentBasedURLs: deploymentURLs, settings: .init(apiKey: "key", transport: transport))
        let settings = AzureOpenAILanguageModelSettings(modelID: "gpt-5")
        let model: any LanguageModel = switch surface {
        case "chat": try provider.chat("production-deployment", settings: settings)
        case "completion": try provider.completion("production-deployment", settings: settings)
        default: try provider.responses("production-deployment", settings: settings)
        }
        #expect(model.modelID == "gpt-5")
        let request = LanguageModelRequest(messages: [.system("Be helpful"), .user("Hello")], temperature: 0.5)
        let result = try await model.generate(request)
        #expect(result.responseMetadata.modelID == "returned-model")
        for try await _ in model.stream(request) {}
        let requests = await transport.requests()
        #expect(requests.count == 2)
        for (index, sent) in requests.enumerated() {
            let body = try decodeJSONBody(try #require(sent.body))
            #expect(body["model"] == "production-deployment")
            #expect(body["stream"] == (index == 1 ? true : nil))
            #expect(sent.url.path.contains(deploymentURLs ? "/deployments/production-deployment/" : "/v1/"))
            #expect(!sent.url.path.contains("gpt-5"))
            #expect(sent.headers["api-key"] == "key")
            if surface == "completion" {
                #expect(body["temperature"] == 0.5)
            } else {
                #expect(body["temperature"] == nil)
                #expect(body[surface == "chat" ? "messages" : "input"]?[0]?["role"] == "developer")
            }
        }
    }

    @Test func azureAliasesAndEmptySettingsPreserveDeploymentIdentity() throws {
        let provider = try AIProviders.azure(resourceName: "test-resource", settings: .init(apiKey: "key"))
        let settings = AzureOpenAILanguageModelSettings(modelID: "gpt-5")
        let models = [try provider("deployment", settings: settings), try provider.languageModel("deployment", settings: settings), try provider.chatModel("deployment", settings: settings), try provider.completionModel("deployment", settings: settings)]
        #expect(models.allSatisfy { $0.modelID == "gpt-5" })
        #expect(try provider("deployment").modelID == "deployment")
        #expect(try provider.languageModel("deployment", settings: .init()).modelID == "deployment")
        #expect(try provider.chat("deployment", settings: .init()).modelID == "deployment")
        #expect(try provider.completion("deployment", settings: .init()).modelID == "deployment")
    }

    @Test(arguments: [false, true])
    func responsesPrewarmPreservesCacheUsageWithNoOutput(_ streaming: Bool) async throws {
        let usage: JSONValue = ["input_tokens": 2048, "output_tokens": 0, "total_tokens": 2048, "input_tokens_details": ["cached_tokens": 0, "cache_write_tokens": 2048, "cache_write_tokens_details": ["ttl_30m_tokens": 0, "ttl_12h_tokens": 2048]], "output_tokens_details": ["reasoning_tokens": 0]]
        let raw: JSONValue = ["id": "prewarm", "status": "completed", "model": "gpt-6.1-sol", "output": [], "usage": usage]
        let transport = RecordingTransport(response: try streaming ? events([["type": "response.completed", "response": raw]]) : response(raw))
        let model = try AIProviders.openAI(settings: .init(apiKey: "key", transport: transport)).languageModel("gpt-6.1-sol")
        let breakpoint: JSONValue = ["mode": "explicit", "ttl": "12h"]
        let cache: JSONValue = ["mode": "implicit", "ttl": "12h", "prewarm": true]
        let request = LanguageModelRequest(messages: [.init(role: .user, content: [
            .text("Stable prefix", providerMetadata: ["openai": ["promptCacheBreakpoint": breakpoint]]),
            .text("Uncached suffix", providerMetadata: ["openai": ["promptCacheBreakpoint": .null]])
        ])], providerOptions: ["openai": ["promptCacheOptions": cache]])
        let parsedUsage: TokenUsage?
        if streaming {
            var parts: [LanguageStreamPart] = []
            for try await part in model.stream(request) { parts.append(part) }
            #expect(!parts.contains { part in
                switch part { case .textStart, .textDelta, .textDeltaPart, .error: true; default: false }
            })
            parsedUsage = parts.compactMap { part -> TokenUsage? in
                switch part { case let .finish(_, usage), let .finishMetadata(_, usage, _): usage; default: nil }
            }.last
        } else {
            let result = try await model.generate(request)
            #expect(result.content.isEmpty)
            #expect(result.text.isEmpty)
            #expect(result.warnings.isEmpty)
            parsedUsage = result.usage
        }
        #expect(parsedUsage?.inputTokens == 2048)
        #expect(parsedUsage?.inputTokensNoCache == 0)
        #expect(parsedUsage?.inputTokensCacheRead == 0)
        #expect(parsedUsage?.inputTokensCacheWrite == 2048)
        #expect(parsedUsage?.outputTokens == 0)
        #expect(parsedUsage?.rawValue == usage)
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["prompt_cache_options"] == cache)
        #expect(body["input"]?[0]?["content"]?[0]?["prompt_cache_breakpoint"] == breakpoint)
        #expect(body["input"]?[0]?["content"]?[1]?["prompt_cache_breakpoint"] == nil)
    }

    @Test(arguments: [JSONValue.null, "invalid", ["ttl": "24h"], ["ttl": .null], ["mode": "other"], ["prewarm": "true"]])
    func responsesRejectInvalidPromptCacheOptionsBeforeSending(_ options: JSONValue) async throws {
        let transport = RecordingTransport(response: jsonResponse("{}"))
        let model = try AIProviders.openAI(settings: .init(apiKey: "key", transport: transport)).languageModel("gpt-6.1-sol")
        await #expect(throws: AIError.self) {
            _ = try await model.generate(.init(messages: [.user("Hello")], providerOptions: ["openai": ["promptCacheOptions": options]]))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test(arguments: [false, true], [false, true])
    func shellExecutionControlsSurviveGenerationAndStreaming(_ nullControls: Bool, _ hosted: Bool) async throws {
        let action: JSONValue = ["commands": ["echo hi"], "timeout_ms": nullControls ? .null : 1000, "max_output_length": nullControls ? .null : 10000]
        let call: JSONValue = ["type": "shell_call", "id": "sh_1", "call_id": "call_1", "action": action]
        let output: JSONValue = ["type": "shell_call_output", "id": "sho_1", "call_id": "call_1", "max_output_length": nullControls ? .null : 10000, "output": [["stdout": "hi", "stderr": "", "outcome": ["type": "exit", "exit_code": 0]]]]
        let transport = RecordingTransport(responses: [try response(["id": "response", "status": "completed", "output": .array([call, output])]), try events([
            ["type": "response.output_item.added", "output_index": 0, "item": call],
            ["type": "response.output_item.done", "output_index": 0, "item": call],
            ["type": "response.output_item.done", "output_index": 1, "item": output]
        ])])
        let model = try AIProviders.openAI(settings: .init(apiKey: "key", transport: transport)).languageModel("gpt-5.1")
        var shellTool = try #require(OpenAITools.shell(environment: hosted ? OpenAITools.shellContainerAutoEnvironment() : OpenAITools.shellLocalEnvironment()).objectValue)
        shellTool["name"] = "terminal"
        let request = LanguageModelRequest(messages: [.user("Run")], tools: ["terminal": .object(shellTool)])
        let expectedTimeout: JSONValue? = nullControls ? .none : .number(1000)
        let expectedMaxOutputLength: JSONValue? = nullControls ? .none : .number(10000)
        let result = try await model.generate(request)
        var streamedCalls: [AIToolCall] = []
        var streamedResults: [AIToolResult] = []
        for try await part in model.stream(request) {
            if case let .toolCall(call) = part { streamedCalls.append(call) }
            if case let .toolResult(result) = part { streamedResults.append(result) }
        }
        #expect(result.toolCalls.count == 1)
        #expect(streamedCalls.count == 1)
        for value in result.toolCalls + streamedCalls {
            let input = try decodeJSONBody(Data(value.arguments.utf8))
            #expect(input["action"]?["commands"] == ["echo hi"])
            #expect(input["action"]?["timeoutMs"] == expectedTimeout)
            #expect(input["action"]?["maxOutputLength"] == expectedMaxOutputLength)
            #expect(value.providerExecuted == hosted)
            #expect(value.name == "terminal")
        }
        let generatedResults = result.content.compactMap { if case let .toolResult(result) = $0 { result } else { nil } }
        #expect(generatedResults.count == 1)
        #expect(streamedResults.count == 1)
        for value in generatedResults + streamedResults {
            #expect(value.result["maxOutputLength"] == expectedMaxOutputLength)
            #expect(value.result["output"]?[0]?["outcome"] == ["type": "exit", "exitCode": 0])
            #expect(value.toolName == "terminal")
        }
    }

    @Test(arguments: [false, true], [false, true])
    func shellHistoryRetainsOutputLimit(_ assistant: Bool, _ includeLimit: Bool) async throws {
        var output: [String: JSONValue] = ["output": [["stdout": "hi", "stderr": "", "outcome": ["type": "exit", "exitCode": 0]]]]
        if includeLimit { output["maxOutputLength"] = 10000 }
        let call = AIToolCall(id: "call_1", name: "shell", arguments: #"{"action":{"commands":["echo hi"],"timeoutMs":1000,"maxOutputLength":10000}}"#, providerExecuted: assistant)
        let result = AIToolResult(toolCallID: "call_1", toolName: "shell", result: ["type": "json", "value": .object(output)], providerExecuted: assistant)
        let transport = RecordingTransport(response: jsonResponse(#"{"status":"completed","output_text":"ok","output":[]}"#))
        let model = try AIProviders.openAI(settings: .init(apiKey: "key", transport: transport)).languageModel("gpt-5.1")
        let content: [AIContentPart] = assistant ? [.toolCall(call), .toolResult(result)] : [.toolResult(result)]
        _ = try await model.generate(.init(messages: [.init(role: assistant ? .assistant : .tool, content: content)], tools: ["shell": OpenAITools.shell()], providerOptions: ["openai": ["store": false]]))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        let input = try #require(body["input"]?.arrayValue)
        let shellOutput = try #require(input.first { $0["type"] == "shell_call_output" })
        #expect(shellOutput["max_output_length"] == (includeLimit ? 10000 : nil))
        #expect(shellOutput["output"]?[0]?["outcome"] == ["type": "exit", "exit_code": 0])
        if assistant {
            #expect(input.first?["action"] == ["commands": ["echo hi"], "timeout_ms": 1000, "max_output_length": 10000])
        }
    }

    struct TranscriptionCase: Sendable {
        let language: String?
        let detectedCodes: [String]?
        let expected: String?
    }

    static let transcriptionCases: [TranscriptionCase] = [
        .init(language: "en", detectedCodes: nil, expected: "en"),
        .init(language: "english", detectedCodes: nil, expected: "en"),
        .init(language: "japanese", detectedCodes: nil, expected: "ja"),
        .init(language: "unknown", detectedCodes: nil, expected: nil),
        .init(language: "en-US", detectedCodes: nil, expected: nil),
        .init(language: "constructor", detectedCodes: nil, expected: nil),
        .init(language: "EN", detectedCodes: nil, expected: nil),
        .init(language: nil, detectedCodes: ["ja"], expected: "ja"),
        .init(language: "unknown", detectedCodes: ["ja"], expected: "ja"),
        .init(language: "en", detectedCodes: ["ja"], expected: "en"),
        .init(language: nil, detectedCodes: ["en", "ja"], expected: nil),
        .init(language: nil, detectedCodes: [], expected: nil),
        .init(language: nil, detectedCodes: ["en-US"], expected: nil),
        .init(language: nil, detectedCodes: ["JA"], expected: nil)
    ]

    @Test(arguments: Self.transcriptionCases)
    func transcriptionNormalizesLanguageAndPreservesDetectedLanguages(_ testCase: TranscriptionCase) async throws {
        let language: JSONValue = testCase.language.map(JSONValue.string) ?? .null
        let languages: JSONValue
        if let codes = testCase.detectedCodes {
            languages = .array(codes.map { .object(["code": .string($0)]) })
        } else {
            languages = .null
        }
        let raw: JSONValue = ["text": "Hello", "language": language, "languages": languages]
        let transport = RecordingTransport(response: try response(raw))
        let model = try AIProviders.openAI(settings: .init(apiKey: "key", transport: transport)).transcriptionModel("gpt-4o-transcribe")
        let result = try await model.transcribe(.init(audio: Data([0, 1])))
        let expectedLanguages: JSONValue? = languages == .null ? .none : .some(languages)
        #expect(result.language == testCase.expected)
        #expect(result.providerMetadata["openai"]?["languages"] == expectedLanguages)
    }

    @Test func transcriptionPreservesLanguagesAlongsideDiarizedSegments() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"text":"Hello","languages":[{"code":"en"}],"segments":[{"start":0,"end":1,"text":"Hello","speaker":"speaker_0"}]}"#))
        let model = try AIProviders.openAI(settings: .init(apiKey: "key", transport: transport)).transcriptionModel("gpt-4o-transcribe-diarize")
        let result = try await model.transcribe(.init(audio: Data([0, 1])))
        #expect(result.language == "en")
        #expect(result.providerMetadata["openai"]?["languages"] == [["code": "en"]])
        #expect(result.providerMetadata["openai"]?["segments"] == [["startSecond": 0, "endSecond": 1, "text": "Hello", "speaker": "speaker_0"]])
    }

    @Test(arguments: ["groq", "compatible", "moonshotai"])
    func unaryReasoningPrecedesTextAndTools(_ providerID: String) async throws {
        var message: [String: JSONValue] = ["content": "Answer", "tool_calls": [["id": "call", "type": "function", "function": ["name": "lookup", "arguments": "{}"]]]]
        message[providerID == "moonshotai" ? "reasoning_content" : "reasoning"] = "Think first"
        let raw: JSONValue = ["choices": [["message": .object(message), "finish_reason": "tool_calls"]]]
        let transport = RecordingTransport(response: try response(raw))
        let provider: OpenAICompatibleProvider = switch providerID {
        case "groq": try AIProviders.groq(settings: .init(apiKey: "key", transport: transport))
        case "moonshotai": try AIProviders.moonshotAI(settings: .init(apiKey: "key", transport: transport))
        default: try AIProviders.openAICompatible(name: "test", baseURL: "https://example.com", apiKey: "key", transport: transport)
        }
        let result = try await provider.languageModel("model").generate(.init(messages: [.user("Hi")]))
        #expect(result.content.count == 3)
        #expect(result.content[0] == .reasoning("Think first"))
        let call = try #require(result.toolCalls.first)
        #expect(result.content[providerID == "moonshotai" ? 2 : 1] == .text("Answer"))
        #expect(result.content[providerID == "moonshotai" ? 1 : 2] == .toolCall(call))
    }

    @Test func compatibleSeparateReasoningPrecedesOrderedContentArray() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"reasoning_content":"First","content":[{"type":"text","text":"Answer"},{"type":"thinking","thinking":[{"type":"text","text":"Inline"}]}]},"finish_reason":"stop"}]}"#))
        let provider = try AIProviders.openAICompatible(name: "test", baseURL: "https://example.com", apiKey: "key", transport: transport)
        let result = try await provider.languageModel("model").generate(.init(messages: [.user("Hi")]))
        #expect(result.content == [.reasoning("First"), .text("Answer"), .reasoning("Inline")])
        #expect(result.reasoning == "FirstInline")
    }

    @Test(arguments: ["none", "provider-default", "high"])
    func decisionsWarnForUnsupportedSharedControlsAndOmitInstructions(_ reasoning: String) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"answers":[{"type":"choice","name":"choice","choice":"a","probabilities":[{"value":"a","probability":1}]},{"type":"score","name":"score","score":0,"probabilities":[{"value":0,"probability":1}]},{"type":"predicate","name":"flag","probability":0.5}]}"#))
        let model = try AIProviders.openAI(settings: .init(apiKey: "key", transport: transport)).decisionModel("decision-model")
        let result = try await model.doDecide(.init(state: [], questions: ["choice": .choice(criteria: ["a": .null]), "score": .score(criteria: [.null]), "flag": .boolean(criteria: ["true": "Pass", "false": .null])], maxOutputTokens: 123, reasoning: reasoning, providerOptions: ["openai": ["unknown": true]]))
        #expect(result.warnings.map(\.feature) == ["maxOutputTokens", "reasoning", "providerOptions.openai.unknown"])
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["max_output_tokens"] == nil)
        #expect(body["reasoning"] == nil)
        let questions = try #require(body["questions"]?.arrayValue)
        #expect(questions.first { $0["name"] == "choice" }?["instructions"] == nil)
        #expect(questions.first { $0["name"] == "score" }?["instructions"] == nil)
        #expect(questions.first { $0["name"] == "flag" }?["instructions"] == "Criteria for true:\nPass")
    }

    private func response(_ value: JSONValue) throws -> AIHTTPResponse {
        jsonResponse(String(decoding: try encodeJSONBody(value), as: UTF8.self))
    }

    private func events(_ values: [JSONValue]) throws -> AIHTTPResponse {
        sseResponse(try values.map { "data: \(String(decoding: try encodeJSONBody($0), as: UTF8.self))\n\n" }.joined())
    }
}
