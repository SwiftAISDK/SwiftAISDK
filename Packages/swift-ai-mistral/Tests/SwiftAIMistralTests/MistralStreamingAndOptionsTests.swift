@testable import SwiftAIMistral
import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Testing
import SwiftAI


@Test func mistralModelsMapNestedProviderOptions() async throws {
    let chatTransport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"role":"assistant","content":"ok"},"finish_reason":"stop"}]}"#))
    let chatProvider = try AIProviders.mistral(configuration: MistralProviderSettings(apiKey: "mistral-key", transport: chatTransport))
    let chatModel = try chatProvider.languageModel("mistral-small-latest")

    _ = try await chatModel.generate(LanguageModelRequest(
        messages: [.user("Hi")],
        tools: ["lookup": ["type": "object", "properties": [:]]],
        providerOptions: [
            "mistral": [
                "safePrompt": true,
                "documentImageLimit": 5,
                "documentPageLimit": 7,
                "parallelToolCalls": false,
                "reasoningEffort": "none",
                "randomSeed": 99,
                "unsupported": "drop-me"
            ],
            "cohere": [
                "safePrompt": true
            ]
        ],
        extraBody: [
            "safePrompt": false,
            "mistral": [
                "safePrompt": false,
                "randomSeed": 11,
                "documentImageLimit": 3,
                "parallelToolCalls": true,
                "reasoningEffort": "high",
                "rawExtra": "keep-me"
            ]
        ]
    ))

    let chatRequest = try #require(await chatTransport.requests().first)
    let chatBody = try decodeJSONBody(try #require(chatRequest.body))
    #expect(chatBody["mistral"] == nil)
    #expect(chatBody["cohere"] == nil)
    #expect(chatBody["unsupported"] == nil)
    #expect(chatBody["safe_prompt"]?.boolValue == true)
    #expect(chatBody["random_seed"]?.intValue == 11)
    #expect(chatBody["document_image_limit"]?.intValue == 5)
    #expect(chatBody["document_page_limit"]?.intValue == 7)
    #expect(chatBody["parallel_tool_calls"]?.boolValue == false)
    #expect(chatBody["reasoning_effort"]?.stringValue == "none")
    #expect(chatBody["rawExtra"]?.stringValue == "keep-me")

    let embeddingTransport = RecordingTransport(response: jsonResponse(#"{"data":[{"embedding":[0.1,0.2]}]}"#))
    let embeddingProvider = try AIProviders.mistral(configuration: MistralProviderSettings(apiKey: "mistral-key", transport: embeddingTransport))
    let embeddingModel = try embeddingProvider.embeddingModel("mistral-embed")

    _ = try await embeddingModel.embed(EmbeddingRequest(
        values: ["hello"],
        extraBody: ["mistral": ["encoding_format": "float"]]
    ))

    let embeddingRequest = try #require(await embeddingTransport.requests().first)
    let embeddingBody = try decodeJSONBody(try #require(embeddingRequest.body))
    #expect(embeddingBody["mistral"] == nil)
    #expect(embeddingBody["encoding_format"]?.stringValue == "float")
}
@Test func mistralLanguageProviderOptionsRejectInvalidSchemaFields() async throws {
    let provider = try AIProviders.mistral(configuration: MistralProviderSettings(apiKey: "mistral-key", transport: RecordingTransport(responses: [])))
    let model = try provider.languageModel("mistral-small-latest")

    await #expect(throws: AIError.invalidArgument(argument: "providerOptions.mistral", message: "Mistral provider options must be an object.")) {
        _ = try await model.generate(LanguageModelRequest(
            messages: [.user("Hi")],
            providerOptions: ["mistral": "not-an-object"]
        ))
    }

    await #expect(throws: AIError.invalidArgument(argument: "providerOptions.mistral.safePrompt", message: "Mistral safePrompt cannot be null.")) {
        _ = try await model.generate(LanguageModelRequest(
            messages: [.user("Hi")],
            providerOptions: ["mistral": .object(["safePrompt": .null])]
        ))
    }

    await #expect(throws: AIError.invalidArgument(argument: "providerOptions.mistral.parallelToolCalls", message: "Mistral parallelToolCalls must be a boolean.")) {
        _ = try await model.generate(LanguageModelRequest(
            messages: [.user("Hi")],
            providerOptions: ["mistral": .object(["parallelToolCalls": "false"])]
        ))
    }

    await #expect(throws: AIError.invalidArgument(argument: "providerOptions.mistral.documentImageLimit", message: "Mistral documentImageLimit must be a number.")) {
        _ = try await model.generate(LanguageModelRequest(
            messages: [.user("Hi")],
            providerOptions: ["mistral": .object(["documentImageLimit": "5"])]
        ))
    }

    await #expect(throws: AIError.invalidArgument(argument: "providerOptions.mistral.reasoningEffort", message: "Mistral reasoningEffort must be high or none.")) {
        _ = try await model.generate(LanguageModelRequest(
            messages: [.user("Hi")],
            providerOptions: ["mistral": .object(["reasoningEffort": "medium"])]
        ))
    }
}