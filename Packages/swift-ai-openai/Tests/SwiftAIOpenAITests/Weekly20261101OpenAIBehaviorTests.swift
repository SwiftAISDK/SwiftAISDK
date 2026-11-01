import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
@testable import SwiftAIOpenAI

@Suite struct Weekly20261101OpenAIBehaviorTests {
    @Test(arguments: [
        ("gpt-5.5", "minimal", "low"), ("gpt-5.1", "xhigh", "high"),
        ("gpt-5-nano", "none", "minimal"), ("gpt-6-astra", "none", "low"),
        ("gpt-6.1-terra", "none", "none"), ("gpt-5.6-luna", "max", "max")
    ]) func responsesMapsPortableReasoning(_ modelID: String, _ reasoning: String, _ expected: String) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"id":"r","status":"completed","output_text":"done"}"#))
        let model = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport)).languageModel(modelID)
        let result = try await model.generate(.init(messages: [.user("Hi")], reasoning: reasoning))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["reasoning"]?["effort"]?.stringValue == expected)
        #expect(result.warnings.contains { $0.type == "compatibility" && $0.feature == "reasoning" } == (reasoning != expected))
    }

    @Test(arguments: ["none", "minimal"])
    func providerReasoningEffortIsForwardedUnchanged(_ effort: String) async throws {
        for chat in [false, true] {
            let response = chat ? #"{"choices":[{"message":{"content":"done"},"finish_reason":"stop"}]}"# : #"{"id":"r","status":"completed","output_text":"done"}"#
            let transport = RecordingTransport(response: jsonResponse(response))
            let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
            let model = chat ? provider.chat("gpt-6-astra") : provider.responses("gpt-6-astra")
            let result = try await model.generate(.init(messages: [.user("Hi")], providerOptions: ["openai": ["reasoningEffort": .string(effort)]]))
            let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
            #expect((chat ? body["reasoning_effort"] : body["reasoning"]?["effort"])?.stringValue == effort)
            #expect(result.warnings.isEmpty)
        }
    }

    @Test func chatToolsDisableGPT56ReasoningButRespectProviderOverride() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"done"},"finish_reason":"stop"}]}"#))
        let model = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport)).chat("gpt-5.6-luna")
        let tools: [String: JSONValue] = ["test": ["type": "object", "properties": [:]]]
        let first = try await model.generate(.init(messages: [.user("Hi")], reasoning: "low", tools: tools))
        _ = try await model.generate(.init(messages: [.user("Hi")], tools: tools, providerOptions: ["openai": ["reasoningEffort": "low"]]))
        let requests = await transport.requests()
        #expect(try decodeJSONBody(#require(requests[0].body))["reasoning_effort"] == "none")
        #expect(try decodeJSONBody(#require(requests[1].body))["reasoning_effort"] == "low")
        #expect(first.warnings.contains { $0.type == "compatibility" && $0.feature == "reasoning" })
    }

    @Test func gpt5CacheRetentionAndResponsesLogprobsRemainAvailable() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"id":"r","status":"completed","output_text":"done"}"#))
        let model = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport)).responses("gpt-5.5")
        let result = try await model.generate(.init(messages: [.user("Hi")], providerOptions: ["openai": ["reasoningEffort": "low", "promptCacheRetention": "24h", "logprobs": 5]]))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["prompt_cache_retention"] == "24h")
        #expect(body["top_logprobs"] == 5)
        #expect(result.warnings.isEmpty)
    }

    @Test func untypedPropertyNamesIsRemovedWithOneWarning() throws {
        let normalized = try normalizeOpenAIJSONSchema(["type": "object", "properties": ["a": ["type": "object", "propertyNames": ["minLength": 1]], "b": ["type": "object", "propertyNames": ["enum": ["a"]]]]])
        #expect(normalized.schema["properties"]?["a"]?["propertyNames"] == nil)
        #expect(normalized.warnings.count == 1)
        #expect(throws: AIError.self) { try normalizeOpenAIJSONSchema(["type": "object", "propertyNames": ["type": "number"]]) }
    }

    @Test(arguments: ["searching", "incomplete", "failed"])
    func noncompletedWebSearchIsAnError(_ status: String) {
        let result = openAIResponsesToolResult(from: ["type": "web_search_call", "id": "ws", "status": .string(status)], providerID: "openai.responses")
        #expect(result?.isError == true)
        #expect(result?.result == ["status": .string(status)])
    }

    @Test func jsonDecisionUsesNativeBoundedObjectsAndPromptCacheKey() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"answers":[{"type":"predicate","name":"ok","probability":1}]}"#))
        let model = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport)).decisionModel("gpt-6-sol")
        for (value, native) in [(JSONValue.object(["ticket": ["charged twice"]]), true), (.array([]), false), (.array([["a": 1], 1]), false), (.object(["blob": .string(String(repeating: "é", count: 140 * 1024))]), false)] {
            let result = try await model.doDecide(.init(state: [.json(value)], questions: ["ok": .boolean(instructions: .string("OK?"), criteria: nil)], providerOptions: ["openai": ["promptCacheKey": "tenant"]]))
            let body = try decodeJSONBody(try #require(await transport.requests().last?.body))
            #expect(body["input"]?[0]?["content"]?[0]?["type"] == .string(native ? "input_json" : "input_text"))
            #expect(body["prompt_cache_key"] == "tenant")
            #expect(result.warnings.isEmpty)
        }
    }

    @Test func transcriptionDefaultsAndDurationUsage() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"text":"Hello","usage":{"type":"duration","seconds":37}}"#))
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
        let result = try await provider.transcriptionModel("gpt-transcribe").transcribe(.init(audio: Data([1]), mimeType: "audio/wav", providerOptions: ["openai": ["prompt": "Hi"]]))
        let body = String(decoding: try #require(await transport.requests().first?.body), as: UTF8.self)
        #expect(!body.contains("name=\"response_format\""))
        #expect(!body.contains("name=\"timestamp_granularities[]\""))
        #expect(result.durationInSeconds == 37)
        await #expect(throws: AIError.self) { try await provider.transcriptionModel("gpt-live-transcribe-2026-01-01").transcribe(.init(audio: Data([1]), mimeType: "audio/wav")) }
    }
    @Test(arguments: [("none", "low"), ("minimal", "low"), ("max", "xhigh")])
    func quiverSharedResponsesMapsUnsupportedReasoning(_ reasoning: String, _ expected: String) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"id":"r","status":"completed","output":[{"type":"message","role":"assistant","content":[{"type":"output_text","text":"done"}]}]}"#))
        let http = AIProviderHTTPClient(providerID: "quiverai.responses", transport: transport, url: { _, _ in URL(string: "https://example.com/responses")! })
        var configuration = OpenAIModelConfiguration(http: http, baseURL: "https://example.com", openAIBackedProviderRoot: nil)
        configuration.responsesRequestMode = .openResponses(providerOptionsName: "quiverai")
        let model = OpenAICompatibleResponsesModel(modelID: "arrow-2", config: configuration)
        let result = try await model.generate(.init(messages: [.user("Hi")], reasoning: reasoning))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["reasoning"]?["effort"] == .string(expected))
        #expect(result.warnings.contains { $0.type == "compatibility" && $0.feature == "reasoning" })
    }

}
