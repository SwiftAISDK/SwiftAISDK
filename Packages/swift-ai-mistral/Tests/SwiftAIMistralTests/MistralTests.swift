@testable import SwiftAIMistral
import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Testing
import SwiftAI

@Test func mistralLanguageUsesNativeChatShapeAndOptions() async throws {
    let transport = RecordingTransport(response: jsonResponse("""
    {"id":"cmpl-1","object":"chat.completion","created":1741257730,"model":"mistral-large-latest","choices":[{"index":0,"message":{"role":"assistant","content":[{"type":"thinking","thinking":[{"type":"text","text":"hmm"}]},{"type":"text","text":"bonjour"}]},"finish_reason":"model_length"}],"usage":{"prompt_tokens":3,"completion_tokens":2,"total_tokens":5}}
    """, headers: ["x-mistral": "yes"]))
    let provider = try AIProviders.mistral(configuration: MistralProviderSettings(apiKey: "mistral-key", transport: transport))
    let model = try provider.languageModel("mistral-large-latest")

    let result = try await model.generate(LanguageModelRequest(
        messages: [
            .system("Reply in French."),
            AIMessage(role: .user, content: [.text("See this"), .data(mimeType: "application/pdf", data: Data("pdf".utf8))])
        ],
        temperature: 0.2,
        topP: 0.9,
        topK: 4,
        presencePenalty: 0.1,
        frequencyPenalty: 0.2,
        seed: 123,
        maxOutputTokens: 16,
        reasoning: "high",
        tools: [
            "lookup": [
                "type": "object",
                "description": "Look up a value.",
                "properties": ["value": ["type": "string"]],
                "required": ["value"]
            ],
            "unused": ["type": "object"]
        ],
        providerOptions: ["mistral": ["promptCacheKey": "shared-prefix-1"]],
        extraBody: [
            "safePrompt": true,
            "randomSeed": 7,
            "documentPageLimit": 2,
            "parallelToolCalls": false,
            "toolChoice": ["type": "tool", "toolName": "lookup"]
        ]
        ))

    #expect(result.text == "bonjour")
    #expect(result.reasoning == "hmm")
    #expect(result.finishReason == "length")
    #expect(result.usage?.totalTokens == 5)
    #expect(result.warnings == [
        AIWarning(type: "unsupported", feature: "topK"),
        AIWarning(
            type: "unsupported",
            feature: "reasoning",
            message: "This model does not support reasoning configuration."
        )
    ])
    #expect(result.responseMetadata.id == "cmpl-1")
    #expect(result.responseMetadata.modelID == "mistral-large-latest")
    #expect(result.responseMetadata.headers["x-mistral"] == "yes")
    #expect(result.responseMetadata.body?["id"]?.stringValue == "cmpl-1")
    let request = try #require(await transport.requests().first)
    #expect(request.url.absoluteString == "https://api.mistral.ai/v1/chat/completions")
    #expect(request.headers["authorization"] == "Bearer mistral-key")
    let body = try decodeJSONBody(try #require(request.body))
    #expect(body["model"]?.stringValue == "mistral-large-latest")
    #expect(body["messages"]?[0]?["role"]?.stringValue == "system")
    #expect(body["messages"]?[1]?["content"]?[0]?["type"]?.stringValue == "text")
    #expect(body["messages"]?[1]?["content"]?[1]?["type"]?.stringValue == "document_url")
    #expect(body["messages"]?[1]?["content"]?[1]?["document_url"]?.stringValue?.hasPrefix("data:application/pdf;base64,") == true)
    #expect(body["safe_prompt"]?.boolValue == true)
    #expect(body["random_seed"]?.intValue == 7)
    #expect(body["document_page_limit"]?.intValue == 2)
    #expect(body["prompt_cache_key"]?.stringValue == "shared-prefix-1")
    #expect(body["promptCacheKey"] == nil)
    #expect(body["top_k"] == nil)
    #expect(body["presence_penalty"]?.doubleValue == 0.1)
    #expect(body["frequency_penalty"]?.doubleValue == 0.2)
    #expect(body["reasoning_effort"] == nil)
    #expect(body["tools"]?.arrayValue?.count == 1)
    #expect(body["tools"]?[0]?["type"]?.stringValue == "function")
    #expect(body["tools"]?[0]?["function"]?["name"]?.stringValue == "lookup")
    #expect(body["tools"]?[0]?["function"]?["description"]?.stringValue == "Look up a value.")
    #expect(body["tools"]?[0]?["function"]?["parameters"]?["properties"]?["value"]?["type"]?.stringValue == "string")
    #expect(body["tool_choice"]?.stringValue == "any")
    #expect(body["parallel_tool_calls"]?.boolValue == false)
}
@Test func mistralLanguageMapsStandardJsonResponseFormat() async throws {
    let transport = RecordingTransport(response: jsonResponse("""
    {"id":"cmpl-1","object":"chat.completion","model":"mistral-small-latest","choices":[{"index":0,"message":{"role":"assistant","content":"{\\"ok\\":true}"},"finish_reason":"stop"}],"usage":{"total_tokens":4}}
    """))
    let provider = try AIProviders.mistral(configuration: MistralProviderSettings(apiKey: "mistral-key", transport: transport))
    let model = try provider.languageModel("mistral-small-latest")

    _ = try await model.generate(LanguageModelRequest(
        messages: [.user("Return JSON.")],
        responseFormat: .json()
    ))

    let body = try decodeJSONBody(try #require((await transport.requests()).first?.body))
    #expect(body["response_format"]?["type"]?.stringValue == "json_object")
    #expect(body["messages"]?[0]?["role"]?.stringValue == "system")
    #expect(body["messages"]?[0]?["content"]?.stringValue == "You MUST answer with JSON.")
    #expect(body["messages"]?[1]?["role"]?.stringValue == "user")
    #expect(body["responseFormat"] == nil)
}
@Test func mistralProviderAddsVersionedUserAgentSuffix() async throws {
    let transport = RecordingTransport(response: jsonResponse("""
    {"id":"cmpl-1","object":"chat.completion","model":"mistral-small-latest","choices":[{"index":0,"message":{"role":"assistant","content":"done"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":2}}
    """))
    let provider = try AIProviders.mistral(configuration: MistralProviderSettings(
        apiKey: "mistral-key",
        headers: ["User-Agent": "custom-client/1.0"],
        transport: transport
    ))
    let model = try provider.languageModel("mistral-small-latest")

    _ = try await model.generate(LanguageModelRequest(messages: [.user("Hi")]))

    let request = try #require(await transport.requests().first)
    #expect(request.headers["authorization"] == "Bearer mistral-key")
    #expect(request.headers["user-agent"] == "custom-client/1.0 ai-sdk-mistral/4.0.72")
}
@Test func mistralMissingFinishReasonMapsToOtherAndUsageCountsCache() async throws {
    let transport = RecordingTransport(response: jsonResponse("""
    {"id":"cmpl-1","object":"chat.completion","model":"mistral-small-latest","choices":[{"index":0,"message":{"role":"assistant","content":"done"},"finish_reason":null}],"usage":{"prompt_tokens":10,"completion_tokens":2,"total_tokens":12,"num_cached_tokens":3,"prompt_audio_seconds":1.5,"completion_tokens_details":{"reasoning_tokens":1,"future":"kept"},"future_usage":{"nested":true}}}
    """))
    let provider = try AIProviders.mistral(configuration: MistralProviderSettings(apiKey: "mistral-key", transport: transport))
    let model = try provider.languageModel("mistral-small-latest")

    let result = try await model.generate(LanguageModelRequest(messages: [.user("Hi")]))

    #expect(result.finishReason == "other")
    #expect(result.usage?.inputTokens == 10)
    #expect(result.usage?.inputTokensNoCache == 7)
    #expect(result.usage?.inputTokensCacheRead == 3)
    #expect(result.usage?.outputTextTokens == 2)
    #expect(result.usage?.rawValue?["num_cached_tokens"]?.intValue == 3)
    #expect(result.usage?.rawValue?["prompt_audio_seconds"]?.doubleValue == 1.5)
    #expect(result.usage?.rawValue?["completion_tokens_details"]?["future"]?.stringValue == "kept")
    #expect(result.usage?.rawValue?["future_usage"]?["nested"]?.boolValue == true)
}

@Test func mistralPromptCacheKeyRequiresAString() async throws {
    let provider = try AIProviders.mistral(configuration: MistralProviderSettings(
        apiKey: "mistral-key",
        transport: RecordingTransport(response: jsonResponse("{}"))
    ))

    await #expect(throws: AIError.invalidArgument(
        argument: "providerOptions.mistral.promptCacheKey",
        message: "Mistral promptCacheKey must be a string."
    )) {
        _ = try await provider.languageModel("mistral-small-latest").generate(LanguageModelRequest(
            messages: [.user("Hi")],
            providerOptions: ["mistral": ["promptCacheKey": 7]]
        ))
    }
}