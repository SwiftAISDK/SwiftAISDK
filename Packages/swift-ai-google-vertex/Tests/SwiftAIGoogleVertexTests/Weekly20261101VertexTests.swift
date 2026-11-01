import Foundation
import Testing
@testable import SwiftAIGoogleVertex
import SwiftAIProvider
import SwiftAITransport

@Suite struct Weekly20261101VertexTests {
    @Test func expressModeResolvesEveryRequestAndOverridesExplicitKeyHeader() async throws {
        let keys = WeeklyVertexKeys()
        let transport = RecordingTransport(response: jsonResponse(#"{"candidates":[{"content":{"parts":[{"text":"done"}]},"finishReason":"STOP"}]}"#))
        let provider = try GoogleVertexProvider(settings: .init(headers: ["x-goog-api-key": "old"], transport: transport, apiKeyProvider: { await keys.next() }))
        #expect(await keys.count == 0)
        let model = try provider.languageModel("gemini-3.8-flash")
        _ = try await model.generate(.init(messages: [.user("Hello")]))
        _ = try await model.generate(.init(messages: [.user("Hello")], headers: ["x-goog-api-key": "request-key"]))
        let requests = await transport.requests()
        #expect(requests.map { normalizeHeaders($0.headers)["x-goog-api-key"] } == ["key-1", "key-2"])
        #expect(requests.allSatisfy { $0.url.absoluteString.hasPrefix("https://aiplatform.googleapis.com/v1/publishers/google/") })
        #expect(throws: AIError.self) { _ = try provider.languageModel("endpoints/tuned") }
    }

    @Test func expressModeRejectsBlankCallbackCredentialBeforeNetwork() async throws {
        let transport = RecordingTransport(response: jsonResponse("{}"))
        let provider = try GoogleVertexProvider(settings: .init(transport: transport, apiKeyProvider: { " \n" }))
        let model = try provider.languageModel("gemini-3.8-flash")
        await #expect(throws: AIError.invalidArgument(argument: "apiKeyProvider", message: "Google Vertex API key must be a non-empty string.")) {
            _ = try await model.generate(.init(messages: [.user("Hello")]))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func abortDuringExpressCredentialResolutionPreventsNetwork() async throws {
        let controller = AIAbortController()
        let transport = RecordingTransport(response: jsonResponse("{}"))
        let provider = try GoogleVertexProvider(settings: .init(transport: transport, apiKeyProvider: {
            controller.abort()
            return "new-key"
        }))
        let model = try provider.languageModel("gemini-3.8-flash")
        await #expect(throws: (any Error).self) {
            _ = try await model.generate(.init(messages: [.user("Hello")], abortSignal: controller.signal))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func hostedBearerSupplierRefreshesWithoutChangingRequestOverridePrecedence() async throws {
        let keys = WeeklyVertexKeys()
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"done"},"finish_reason":"stop"}]}"#))
        let provider = try GoogleVertexHostedProvider(endpoint: .maaS, project: "project", location: "global", configuration: .init(transport: transport, apiKeyProvider: { await keys.next() }))
        let model = try provider.languageModel("meta/model")
        #expect(await keys.count == 0)
        _ = try await model.generate(.init(messages: [.user("Hello")]))
        _ = try await model.generate(.init(messages: [.user("Hello")], headers: ["Authorization": "Bearer override"]))
        let requests = await transport.requests()
        #expect(requests.map { normalizeHeaders($0.headers)["authorization"] } == ["Bearer key-1", "Bearer override"])
    }

    @Test func vertexPrefersItsVideoMetadataNamespace() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"candidates":[{"content":{"parts":[{"text":"done"}]},"finishReason":"STOP"}]}"#))
        let provider = try GoogleVertexProvider(settings: .init(apiKey: "key", transport: transport))
        let model = try provider.languageModel("gemini-3.8-flash")
        _ = try await model.generate(.init(messages: [AIMessage(role: .user, content: [
            .file(mimeType: "video/mp4", data: Data([1]), providerMetadata: ["google": ["videoMetadata": ["fps": 1]], "googleVertex": ["videoMetadata": ["fps": 2]]])
        ])]))
        let request = try #require(await transport.requests().first)
        let body = try decodeJSONBody(try #require(request.body))
        #expect(body["contents"]?[0]?["parts"]?[0]?["videoMetadata"] == ["fps": 2])
    }

    @Test func inheritedClaudeStructuredOutputSelectsNativeForForcedToolIncompatibleModels() async throws {
        let schema: JSONValue = ["type": "object", "properties": ["answer": ["type": "string"]], "required": ["answer"], "additionalProperties": false]
        for modelID in ["claude-sonnet-5-5", "claude-opus-5-5", "claude-fable-5-1", "claude-haiku-5-5"] {
            let transport = RecordingTransport(response: jsonResponse(#"{"id":"msg_1","type":"message","role":"assistant","model":"claude-sonnet-5-5","content":[{"type":"text","text":"{}"}],"stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":1,"output_tokens":1}}"#))
            let provider = try GoogleVertexHostedProvider(endpoint: .anthropic, project: "test-project", location: "global", configuration: .init(apiKey: "token", transport: transport))
            _ = try await provider.languageModel(modelID).generate(.init(messages: [.user("Hello")], responseFormat: .json(schema: schema)))
            let request = try #require(await transport.requests().first)
            let body = try decodeJSONBody(try #require(request.body))
            if modelID == "claude-haiku-5-5" {
                #expect(body["output_config"] == nil)
                #expect(body["tool_choice"]?["type"] == "any")
            } else {
                #expect(body["output_config"]?["format"] == ["type": "json_schema", "schema": schema])
                #expect(body["tools"] == nil)
            }
        }
    }
}

private actor WeeklyVertexKeys {
    private(set) var count = 0
    func next() -> String { count += 1; return "key-\(count)" }
}
