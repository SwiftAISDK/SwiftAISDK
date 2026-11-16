@testable import SwiftAIAzure
@testable import SwiftAIOpenAI
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translations of @ai-sdk/azure 4.0.126 `azure-openai-provider.test.ts` cases plus the
// shared OpenAIChatLanguageModel request policy that Azure chat inherits upstream.

private let parityAzureChatResponse = #"{"id":"chatcmpl-1","object":"chat.completion","created":1,"model":"test-deployment","choices":[{"index":0,"message":{"role":"assistant","content":"ok"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":2}}"#
private let parityAzureHelloJSON: JSONValue = [["role": "user", "content": "Hello"]]

private func parityAzureProvider(_ transport: RecordingTransport) throws -> AzureOpenAIProvider {
    try AIProviders.azure(resourceName: "test-resource", configuration: AzureOpenAIProviderSettings(apiKey: "test-api-key", transport: transport))
}

@Test func parityAzureChatAcceptsOptionsUnderTheAzureKey() async throws {
    let transport = RecordingTransport(response: jsonResponse(parityAzureChatResponse))
    _ = try await parityAzureProvider(transport).chat("test-deployment").generate(LanguageModelRequest(
        messages: [.user("Hello")], providerOptions: ["azure": ["user": "azure-user"]]
    ))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["user"] == "azure-user")
}

@Test func parityAzureChatMergesOpenAIAndAzureOptionsPreferringAzure() async throws {
    let transport = RecordingTransport(response: jsonResponse(parityAzureChatResponse))
    _ = try await parityAzureProvider(transport).chat("test-deployment").generate(LanguageModelRequest(
        messages: [.user("Hello")],
        providerOptions: ["openai": ["user": "openai-user", "logitBias": ["50256": -100]], "azure": ["user": "azure-user"]]
    ))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body["user"] == "azure-user")
    #expect(body["logit_bias"] == ["50256": -100])
}

// Upstream Azure chat is `OpenAIChatLanguageModel`, which always sends `json_schema` for schemas.
@Test func parityAzureChatSendsJSONSchemaResponseFormatWithoutStructuredOutputsSetting() async throws {
    let transport = RecordingTransport(response: jsonResponse(parityAzureChatResponse))
    let schema: JSONValue = ["type": "object", "properties": ["value": ["type": "string"]], "required": ["value"]]
    let result = try await parityAzureProvider(transport).chat("test-deployment").generate(LanguageModelRequest(
        messages: [.user("Hello")], responseFormat: .json(schema: schema, name: nil, description: nil)
    ))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body == [
        "model": "test-deployment",
        "messages": parityAzureHelloJSON,
        "response_format": ["type": "json_schema", "json_schema": ["name": "response", "strict": true, "schema": schema]]
    ])
    #expect(result.warnings.isEmpty)
}

@Test func parityAzureChatWarnsForAzureReasoningSummaryAndUnsupportedServiceTier() async throws {
    let transport = RecordingTransport(response: jsonResponse(parityAzureChatResponse))
    let result = try await parityAzureProvider(transport).chat("gpt-4o-mini").generate(LanguageModelRequest(
        messages: [.user("Hello")], providerOptions: ["azure": ["reasoningSummary": "auto", "serviceTier": "flex"]]
    ))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body == ["model": "gpt-4o-mini", "messages": parityAzureHelloJSON])
    #expect(result.warnings == [
        AIWarning(type: "unsupported", feature: "reasoningSummary", message: "reasoningSummary is only supported by the Responses API, not the Chat Completions API"),
        AIWarning(type: "unsupported", feature: "serviceTier", message: "flex processing is only available for o3, o4-mini, and gpt-5 models")
    ])
}

@Test func parityAzureDeepSeekSendsJSONSchemaResponseFormatForStructuredOutput() async throws {
    let transport = RecordingTransport(response: jsonResponse(parityAzureChatResponse))
    let schema: JSONValue = [
        "type": "object",
        "properties": ["sentiment": ["type": "string"]],
        "required": ["sentiment"],
        "additionalProperties": false
    ]
    _ = try await parityAzureProvider(transport).deepseek("deepseek-v4-flash").generate(LanguageModelRequest(
        messages: [.user("Hello")], responseFormat: .json(schema: schema, name: nil, description: nil), reasoning: "high"
    ))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body == [
        "messages": parityAzureHelloJSON,
        "model": "deepseek-v4-flash",
        "reasoning_effort": "high",
        "response_format": ["json_schema": ["name": "response", "schema": schema, "strict": true], "type": "json_schema"]
    ])
}

@Test func parityAzureDeepSeekParsesProviderOptionsFromTheAzureNamespace() async throws {
    let transport = RecordingTransport(response: jsonResponse(parityAzureChatResponse))
    _ = try await parityAzureProvider(transport).deepseek("deepseek-v4-flash").generate(LanguageModelRequest(
        messages: [.user("Hello")], reasoning: "high", providerOptions: ["azure": ["reasoningEffort": "max"]]
    ))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    #expect(body == ["messages": parityAzureHelloJSON, "model": "deepseek-v4-flash", "reasoning_effort": "max"])
}

// Upstream resolves the Azure OpenAI resource lazily (`getResourceName` runs per request),
// so Speech/MAI-only configurations can be created without one.
@Test func parityAzureAllowsAudioOnlyConfigurationAndFailsOpenAIRequestsLazily() async throws {
    let transport = RecordingTransport(response: jsonResponse(parityAzureChatResponse))
    let provider = try AIProviders.azure(
        configuration: AzureOpenAIProviderSettings(apiKey: "test-api-key", transport: transport),
        audioSettings: AzureOpenAIAudioSettings(speechBaseURL: "https://speech.example.com")
    )
    await #expect(throws: AIError.invalidURL("Azure requires ProviderSettings.baseURL or AZURE_RESOURCE_NAME/resourceName.")) {
        _ = try await provider.chat("test-deployment").generate(LanguageModelRequest(messages: [.user("Hello")]))
    }
    #expect(await transport.requests().isEmpty)
}
