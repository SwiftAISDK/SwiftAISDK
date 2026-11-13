import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIOpenAI

private let weeklyTextSchema: JSONValue = ["type": "object", "properties": ["total": ["type": "integer"]], "required": ["total"], "additionalProperties": false]
private let weeklyTextFormat: JSONValue = ["type": "json_schema", "name": "count", "schema": weeklyTextSchema, "strict": true]
private func weeklyControl(_ options: JSONValue, namespace: String = "openai") -> AIMessage { .init(role: .system, content: [.text("")], providerMetadata: [namespace: options]) }
private func weeklyResponseTransport(stream: Bool, diagnostics: JSONValue? = nil) throws -> RecordingTransport {
    var raw: [String: JSONValue] = ["id": "resp", "created_at": 0, "model": "gpt-6-sol", "output": []]
    raw["prompt_cache_diagnostics"] = diagnostics
    if stream {
        let event: JSONValue = ["type": "response.completed", "response": .object(raw)]
        return RecordingTransport(response: sseResponse("data: " + String(decoding: try encodeJSONBody(event), as: UTF8.self)))
    }
    return RecordingTransport(response: .init(statusCode: 200, body: try encodeJSONBody(.object(raw))))
}

@Suite struct Weekly20261114ResponsesTests {
    @Test(arguments: [false, true]) func stableInitialFormatAndHistoricalCombinedControls(stream: Bool) async throws {
        let transport = try weeklyResponseTransport(stream: stream)
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
        let request = LanguageModelRequest(messages: [.user("Count"), weeklyControl(["textFormatUpdate": weeklyTextFormat, "reasoningEffortUpdate": "high"]), .user("Next"), weeklyControl(["textFormatUpdate": ["type": "text"]]), .user("More")], responseFormat: .json(schema: ["type": "object", "propertyNames": ["type": "number"]], name: nil, description: nil), providerOptions: ["openai": ["textFormat": ["type": "text"], "reasoningEffort": "low", "store": false]])
        if stream { for try await _ in provider.responses("gpt-6-sol").stream(request) {} }
        else { _ = try await provider.responses("gpt-6-sol").generate(request) }
        let body = try decodeJSONBody(#require(await transport.requests().first?.body))
        #expect(body["text"]?["format"] == ["type": "text"])
        #expect(body["reasoning"]?["effort"] == "low")
        #expect(body["input"]?[1] == ["type": "configuration_update", "reasoning": ["effort": "high"], "text": ["format": weeklyTextFormat]])
        #expect(body["input"]?[3] == ["type": "configuration_update", "text": ["format": ["type": "text"]]])
        #expect(body["textFormat"] == nil)
    }

    @Test func schemaNormalizationIsIndependentAndDoesNotMutateCaller() async throws {
        var format = weeklyTextFormat.objectValue!; var schema = weeklyTextSchema.objectValue!; schema["propertyNames"] = ["type": "string"]; format["schema"] = .object(schema)
        let transport = try weeklyResponseTransport(stream: false)
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
        let result = try await provider.responses("gpt-6-sol").generate(.init(messages: [weeklyControl(["textFormatUpdate": .object(format)]), .user("Next")], providerOptions: ["openai": ["textFormat": .object(format)]]))
        let body = try decodeJSONBody(#require(await transport.requests().first?.body))
        #expect(body["text"]?["format"]?["schema"] == weeklyTextSchema)
        #expect(body["input"]?[0]?["text"]?["format"]?["schema"] == weeklyTextSchema)
        #expect(format["schema"]?["propertyNames"] == ["type": "string"])
        #expect(result.warnings.filter { $0.type == "compatibility" }.count == 2)
    }

    @Test func formatOnlyUpdatesRetainEffectiveReasoningAndPreviousResponse() async throws {
        let transport = try weeklyResponseTransport(stream: false)
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
        _ = try await provider.responses("gpt-6-sol").generate(.init(messages: [weeklyControl(["reasoningEffortUpdate": "none"]), .user("Count"), weeklyControl(["textFormatUpdate": weeklyTextFormat]), .user("Next")], temperature: 0.2, topP: 0.8, providerOptions: ["openai": ["previousResponseId": "prior", "reasoningEffort": "low", "reasoningSummary": .null]]))
        let body = try decodeJSONBody(#require(await transport.requests().first?.body))
        #expect(body["temperature"] == 0.2)
        #expect(body["top_p"] == 0.8)
        #expect(body["previous_response_id"] == "prior")
        #expect(body["text"] == nil)
    }

    @Test func invalidOrIncompatibleConfigurationUpdatesRejectWithoutHTTP() async throws {
        let transport = try weeklyResponseTransport(stream: false)
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
        let bad: [LanguageModelRequest] = [
            .init(messages: [weeklyControl(["textFormatUpdate": ["type": "json_object"]]), .user("Next")]),
            .init(messages: [weeklyControl(["reasoningEffortUpdate": "low"]), weeklyControl(["textFormatUpdate": weeklyTextFormat]), .user("Next")]),
            .init(messages: [weeklyControl(["textFormatUpdate": weeklyTextFormat]), .user("Next")], providerOptions: ["openai": ["reasoningEffortUpdate": "high"]]),
            .init(messages: [weeklyControl(["textFormatUpdate": weeklyTextFormat]), .user("Next")], providerOptions: ["openai": ["reasoningMode": "pro"]]),
            .init(messages: [.init(role: .system, content: [.text("Instructions")], providerMetadata: ["openai": ["textFormatUpdate": weeklyTextFormat]])])
        ]
        for request in bad { await #expect(throws: AIError.self) { try await provider.responses("gpt-6-sol").generate(request) } }
        await #expect(throws: AIError.self) { try await provider.responses("gpt-5.4").generate(.init(messages: [weeklyControl(["textFormatUpdate": weeklyTextFormat]), .user("Next")])) }
        #expect(await transport.requests().isEmpty)
    }

    @Test(arguments: ["openai", "azure"])
    func invalidHistoricalReasoningKeepsItsQualifiedNativeDiagnostic(namespace: String) async throws {
        let transport = try weeklyResponseTransport(stream: false)
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport, name: namespace))
        let argument = "messages.providerMetadata.\(namespace).reasoningEffortUpdate"
        await #expect(throws: AIError.invalidArgument(argument: argument, message: "Message-level reasoningEffortUpdate must be none, low, medium, high, xhigh, or max.")) {
            _ = try await provider.responses("gpt-6-sol").generate(.init(messages: [weeklyControl(["reasoningEffortUpdate": 42], namespace: namespace), .user("Think")]))
        }
        await #expect(throws: AIError.invalidArgument(argument: argument, message: "The selected model only supports these reasoning efforts: low, medium, high, xhigh, max.")) {
            _ = try await provider.responses("gpt-6-astra").generate(.init(messages: [weeklyControl(["reasoningEffortUpdate": "none"], namespace: namespace), .user("Think")]))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test(arguments: [false, true]) func malformedCacheDiagnosticsFailValidation(stream: Bool) async throws {
        let transport = try weeklyResponseTransport(stream: stream, diagnostics: ["type": "cache_miss", "cache_missed_tokens": "invalid"])
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
        await #expect(throws: AIError.self) {
            let request = LanguageModelRequest(messages: [.user("Hello")])
            if stream { for try await _ in provider.responses("gpt-6-sol").stream(request) {} }
            else { _ = try await provider.responses("gpt-6-sol").generate(request) }
        }
    }

    @Test(arguments: [false, true]) func promptCacheComparisonAndDiagnosticsArePreserved(stream: Bool) async throws {
        for diagnostics: JSONValue in [["type": "cache_miss", "reason": "text_format_changed", "cache_missed_tokens": 1200, "comparison_reusable_tokens": 1500], ["type": "future_diagnostic", "reason": "future"], .null] {
            let transport = try weeklyResponseTransport(stream: stream, diagnostics: diagnostics)
            let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
            let request = LanguageModelRequest(messages: [.user("Hello")], providerOptions: ["openai": ["promptCacheOptions": ["mode": "implicit", "ttl": "12h", "prewarm": false, "comparisonResponseId": "baseline"]]])
            var metadata: [String: JSONValue] = [:]
            if stream { for try await part in provider.responses("gpt-6-astra").stream(request) { if case let .finishMetadata(_, _, value) = part { metadata = value } } }
            else { metadata = try await provider.responses("gpt-6-astra").generate(request).providerMetadata }
            let body = try decodeJSONBody(#require(await transport.requests().first?.body))
            #expect(body["prompt_cache_options"] == ["mode": "implicit", "ttl": "12h", "prewarm": false, "comparison_response_id": "baseline"])
            if diagnostics == .null { #expect(metadata["openai"]?["promptCacheDiagnostics"] == nil) }
            else { #expect(metadata["openai"]?["promptCacheDiagnostics"] == diagnostics) }
        }
    }
}
