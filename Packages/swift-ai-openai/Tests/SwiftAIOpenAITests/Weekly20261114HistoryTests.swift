import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIOpenAI

@Suite struct Weekly20261114HistoryTests {
    private var custom: JSONValue { ["type": "custom", "name": "apply_patch", "format": ["type": "grammar", "syntax": "lark", "definition": "start: x"]] }
    private var namespace: JSONValue { ["type": "namespace", "name": "linear", "description": "Linear tools", "tools": [["type": "function", "name": "get_issue", "parameters": ["type": "object"], "defer_loading": true]]] }

    @Test func additionalToolsSupportControlMessagesAndHostingFallback() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"id":"resp","output":[]}"#))
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport, name: "azure"))
        let result = AIToolResult(toolCallID: "call", toolName: "lookup", result: "result", providerMetadata: ["openai": ["additionalTools": .array([custom, namespace])]])
        var control = AIMessage.system(""); control.providerMetadata = ["azure": ["additionalTools": .array([custom])]]
        _ = try await provider.responses("gpt-5.4").generate(.init(messages: [.user("Next"), control, .init(role: .tool, content: [.toolResult(result)])]))
        let body = try decodeJSONBody(#require(await transport.requests().first?.body))
        #expect(body["input"]?[1] == ["type": "additional_tools", "role": "developer", "tools": .array([custom])])
        #expect(body["input"]?[3] == ["type": "additional_tools", "role": "developer", "tools": .array([custom, namespace])])
    }

    @Test func additionalToolDefinitionsRejectInvalidShapes() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"output":[]}"#))
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
        let invalid: [JSONValue] = [["type": "namespace", "name": "ns", "description": "d", "tools": []], ["type": "custom", "name": "c", "format": ["type": "grammar"]], ["type": "web_search"]]
        for value in invalid {
            var message = AIMessage.system(""); message.providerMetadata = ["openai": ["additionalTools": .array([value])]]
            await #expect(throws: AIError.self) { try await provider.responses("gpt-6-sol").generate(.init(messages: [message, .user("Next")])) }
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test(arguments: [false, true]) func compactParallelMetadataRoundTripsAndRetainsEachChildsDefinitions(reverse: Bool) async throws {
        let wrapper = #"{"tool_uses":[{"recipient_name":"functions.a","parameters":{}},{"recipient_name":"functions.b","parameters":{}}]}"#
        let tools: [String: JSONValue] = ["a": ["type": "object"], "b": ["type": "object"]]
        let calls = try #require(openAIResponsesExpandedParallelToolCalls(from: .init(id: "wrapper", name: "parallel", arguments: wrapper), itemID: "fc", providerID: "openai.responses", functionToolNames: ["a", "b"]))
        #expect(calls[0].providerMetadata["openai"]?["parallelToolCall"]?["input"] == .string(wrapper))
        #expect(calls[1].providerMetadata["openai"]?["parallelToolCall"]?["input"] == nil)
        var results = calls.enumerated().map { index, call -> AIToolResult in
            var options = call.providerMetadata["openai"]?.objectValue ?? [:]
            options["additionalTools"] = .array([["type": "function", "name": .string("loaded_\(index)"), "parameters": ["type": "object"], "defer_loading": true]])
            return .init(toolCallID: call.id, toolName: call.name, result: .string("result_\(index)"), providerMetadata: ["openai": .object(options)])
        }
        if reverse { results.reverse() }
        let transport = RecordingTransport(response: jsonResponse(#"{"output":[]}"#))
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
        _ = try await provider.responses("gpt-6-sol").generate(.init(messages: [.init(role: .assistant, content: calls.map(AIContentPart.toolCall)), .init(role: .tool, content: results.map(AIContentPart.toolResult))], tools: tools, providerOptions: ["openai": ["previousResponseId": "prior"]]))
        let body = try decodeJSONBody(#require(await transport.requests().first?.body))
        #expect(body["input"]?[0]?["arguments"] == .string(wrapper))
        #expect(body["input"]?[1]?["output"] == "result_0\nresult_1")
        #expect(body["input"]?[2]?["tools"]?[0]?["name"] == "loaded_0")
        #expect(body["input"]?[3]?["tools"]?[0]?["name"] == "loaded_1")
        #expect(body["input"]?.arrayValue?.count == 4)
    }

    @Test func telemetryViewRedactsOnlyCopiesOfKnownToolSecrets() throws {
        let policy: JSONValue = ["networkPolicy": ["domainSecrets": [["domain": "example.com", "name": "KEY", "value": "test-secret"]]]]
        let tools: [JSONValue] = [OpenAITools.codeInterpreter(container: policy), OpenAITools.shell(environment: policy), OpenAITools.mcp(serverLabel: "remote", authorization: "test-secret", headers: ["X-Key": "test-secret"], serverURL: "https://example.com")]
        let wire: JSONValue = ["tools": [["type": "mcp", "authorization": "test-secret", "headers": ["X-Key": "test-secret"]], ["type": "shell", "environment": ["network_policy": ["domain_secrets": [["name": "KEY", "value": "test-secret"]]]]]]]
        for value in tools + [wire] {
            let redacted = openAIRedactedTelemetry(value)
            let rawText = String(decoding: try encodeJSONBody(value), as: UTF8.self)
            let safeText = String(decoding: try encodeJSONBody(redacted), as: UTF8.self)
            #expect(rawText.contains("test-secret"))
            #expect(!safeText.contains("test-secret"))
            #expect(safeText.contains("[redacted]"))
            #expect(String(decoding: try encodeJSONBody(value), as: UTF8.self) == rawText)
        }
        let userData: JSONValue = ["input": [["serverLabel": "prose", "authorization": "user prose"]], "messages": [["content": [["type": "mcp", "authorization": "user prose"]]]], "output": [["type": "mcp", "authorization": "user prose"]]]
        #expect(openAIRedactedTelemetry(userData) == userData)
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key"))
        #expect(provider.responses("gpt-6-sol").telemetryRedactor != nil)
    }
}
