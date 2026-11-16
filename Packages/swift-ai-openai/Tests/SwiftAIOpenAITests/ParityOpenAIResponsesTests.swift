@testable import SwiftAIOpenAICompatible
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing
@testable import SwiftAIOpenAI

// Translations of @ai-sdk/openai 4.0.118 Responses tests that cover request options and
// `convertToOpenAIResponsesInput` user/system message conversion.

private let parityResponsesEmptyResponse = #"{"id":"resp_1","status":"completed","output":[]}"#
private let parityResponsesHelloJSON: JSONValue = ["role": "user", "content": [["type": "input_text", "text": "Hello"]]]

private func parityResponsesRequest(
    _ modelID: String,
    _ request: LanguageModelRequest,
    name: String? = nil
) async throws -> (body: [String: JSONValue], warnings: [AIWarning]) {
    let transport = RecordingTransport(response: jsonResponse(parityResponsesEmptyResponse))
    let provider = try AIProviders.openAI(configuration: OpenAIProviderSettings(apiKey: "test-key", transport: transport, name: name))
    let result = try await provider.responses(modelID).generate(request)
    let body = try decodeJSONBody(try #require((await transport.requests()).first?.body))
    return (try #require(body.objectValue), result.warnings)
}

// MARK: openai-responses-language-model.test.ts

@Test func parityResponsesWarnsAndDropsFastServiceTierWithoutPriorityProcessing() async throws {
    let (body, warnings) = try await parityResponsesRequest("gpt-5-nano", LanguageModelRequest(
        messages: [.user("Hello")], providerOptions: ["openai": ["serviceTier": "fast"]]
    ))
    #expect(body["service_tier"] == nil)
    #expect(warnings == [AIWarning(
        type: "unsupported",
        feature: "serviceTier",
        message: "priority processing is only available for supported models (gpt-4, gpt-5, gpt-5-mini, o3, o4-mini) and requires Enterprise access. gpt-5-nano is not supported"
    )])
}

// Supplements the upstream Chat flex cases with the shared Responses validation branch.
@Test func parityResponsesWarnsAndDropsFlexServiceTierForUnsupportedModel() async throws {
    let (body, warnings) = try await parityResponsesRequest("gpt-4o-mini", LanguageModelRequest(
        messages: [.user("Hello")], providerOptions: ["openai": ["serviceTier": "flex"]]
    ))
    #expect(body["service_tier"] == nil)
    #expect(warnings == [AIWarning(
        type: "unsupported",
        feature: "serviceTier",
        message: "flex processing is only available for o3, o4-mini, and gpt-5 models"
    )])
    let (supported, supportedWarnings) = try await parityResponsesRequest("o4-mini", LanguageModelRequest(
        messages: [.user("Hello")], providerOptions: ["openai": ["serviceTier": "flex"]]
    ))
    #expect(supported["service_tier"] == "flex")
    #expect(supportedWarnings.isEmpty)
}

@Test func parityResponsesStripsSamplingAndLogprobSettingsForGPT6InUpstreamOrder() async throws {
    let (body, warnings) = try await parityResponsesRequest("gpt-6-astra", LanguageModelRequest(
        messages: [.user("Hello")],
        temperature: 0.5,
        topP: 0.7,
        providerOptions: ["openai": [
            "reasoningEffort": "low",
            "logprobs": 5,
            "include": ["message.output_text.logprobs"]
        ]]
    ))
    #expect(body == [
        "model": "gpt-6-astra",
        "input": [parityResponsesHelloJSON],
        "reasoning": ["effort": "low", "summary": "detailed"]
    ])
    #expect(warnings == [
        AIWarning(type: "unsupported", feature: "temperature", message: "temperature is not supported for reasoning models"),
        AIWarning(type: "unsupported", feature: "topP", message: "topP is not supported for reasoning models"),
        AIWarning(type: "unsupported", feature: "logprobs", message: "logprobs is not supported for reasoning models")
    ])
}

@Test func parityResponsesDoesNotIncludeWebSearchSourcesWhenDisabledByProviderOptions() async throws {
    let (body, _) = try await parityResponsesRequest("gpt-5-nano", LanguageModelRequest(
        messages: [.user("Hello")],
        tools: ["webSearch": ["type": "provider", "id": "openai.web_search", "name": "webSearch", "args": [:]]],
        providerOptions: ["openai": ["includeWebSearchSources": false]]
    ))
    #expect(body["include"] == nil)
    #expect(body["includeWebSearchSources"] == nil)
}

// MARK: convert-to-openai-responses-input.test.ts — system messages

@Test(arguments: [("system", "system"), ("developer", "developer")])
func parityResponsesConvertsSystemMessagesWithSystemMessageMode(mode: String, role: String) async throws {
    let (body, warnings) = try await parityResponsesRequest("gpt-4o", LanguageModelRequest(
        messages: [.system("Hello")], providerOptions: ["openai": ["systemMessageMode": .string(mode)]]
    ))
    #expect(body["input"] == [["role": .string(role), "content": "Hello"]])
    #expect(body["systemMessageMode"] == nil)
    #expect(warnings.isEmpty)
}

@Test func parityResponsesRemovesSystemMessages() async throws {
    let (body, warnings) = try await parityResponsesRequest("gpt-4o", LanguageModelRequest(
        messages: [.system("Hello")], providerOptions: ["openai": ["systemMessageMode": "remove"]]
    ))
    #expect(body["input"] == [])
    #expect(warnings == [AIWarning(type: "other", message: "system messages are removed for this model")])
}

@Test func parityResponsesAddsPromptCacheBreakpointToSystemMessage() async throws {
    let (body, _) = try await parityResponsesRequest("o4-mini", LanguageModelRequest(
        messages: [AIMessage(
            role: .system,
            content: [.text("Hello")],
            providerMetadata: ["openai": ["promptCacheBreakpoint": ["mode": "explicit"]]]
        )]
    ))
    #expect(body["input"] == [[
        "role": "developer",
        "content": [["type": "input_text", "text": "Hello", "prompt_cache_breakpoint": ["mode": "explicit"]]]
    ]])
}

// MARK: convert-to-openai-responses-input.test.ts — user messages

@Test func parityResponsesAddsPromptCacheBreakpointsToSupportedContentBlocks() async throws {
    let breakpoint: JSONValue = ["mode": "explicit"]
    let (body, _) = try await parityResponsesRequest("gpt-4o", LanguageModelRequest(messages: [AIMessage(role: .user, content: [
        .text("Hello", providerMetadata: ["openai": ["promptCacheBreakpoint": breakpoint]]),
        .imageURL("https://example.com/image.png", providerMetadata: ["openai": ["promptCacheBreakpoint": breakpoint]]),
        .providerReference(
            mimeType: "application/pdf",
            reference: ["openai": "file-pdf-123"],
            providerMetadata: ["openai": ["promptCacheBreakpoint": breakpoint]]
        )
    ])]))
    #expect(body["input"] == [[
        "role": "user",
        "content": [
            ["type": "input_text", "text": "Hello", "prompt_cache_breakpoint": breakpoint],
            ["type": "input_image", "image_url": "https://example.com/image.png", "prompt_cache_breakpoint": breakpoint],
            ["type": "input_file", "file_id": "file-pdf-123", "prompt_cache_breakpoint": breakpoint]
        ]
    ]])
}

@Test(arguments: ["openai", "azure"])
func parityResponsesAddsImageDetailFromProviderOptions(providerOptionsName: String) async throws {
    let (body, _) = try await parityResponsesRequest(
        "gpt-4o",
        LanguageModelRequest(messages: [AIMessage(role: .user, content: [
            .file(mimeType: "image/png", data: Data([0, 1, 2, 3]), providerMetadata: [providerOptionsName: ["imageDetail": "low"]])
        ])]),
        name: providerOptionsName == "azure" ? "azure" : nil
    )
    #expect(body["input"] == [[
        "role": "user",
        "content": [["type": "input_image", "image_url": "data:image/png;base64,AAECAw==", "detail": "low"]]
    ]])
}

@Test func parityResponsesUsesDefaultFilenameForPDFFileParts() async throws {
    let (body, _) = try await parityResponsesRequest("gpt-4o", LanguageModelRequest(messages: [AIMessage(role: .user, content: [
        .file(mimeType: "application/pdf", data: Data(base64Encoded: "AQIDBAU=")!)
    ])]))
    #expect(body["input"] == [[
        "role": "user",
        "content": [["type": "input_file", "filename": "part-0.pdf", "file_data": "data:application/pdf;base64,AQIDBAU="]]
    ]])
}

@Test func parityResponsesUsesProvidedFilenameForPDFFileParts() async throws {
    let (body, _) = try await parityResponsesRequest("gpt-4o", LanguageModelRequest(messages: [AIMessage(role: .user, content: [
        .file(mimeType: "application/pdf", data: Data(base64Encoded: "AQIDBAU=")!, filename: "document.pdf")
    ])]))
    #expect(body["input"]?[0]?["content"]?[0]?["filename"] == "document.pdf")
}

@Test func parityResponsesThrowsForUnsupportedFileTypes() async throws {
    let transport = RecordingTransport(response: jsonResponse(parityResponsesEmptyResponse))
    let provider = try AIProviders.openAI(configuration: OpenAIProviderSettings(apiKey: "test-key", transport: transport))
    await #expect(throws: AIError.invalidArgument(argument: "messages", message: "'file part media type text/plain' functionality not supported.")) {
        _ = try await provider.responses("gpt-4o").generate(LanguageModelRequest(messages: [AIMessage(role: .user, content: [
            .file(mimeType: "text/plain", data: Data(base64Encoded: "AQIDBAU=")!)
        ])]))
    }
    #expect(await transport.requests().isEmpty)
}

@Test func parityResponsesPassesThroughUnsupportedFileTypesWhenEnabled() async throws {
    let base64Data = "bmFtZSxyb2xlCkFkYSxlbmdpbmVlcgo="
    let (body, _) = try await parityResponsesRequest("gpt-4o", LanguageModelRequest(
        messages: [AIMessage(role: .user, content: [
            .file(mimeType: "text/csv", data: Data(base64Encoded: base64Data)!, filename: "names.csv")
        ])],
        providerOptions: ["openai": ["passThroughUnsupportedFiles": true]]
    ))
    #expect(body["input"] == [[
        "role": "user",
        "content": [["type": "input_file", "filename": "names.csv", "file_data": .string("data:text/csv;base64,\(base64Data)")]]
    ]])
    #expect(body["passThroughUnsupportedFiles"] == nil)
}

// MARK: openai-responses-reasoning-effort-update.test.ts

@Test func parityResponsesRejectsHistoricalNoneUpdatesForAstraWithUpstreamMessage() async throws {
    let transport = RecordingTransport(response: jsonResponse(parityResponsesEmptyResponse))
    let provider = try AIProviders.openAI(configuration: OpenAIProviderSettings(apiKey: "test-key", transport: transport))
    let update = AIMessage(role: .system, content: [.text("")], providerMetadata: ["openai": ["reasoningEffortUpdate": "none"]])
    await #expect(throws: AIError.invalidArgument(
        argument: "messages.providerMetadata.openai.reasoningEffortUpdate",
        message: "gpt-6-astra only supports the following reasoning efforts: low, medium, high, xhigh, max"
    )) {
        _ = try await provider.responses("gpt-6-astra").generate(LanguageModelRequest(messages: [.user("Question"), update, .user("Question")]))
    }
    #expect(await transport.requests().isEmpty)
}
