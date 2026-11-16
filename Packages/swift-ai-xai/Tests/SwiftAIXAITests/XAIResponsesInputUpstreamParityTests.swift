@testable import SwiftAIXAI
@testable import SwiftAIOpenAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translations of @ai-sdk/xai 5.0.46 responses/convert-to-xai-responses-input.test.ts and the
// xai-image-model / xai-video-model provider-metadata cases that previously diverged.

private let xaiPNGBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

private func xaiResponsesInput(_ messages: [AIMessage]) async throws -> (input: JSONValue?, warnings: [AIWarning]) {
    let transport = RecordingTransport(response: jsonResponse(#"{"id":"resp-1","status":"completed","output_text":"done"}"#))
    let provider = try AIProviders.xAI(configuration: XAIProviderSettings(apiKey: "xai-key", transport: transport))
    let result = try await provider.responses("grok-4.3").generate(LanguageModelRequest(messages: messages))
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    return (body["input"], result.warnings)
}

@Test func xAIUpstreamRoundTripsReasoningWithEncryptedContent() async throws {
    let (input, warnings) = try await xaiResponsesInput([
        .user("What is the capital of France?"),
        AIMessage(role: .assistant, content: [
            .reasoning("The user is asking about geography.", providerMetadata: ["xai": ["itemId": "rs_789", "reasoningEncryptedContent": "encrypted_xyz"]]),
            .text("The capital of France is Paris.")
        ]),
        .user("And what about Germany?")
    ])
    #expect(input == [
        ["role": "user", "content": [["type": "input_text", "text": "What is the capital of France?"]]],
        [
            "encrypted_content": "encrypted_xyz",
            "id": "rs_789",
            "status": "completed",
            "summary": [["text": "The user is asking about geography.", "type": "summary_text"]],
            "type": "reasoning"
        ],
        ["content": "The capital of France is Paris.", "role": "assistant"],
        ["role": "user", "content": [["type": "input_text", "text": "And what about Germany?"]]]
    ])
    #expect(warnings.isEmpty)
}

@Test func xAIUpstreamSkipsReasoningWithoutItemIDOrEncryptedContent() async throws {
    let (input, warnings) = try await xaiResponsesInput([
        AIMessage(role: .assistant, content: [.reasoning("thinking"), .text("answer", providerMetadata: ["xai": ["itemId": "msg_1"]])])
    ])
    #expect(input == [["content": "answer", "role": "assistant", "id": "msg_1"]])
    #expect(warnings.map(\.message) == ["Reasoning parts without itemId or encrypted content cannot be sent back to xAI. Skipping."])
}

@Test func xAIUpstreamPreservesImageURLsInContentOutput() async throws {
    let (input, _) = try await xaiResponsesInput([
        AIMessage(role: .tool, content: [
            .toolResult(AIToolResult(
                toolCallID: "call_123",
                toolName: "inspectImage",
                result: .null,
                modelOutput: ["type": "content", "value": [
                    ["type": "text", "text": "The requested image is attached."],
                    ["type": "file", "mediaType": "image/png", "data": ["type": "url", "url": "https://example.com/image.png"]]
                ]]
            ))
        ])
    ])
    #expect(input == [[
        "call_id": "call_123",
        "output": [
            ["text": "The requested image is attached.", "type": "input_text"],
            ["image_url": "https://example.com/image.png", "type": "input_image"]
        ],
        "type": "function_call_output"
    ]])
}

@Test(arguments: ["image", "image/*", "image/png"])
func xAIUpstreamResolvesImageMediaTypeForInlineData(mediaType: String) async throws {
    let (input, _) = try await xaiResponsesInput([
        AIMessage(role: .user, content: [.data(mimeType: mediaType, data: try #require(Data(base64Encoded: xaiPNGBase64)))])
    ])
    #expect(input == [["role": "user", "content": [[
        "type": "input_image",
        "image_url": .string("data:image/png;base64,\(xaiPNGBase64)")
    ]]]])
}

@Test func xAIUpstreamPassesImageDetailFilePartOption() async throws {
    let (input, _) = try await xaiResponsesInput([
        AIMessage(role: .user, content: [.imageURL("https://example.com/x.png", providerMetadata: ["xai": ["imageDetail": "high"]])])
    ])
    #expect(input == [["role": "user", "content": [[
        "type": "input_image",
        "image_url": "https://example.com/x.png",
        "detail": "high"
    ]]]])
}

@Test func xAIUpstreamStringifiesJSONToolOutputWithoutEscapingSlashes() async throws {
    let (input, _) = try await xaiResponsesInput([
        AIMessage(role: .tool, content: [
            .toolResult(AIToolResult(toolCallID: "call_1", toolName: "fetch", result: .null, modelOutput: ["type": "json", "value": ["url": "https://example.com/a"]]))
        ])
    ])
    #expect(input?[0]?["output"] == #"{"url":"https://example.com/a"}"#)
}

@Test func xAIUpstreamOmitsNullImageProviderMetadataFields() async throws {
    let transport = RecordingTransport(response: jsonResponse(#"{"data":[{"b64_json":"aW1n","revised_prompt":""}],"usage":{"cost_in_usd_ticks":null}}"#))
    let provider = try AIProviders.xAI(configuration: XAIProviderSettings(apiKey: "xai-key", transport: transport))
    let result = try await provider.imageModel("grok-imagine-image").generateImage(ImageGenerationRequest(prompt: "A cat"))
    #expect(result.providerMetadata["xai"] == ["images": [[:]]])
}
