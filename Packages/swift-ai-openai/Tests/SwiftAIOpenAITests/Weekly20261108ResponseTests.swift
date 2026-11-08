import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIOpenAI

@Suite struct Weekly20261108ResponseTests {
    @Test func refusalTextLogprobsAndURLArePreserved() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"Partial. ","refusal":"Cannot continue."},"finish_reason":"stop","logprobs":{"content":[{"token":"Partial"}],"refusal":[{"token":"Cannot"}]}}]}"#))
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", baseURL: "https://proxy.test/v2", queryParams: ["route": "secret"], transport: transport))
        let result = try await provider.chat("gpt-4.1").generate(.init(messages: [.user("Hi")]))
        #expect(result.text == "Partial. Cannot continue.")
        #expect(result.content.count == 2)
        #expect(result.finishReason == "content-filter")
        #expect(result.providerMetadata["openai"]?["logprobs"]?.arrayValue?.compactMap { $0["token"]?.stringValue } == ["Partial", "Cannot"])
        #expect(result.requestMetadata.url == (await transport.requests().first?.url.absoluteString))
    }

    @Test func streamRefusalInFinishChunkAccumulatesLogprobs() async throws {
        let chunks = [
            #"{"choices":[{"delta":{"content":"Partial. "},"logprobs":{"content":[{"token":"Partial"}]}}]}"#,
            #"{"choices":[{"delta":{"refusal":"Cannot continue."},"finish_reason":"stop","logprobs":{"refusal":[{"token":"Cannot"}]}}]}"#
        ]
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 200, headers: ["content-type": "text/event-stream"], body: Data((chunks.map { "data: \($0)\n\n" }.joined() + "data: [DONE]\n\n").utf8)))
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
        var text = ""; var finish: String?; var logprobs: JSONValue?; var endpoint: String?
        for try await part in provider.chat("gpt-4.1").stream(.init(messages: [.user("Hi")])) {
            switch part {
            case let .textDeltaPart(_, delta, _): text += delta
            case let .finishMetadata(reason, _, metadata): finish = reason; logprobs = metadata["openai"]?["logprobs"]
            case let .requestMetadata(value): endpoint = value.url
            default: break
            }
        }
        #expect(text == "Partial. Cannot continue."); #expect(finish == "content-filter")
        #expect(logprobs?.arrayValue?.count == 2); #expect(endpoint == "https://api.openai.com/v1/chat/completions")
    }

    @Test func namedMessagesUseOnlyMessageOpenAINamespace() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"ok"},"finish_reason":"stop"}]}"#))
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
        var user = AIMessage.user("Hi"); user.providerMetadata = ["openai": ["name": "alice"]]
        _ = try await provider.chat("gpt-4.1").generate(.init(messages: [user]))
        let body = try decodeJSONBody(#require(await transport.requests().first?.body))
        #expect(body["messages"]?[0]?["name"] == "alice")
        user.providerMetadata = ["openai": ["name": 3]]
        await #expect(throws: AIError.self) { _ = try await provider.chat("gpt-4.1").generate(.init(messages: [user])) }
        #expect(await transport.requests().count == 1)
    }

    @Test func responsesPreserveRefusalContentAndToolPrecedence() async throws {
        for hasTool in [false, true] {
            var output: [JSONValue] = [["type": "message", "id": "msg", "phase": "final_answer", "content": [["type": "output_text", "text": "Partial. "], ["type": "refusal", "refusal": "Cannot continue."]]]]
            if hasTool { output.append(["type": "function_call", "id": "fc", "call_id": "call", "name": "lookup", "arguments": "{}", "status": "completed"]) }
            let raw: JSONValue = ["id": "resp", "status": "completed", "output": .array(output)]
            let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 200, body: try encodeJSONBody(raw)))
            let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
            let result = try await provider.responses("gpt-4.1").generate(.init(messages: [.user("Hi")]))
            #expect(result.text == "Partial. Cannot continue.")
            #expect(result.finishReason == (hasTool ? "tool-calls" : "content-filter"))
        }
    }

    @Test func responsesStreamRefusalsStayTextWithContentFilterFinish() async throws {
        let chunks: [JSONValue] = [
            ["type": "response.created", "response": ["id": "resp", "status": "in_progress", "output": []]],
            ["type": "response.output_item.added", "output_index": 0, "item": ["type": "message", "id": "msg", "content": []]],
            ["type": "response.refusal.delta", "item_id": "msg", "output_index": 0, "delta": "Cannot answer."],
            ["type": "response.refusal.done", "item_id": "msg", "output_index": 0, "refusal": "Cannot answer."],
            ["type": "response.completed", "response": ["id": "resp", "status": "completed", "output": []]]
        ]
        let bytes = try chunks.map { "data: " + String(decoding: try encodeJSONBody($0), as: UTF8.self) + "\n\n" }.joined()
        let transport = RecordingTransport(response: .init(statusCode: 200, headers: ["content-type": "text/event-stream"], body: Data(bytes.utf8)))
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
        var text = ""; var finish: String?
        for try await part in provider.responses("gpt-4.1").stream(.init(messages: [.user("Hi")])) {
            if case let .textDeltaPart(_, delta, _) = part { text += delta }
            if case let .finishMetadata(reason, _, _) = part { finish = reason }
        }
        #expect(text == "Cannot answer."); #expect(finish == "content-filter")
    }

    @Test func liveRejectsTranscriptionIntentBeforeConnectionsAndSerialization() async throws {
        let model = try OpenAILiveModel(configuration: .init(apiKey: "key"))
        #expect(throws: AIError.self) { _ = try model.getServerWebSocketConfig(intent: .transcription) }
        await #expect(throws: AIError.self) { _ = try await model.getResolvedServerWebSocketConfig(intent: .transcription) }
        await #expect(throws: AIError.self) { _ = try await model.serializeClientEvent(.sessionUpdate(.init()), intent: .transcription) }
        #expect(throws: AIError.self) { _ = try model.buildSessionConfig(.init(), intent: .transcription) }
    }

    @Test func mcpTunnelAndCodeInterpreterPoliciesMapAndRejectConflicts() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"status":"completed","output":[{"type":"message","id":"msg","content":[{"type":"output_text","text":"ok"}]}]}"#))
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
        let model = provider.responses("gpt-4.1")
        _ = try await model.generate(.init(messages: [.user("Hi")], tools: [
            "mcp": OpenAITools.mcp(serverLabel: "secure", tunnelID: "tunnel"),
            "python": OpenAITools.codeInterpreter(container: ["memoryLimit": "4g", "networkPolicy": ["type": "allowlist", "allowedDomains": ["example.com"], "domainSecrets": [["domain": "example.com", "name": "TOKEN", "value": "secret"]]]])
        ]))
        let body = try decodeJSONBody(#require(await transport.requests().first?.body))
        let tools = body["tools"]?.arrayValue ?? []
        #expect(tools.first { $0["type"] == "mcp" }?["tunnel_id"] == "tunnel")
        #expect(tools.first { $0["type"] == "code_interpreter" }?["container"]?["memory_limit"] == "4g")
        #expect(tools.first { $0["type"] == "code_interpreter" }?["container"]?["network_policy"]?["allowed_domains"] == ["example.com"])
        await #expect(throws: AIError.self) { _ = try await model.generate(.init(messages: [.user("Hi")], tools: ["mcp": OpenAITools.mcp(serverLabel: "secure", serverURL: "https://mcp.test", tunnelID: "tunnel")])) }
        #expect(await transport.requests().count == 1)
    }
}
