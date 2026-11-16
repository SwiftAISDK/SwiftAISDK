import Foundation
import Testing
@testable import SwiftAIMiniMax
import SwiftAIProvider
import SwiftAITransport

// Translated from packages/minimax/src/minimax-image-model.test.ts.

private let imageURL = "https://api.example.com/generated.png"
private let image: JSONValue = ["url": .string(imageURL), "size": "1024x1024", "revised_prompt": "A red circle."]
private let usage: JSONValue = [
    "generated_images": 1, "input_tokens": 30, "output_tokens": 40, "total_tokens": 70,
    "input_tokens_details": ["text_tokens": 10, "image_tokens": 20],
    "output_tokens_details": ["image_tokens": 40]
]

private func json(_ value: JSONValue) throws -> AIHTTPResponse {
    AIHTTPResponse(statusCode: 200, headers: ["content-type": "application/json"], body: try encodeJSONBody(value))
}

private func pngResponse() -> AIHTTPResponse {
    AIHTTPResponse(statusCode: 200, headers: ["content-type": "image/png"], body: Data([1, 2, 3]))
}

private func imageModel(_ transport: RecordingTransport) throws -> MiniMaxImageModel {
    try MiniMaxProvider(configuration: .init(
        apiKey: "test-key",
        imageBaseURL: "https://api.example.com/v1",
        headers: ["custom-header": "value"],
        transport: transport
    )).image("MiniMax-H3-Image")
}

@Suite("MiniMax image model (upstream)")
struct MiniMaxImageUpstreamParityTests {
    @Test func generatesAndDownloadsImagesWhilePreservingUsage() async throws {
        let transport = RecordingTransport(responses: [
            try json(["data": [image], "usage": usage, "output_format": "png", "request_id": "request-1"]),
            pngResponse()
        ])
        let result = try await imageModel(transport).generateImage(.init(
            prompt: "A red circle.",
            size: "1024x1024",
            seed: 1,
            count: 1,
            providerOptions: ["minimax": ["disablePromptEnhanced": true, "outputFormat": "png", "outputCompression": 90]],
            headers: ["request-header": "request"]
        ))
        let requests = await transport.requests()
        #expect(try decodeJSONBody(try #require(requests[0].body)) == [
            "model": "MiniMax-H3-Image", "prompt": "A red circle.", "n": 1, "size": "1024x1024",
            "disable_prompt_enhanced": true, "output_format": "png", "output_compression": 90, "response_format": "url"
        ])
        let headers = normalizeHeaders(requests[0].headers)
        #expect(headers["authorization"] == "Bearer test-key")
        #expect(headers["custom-header"] == "value")
        #expect(headers["request-header"] == "request")
        #expect(normalizeHeaders(requests[1].headers)["authorization"] == nil)
        #expect(normalizeHeaders(requests[1].headers)["custom-header"] == nil)
        #expect(result.base64Images == [Data([1, 2, 3]).base64EncodedString()])
        #expect(result.usage?.inputTokens == 30)
        #expect(result.usage?.outputTokens == 40)
        #expect(result.usage?.totalTokens == 70)
        #expect(result.providerMetadata["minimax"] == ["images": [[
            "size": "1024x1024", "revisedPrompt": "A red circle.", "usage": usage, "outputFormat": "png", "requestId": "request-1"
        ]]])
        #expect(result.warnings == [AIWarning(type: "unsupported", feature: "seed")])
    }

    @Test func mapsAspectRatioAreaAndBatchSizeWithoutSupplyingAPixelSize() async throws {
        var batchUsage = try #require(usage.objectValue)
        batchUsage["generated_images"] = 2
        let transport = RecordingTransport(responses: [
            try json(["data": [image, image], "usage": .object(batchUsage)]),
            pngResponse(),
            pngResponse()
        ])
        let result = try await imageModel(transport).generateImage(.init(
            prompt: "A red circle.", aspectRatio: "16:9", count: 2, providerOptions: ["minimax": ["area": "2K"]]
        ))
        #expect(try decodeJSONBody(try #require(await transport.requests().first?.body)) == [
            "model": "MiniMax-H3-Image", "prompt": "A red circle.", "n": 2, "aspect_ratio": "16:9", "area": "2K", "response_format": "url"
        ])
        #expect(result.providerMetadata["minimax"]?["images"] == [
            ["size": "1024x1024", "revisedPrompt": "A red circle.", "usage": .object(batchUsage)],
            ["size": "1024x1024", "revisedPrompt": "A red circle."]
        ])
    }

    @Test func editsBinaryAndURLReferencesAndOmitsTheGenerationOnlyPromptOption() async throws {
        let transport = RecordingTransport(responses: [try json(["data": [image], "usage": usage]), pngResponse()])
        let result = try await imageModel(transport).generateImage(.init(
            prompt: "A red circle.",
            count: 1,
            files: [.init(data: Data([1, 2, 3]), mediaType: "image/png"), .init(url: "https://example.com/reference.png")],
            providerOptions: ["minimax": ["disablePromptEnhanced": true]]
        ))
        let request = try #require(await transport.requests().first)
        #expect(request.url.absoluteString == "https://api.example.com/v1/images/edits")
        #expect(try decodeJSONBody(try #require(request.body)) == [
            "model": "MiniMax-H3-Image", "prompt": "A red circle.", "n": 1,
            "images": [["image_url": "data:image/png;base64,AQID"], ["image_url": "https://example.com/reference.png"]],
            "response_format": "url"
        ])
        #expect(result.warnings == [AIWarning(type: "unsupported", feature: "disablePromptEnhanced", message: "MiniMax image edits always apply prompt enhancement.")])
    }

    @Test func returnsSuccessfulImagesAndReportsPerImageFailuresWithoutLosingRequestUsage() async throws {
        let transport = RecordingTransport(responses: [
            try json(["data": [image, ["error": ["code": "1027", "message": "Content safety check failed."]]], "usage": usage]),
            pngResponse()
        ])
        let result = try await imageModel(transport).generateImage(.init(prompt: "A red circle.", count: 2))
        #expect(result.base64Images.count == 1)
        #expect(result.providerMetadata["minimax"]?["images"]?.arrayValue?.count == 1)
        #expect(result.providerMetadata["minimax"]?["images"]?[0]?["usage"] == usage)
        #expect(result.warnings == [AIWarning(type: "other", message: "Image 2 failed: Content safety check failed.")])
    }

    @Test func rejectsMasksBeforeSendingAnUnmaskedEdit() async throws {
        let transport = RecordingTransport(response: try json([:]))
        await #expect(throws: AIError.invalidArgument(argument: "mask", message: "MiniMax image masks are not supported.")) {
            _ = try await imageModel(transport).generateImage(.init(prompt: "A red circle.", mask: .init(data: Data([1]), mediaType: "image/png")))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func preservesTheProviderErrorMessage() async throws {
        let body = #"{"error":{"message":"Insufficient balance (1008)"}}"#
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 402, headers: ["content-type": "application/json"], body: Data(body.utf8)))
        do {
            _ = try await imageModel(transport).generateImage(.init(prompt: "A red circle.", count: 1))
            Issue.record("Expected an API call error")
        } catch let AIError.apiCall(error) {
            #expect(error.message == "Insufficient balance (1008)")
            #expect(error.responseBody == body)
            #expect(error.statusCode == 402)
        }
    }
}
