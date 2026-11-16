@testable import SwiftAIOpenAICompatible
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing
@testable import SwiftAIOpenAI

// Translations of `packages/openai/src/chat/openai-chat-language-model.test.ts`
// (@ai-sdk/openai 4.0.118) that cover the OpenAI Chat Completions request policy.

private let parityChatTextResponse = #"{"id":"chatcmpl-1","object":"chat.completion","created":1711115037,"model":"gpt-4o","choices":[{"index":0,"message":{"role":"assistant","content":"Hello"},"finish_reason":"stop"}],"usage":{"prompt_tokens":4,"completion_tokens":30,"total_tokens":34}}"#

private func parityChatRequest(
    _ modelID: String,
    _ request: LanguageModelRequest
) async throws -> (body: [String: JSONValue], warnings: [AIWarning]) {
    let transport = RecordingTransport(response: jsonResponse(parityChatTextResponse))
    let provider = try AIProviders.openAI(configuration: OpenAIProviderSettings(apiKey: "test-key", transport: transport))
    let result = try await provider.chat(modelID).generate(request)
    let body = try decodeJSONBody(try #require((await transport.requests()).first?.body))
    return (try #require(body.objectValue), result.warnings)
}

private let parityChatHello: [AIMessage] = [.user("Hello")]
private let parityChatHelloJSON: JSONValue = .array([.object(["role": "user", "content": "Hello"])])

@Test(arguments: ["gpt-4o-search-preview", "gpt-4o-mini-search-preview", "gpt-4o-mini-search-preview-2025-03-11"])
func parityOpenAIChatRemovesTemperatureForSearchPreviewModels(modelID: String) async throws {
    let (body, warnings) = try await parityChatRequest(modelID, LanguageModelRequest(messages: parityChatHello, temperature: 0.7))

    #expect(body["model"]?.stringValue == modelID)
    #expect(body["temperature"] == nil)
    #expect(warnings == [AIWarning(
        type: "unsupported",
        feature: "temperature",
        message: "temperature is not supported for the search preview models and has been removed."
    )])
}

@Test func parityOpenAIChatSendsFlexServiceTier() async throws {
    let (body, warnings) = try await parityChatRequest("o4-mini", LanguageModelRequest(
        messages: parityChatHello, providerOptions: ["openai": ["serviceTier": "flex"]]
    ))
    #expect(body == ["model": "o4-mini", "messages": parityChatHelloJSON, "service_tier": "flex"])
    #expect(warnings.isEmpty)
}

@Test func parityOpenAIChatWarnsAndDropsFlexServiceTierForUnsupportedModel() async throws {
    let (body, warnings) = try await parityChatRequest("gpt-4o-mini", LanguageModelRequest(
        messages: parityChatHello, providerOptions: ["openai": ["serviceTier": "flex"]]
    ))
    #expect(body["service_tier"] == nil)
    #expect(warnings == [AIWarning(
        type: "unsupported",
        feature: "serviceTier",
        message: "flex processing is only available for o3, o4-mini, and gpt-5 models"
    )])
}

@Test(arguments: [("gpt-4o-mini", "priority"), ("gpt-4o", "priority"), ("o3", "priority"), ("gpt-4o", "fast"), ("gpt-5.6-sol", "ultrafast")])
func parityOpenAIChatSendsSupportedPriorityServiceTiers(modelID: String, tier: String) async throws {
    let (body, warnings) = try await parityChatRequest(modelID, LanguageModelRequest(
        messages: parityChatHello, providerOptions: ["openai": ["serviceTier": .string(tier)]]
    ))
    #expect(body["service_tier"]?.stringValue == tier)
    #expect(warnings.isEmpty)
}

@Test(arguments: ["priority", "fast"])
func parityOpenAIChatWarnsAndDropsPriorityServiceTierForUnsupportedModel(tier: String) async throws {
    let (body, warnings) = try await parityChatRequest("gpt-5-nano", LanguageModelRequest(
        messages: parityChatHello, providerOptions: ["openai": ["serviceTier": .string(tier)]]
    ))
    #expect(body["service_tier"] == nil)
    #expect(warnings == [AIWarning(
        type: "unsupported",
        feature: "serviceTier",
        message: "priority processing is only available for supported models (gpt-4, gpt-5, gpt-5-mini, o3, o4-mini) and requires Enterprise access. gpt-5-nano is not supported"
    )])
}

@Test func parityOpenAIChatPassesSettings() async throws {
    let (body, warnings) = try await parityChatRequest("gpt-3.5-turbo", LanguageModelRequest(
        messages: parityChatHello,
        providerOptions: ["openai": ["logitBias": ["50256": -100], "parallelToolCalls": false, "user": "test-user-id"]]
    ))
    #expect(body == [
        "logit_bias": ["50256": -100],
        "messages": parityChatHelloJSON,
        "model": "gpt-3.5-turbo",
        "parallel_tool_calls": false,
        "user": "test-user-id"
    ])
    #expect(warnings.isEmpty)
}

@Test func parityOpenAIChatForwardsJSONSchemaResponseFormat() async throws {
    let schema: JSONValue = [
        "type": "object",
        "properties": ["value": ["type": "string"]],
        "required": ["value"],
        "additionalProperties": false,
        "$schema": "http://json-schema.org/draft-07/schema#"
    ]
    let (body, warnings) = try await parityChatRequest("gpt-4o-2024-08-06", LanguageModelRequest(
        messages: parityChatHello, responseFormat: .json(schema: schema, name: nil, description: nil)
    ))
    #expect(body == [
        "messages": parityChatHelloJSON,
        "model": "gpt-4o-2024-08-06",
        "response_format": [
            "json_schema": ["name": "response", "schema": schema, "strict": true],
            "type": "json_schema"
        ]
    ])
    #expect(warnings.isEmpty)
}

@Test func parityOpenAIChatForwardsJSONObjectWithoutSchema() async throws {
    let (body, _) = try await parityChatRequest("gpt-4o-2024-08-06", LanguageModelRequest(
        messages: parityChatHello, responseFormat: .json(schema: nil, name: nil, description: nil)
    ))
    #expect(body == ["model": "gpt-4o-2024-08-06", "messages": parityChatHelloJSON, "response_format": ["type": "json_object"]])
}

@Test func parityOpenAIChatClearsSamplingForReasoningModels() async throws {
    let (body, warnings) = try await parityChatRequest("o4-mini", LanguageModelRequest(
        messages: parityChatHello, temperature: 0.5, topP: 0.7, presencePenalty: 0.3, frequencyPenalty: 0.2
    ))
    #expect(body == ["model": "o4-mini", "messages": parityChatHelloJSON])
    #expect(warnings == [
        AIWarning(type: "unsupported", feature: "temperature", message: "temperature is not supported for reasoning models"),
        AIWarning(type: "unsupported", feature: "topP", message: "topP is not supported for reasoning models"),
        AIWarning(type: "unsupported", feature: "frequencyPenalty", message: "frequencyPenalty is not supported for reasoning models"),
        AIWarning(type: "unsupported", feature: "presencePenalty", message: "presencePenalty is not supported for reasoning models")
    ])
}

@Test(arguments: ["openai", "azure"])
func parityOpenAIChatWarnsThatReasoningSummaryIsNotSupported(namespace: String) async throws {
    let transport = RecordingTransport(response: jsonResponse(parityChatTextResponse))
    let provider = try AIProviders.openAI(configuration: OpenAIProviderSettings(
        apiKey: "test-key", transport: transport, name: namespace == "azure" ? "azure" : nil
    ))
    let warnings = try await provider.chat("o3").generate(LanguageModelRequest(
        messages: parityChatHello, providerOptions: [namespace: ["reasoningSummary": "detailed"]]
    )).warnings
    let body = try decodeJSONBody(try #require((await transport.requests()).first?.body))
    #expect(body == ["model": "o3", "messages": parityChatHelloJSON])
    #expect(warnings == [AIWarning(
        type: "unsupported",
        feature: "reasoningSummary",
        message: "reasoningSummary is only supported by the Responses API, not the Chat Completions API"
    )])
}

@Test func parityOpenAIChatMapsMaxReasoningToXHighForGPT6() async throws {
    let (body, warnings) = try await parityChatRequest("gpt-6-sol", LanguageModelRequest(messages: parityChatHello, reasoning: "max"))
    #expect(body["reasoning_effort"]?.stringValue == "xhigh")
    #expect(warnings == [AIWarning(
        type: "compatibility",
        feature: "reasoning",
        message: #"reasoning "max" is not directly supported by this model. mapped to effort "xhigh"."#
    )])
}

@Test func parityOpenAIChatStripsSamplingAndLogprobsForGPT6() async throws {
    let (body, warnings) = try await parityChatRequest("gpt-6-astra", LanguageModelRequest(
        messages: parityChatHello, temperature: 0.5, topP: 0.7,
        providerOptions: ["openai": ["reasoningEffort": "low", "logprobs": 5]]
    ))
    #expect(body == ["model": "gpt-6-astra", "messages": parityChatHelloJSON, "reasoning_effort": "low"])
    #expect(warnings == [
        AIWarning(type: "unsupported", feature: "temperature", message: "temperature is not supported for reasoning models"),
        AIWarning(type: "unsupported", feature: "topP", message: "topP is not supported for reasoning models"),
        AIWarning(type: "other", message: "logprobs is not supported for reasoning models"),
        AIWarning(type: "other", message: "topLogprobs is not supported for reasoning models")
    ])
}

@Test(arguments: ["none", "minimal"])
func parityOpenAIChatMapsUnsupportedGPT6ReasoningToLowest(reasoning: String) async throws {
    let (body, warnings) = try await parityChatRequest("gpt-6-astra", LanguageModelRequest(messages: parityChatHello, reasoning: reasoning))
    #expect(body == ["model": "gpt-6-astra", "messages": parityChatHelloJSON, "reasoning_effort": "low"])
    #expect(warnings == [AIWarning(
        type: "compatibility",
        feature: "reasoning",
        message: "reasoning \"\(reasoning)\" is not directly supported by this model. mapped to effort \"low\"."
    )])
}

@Test func parityOpenAIChatClearsTemperatureWhenReasoningNoneOnO4Mini() async throws {
    let (body, warnings) = try await parityChatRequest("o4-mini", LanguageModelRequest(messages: parityChatHello, temperature: 0.5, reasoning: "none"))
    #expect(body == ["model": "o4-mini", "messages": parityChatHelloJSON, "reasoning_effort": "none"])
    #expect(warnings == [AIWarning(type: "unsupported", feature: "temperature", message: "temperature is not supported for reasoning models")])
}

@Test func parityOpenAIChatPromptCacheRetentionGPT6() async throws {
    let (body, warnings) = try await parityChatRequest("gpt-6-astra", LanguageModelRequest(
        messages: parityChatHello, providerOptions: ["openai": ["promptCacheRetention": "24h"]]
    ))
    #expect(body["prompt_cache_retention"] == nil)
    #expect(warnings == [AIWarning(
        type: "unsupported",
        feature: "promptCacheRetention",
        message: "promptCacheRetention is not supported by GPT-6 and later models; use promptCacheOptions instead"
    )])
}

@Test func parityOpenAIChatRemovesStringPropertyNamesFromResponseSchemasAndWarns() async throws {
    let (body, warnings) = try await parityChatRequest("gpt-4o-2024-08-06", LanguageModelRequest(
        messages: parityChatHello,
        responseFormat: .json(schema: [
            "type": "object",
            "properties": ["variables": [
                "type": "object",
                "propertyNames": ["type": "string", "format": "uuid"],
                "additionalProperties": ["type": "string"]
            ]],
            "required": ["variables"],
            "additionalProperties": false
        ], name: nil, description: nil)
    ))
    #expect(body == [
        "model": "gpt-4o-2024-08-06",
        "messages": parityChatHelloJSON,
        "response_format": [
            "type": "json_schema",
            "json_schema": [
                "name": "response",
                "strict": true,
                "schema": [
                    "type": "object",
                    "properties": ["variables": ["type": "object", "additionalProperties": ["type": "string"]]],
                    "required": ["variables"],
                    "additionalProperties": false
                ]
            ]
        ]
    ])
    #expect(warnings == [AIWarning(
        type: "compatibility",
        feature: "JSON Schema propertyNames",
        message: "OpenAI does not support JSON Schema propertyNames. It was removed before sending the schema, so OpenAI will not enforce property-name constraints."
    )])
}

@Test func parityOpenAIChatSendsResponseSchemaWithoutAddingAdditionalProperties() async throws {
    let schema: JSONValue = ["type": "object", "properties": ["value": ["type": "string"]], "required": ["value"]]
    let (body, _) = try await parityChatRequest("gpt-4o-2024-08-06", LanguageModelRequest(
        messages: parityChatHello, responseFormat: .json(schema: schema, name: "test-name", description: "test description")
    ))
    #expect(body["response_format"] == [
        "type": "json_schema",
        "json_schema": ["name": "test-name", "description": "test description", "strict": true, "schema": schema]
    ])
}

@Test func parityOpenAIChatSendsToolSchemaUnchanged() async throws {
    let schema: JSONValue = ["type": "object", "properties": ["value": ["type": "string"]], "required": ["value"]]
    let (body, _) = try await parityChatRequest("gpt-4o-2024-08-06", LanguageModelRequest(
        messages: parityChatHello,
        tools: ["test-tool": schema],
        toolChoice: ["type": "tool", "toolName": "test-tool"]
    ))
    #expect(body["tools"] == [["type": "function", "function": ["name": "test-tool", "parameters": schema]]])
    #expect(body["tool_choice"] == ["type": "function", "function": ["name": "test-tool"]])
}
