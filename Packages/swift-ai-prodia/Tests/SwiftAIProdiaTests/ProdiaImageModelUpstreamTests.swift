@testable import SwiftAIProdia
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translated from upstream `@ai-sdk/prodia` 2.0.84 `prodia-image-model.test.ts`.
// The JSON job is the raw request body, not a `{content, values}` wrapper.

private let upstreamImagePrompt = "A cute baby sea otter"
private let upstreamImageModelID = "inference.flux-fast.schnell.txt2img.v2"
private let upstreamImageJobURL = "https://api.example.com/v2/job?price=true"
private let upstreamDefaultImageJobResult = #"{"id":"job-123","created_at":"2025-01-01T00:00:00Z","updated_at":"2025-01-01T00:00:05Z","state":{"current":"completed"},"config":{"prompt":"A cute baby sea otter","seed":42},"metrics":{"elapsed":2.5,"ips":10.5},"price":{"product":"flux-fast.schnell","dollars":0.0025}}"#

private func upstreamImageModel(
    transport: RecordingTransport,
    headers: [String: String] = [:]
) throws -> any ImageModel {
    try AIProviders.prodia(configuration: ProdiaProviderSettings(
        apiKey: "test-key",
        baseURL: "https://api.example.com/v2",
        headers: headers,
        transport: transport
    )).imageModel(upstreamImageModelID)
}

/// Mirrors upstream `createMultipartResponse`.
private func upstreamImageResponse(
    jobResult: String = upstreamDefaultImageJobResult,
    imageContent: String = "test-binary-content"
) -> AIHTTPResponse {
    prodiaUpstreamMultipartResponse([
        prodiaUpstreamJobPart(jobResult),
        (name: "output", fileName: "output.png", contentType: "image/png", body: Data(imageContent.utf8))
    ])
}

private func sentBody(_ transport: RecordingTransport) async throws -> JSONValue {
    let request = try #require(await transport.requests().first)
    return try decodeJSONBody(try #require(request.body))
}

@Test func prodiaImageUpstreamAdvertisesThatEditingInputsAreUnsupported() async throws {
    let model = try upstreamImageModel(transport: RecordingTransport(response: upstreamImageResponse()))

    #expect(await model.supportsFileInputs == false)
    #expect(await model.supportsMaskInputs == false)
}

// describe('doGenerate')

@Test func prodiaImageUpstreamPassesTheCorrectParametersIncludingProviderOptions() async throws {
    let transport = RecordingTransport(response: upstreamImageResponse())

    _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(
        prompt: upstreamImagePrompt,
        seed: 12345,
        providerOptions: ["prodia": .object(["steps": 4])]
    ))

    #expect(try await sentBody(transport) == .object([
        "type": .string(upstreamImageModelID),
        "config": .object(["prompt": .string(upstreamImagePrompt), "seed": 12345, "steps": 4])
    ]))
}

@Test func prodiaImageUpstreamIncludesWidthAndHeightWhenSizeIsProvided() async throws {
    let transport = RecordingTransport(response: upstreamImageResponse())

    _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(
        prompt: upstreamImagePrompt,
        size: "1024x768"
    ))

    #expect(try await sentBody(transport) == .object([
        "type": .string(upstreamImageModelID),
        "config": .object(["prompt": .string(upstreamImagePrompt), "width": 1024, "height": 768])
    ]))
}

@Test func prodiaImageUpstreamProviderOptionsWidthHeightTakePrecedenceOverSize() async throws {
    let transport = RecordingTransport(response: upstreamImageResponse())

    _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(
        prompt: upstreamImagePrompt,
        size: "1024x768",
        providerOptions: ["prodia": .object(["width": 512, "height": 512])]
    ))

    #expect(try await sentBody(transport) == .object([
        "type": .string(upstreamImageModelID),
        "config": .object(["prompt": .string(upstreamImagePrompt), "width": 512, "height": 512])
    ]))
}

@Test func prodiaImageUpstreamIncludesStylePresetWhenProvided() async throws {
    let transport = RecordingTransport(response: upstreamImageResponse())

    _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(
        prompt: upstreamImagePrompt,
        providerOptions: ["prodia": .object(["stylePreset": "anime"])]
    ))

    #expect(try await sentBody(transport) == .object([
        "type": .string(upstreamImageModelID),
        "config": .object(["prompt": .string(upstreamImagePrompt), "style_preset": "anime"])
    ]))
}

@Test func prodiaImageUpstreamIncludesLorasWhenProvided() async throws {
    let transport = RecordingTransport(response: upstreamImageResponse())

    _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(
        prompt: upstreamImagePrompt,
        providerOptions: ["prodia": .object(["loras": ["prodia/lora/flux/anime@v1", "prodia/lora/flux/realism@v1"]])]
    ))

    #expect(try await sentBody(transport) == .object([
        "type": .string(upstreamImageModelID),
        "config": .object([
            "prompt": .string(upstreamImagePrompt),
            "loras": ["prodia/lora/flux/anime@v1", "prodia/lora/flux/realism@v1"]
        ])
    ]))
}

@Test func prodiaImageUpstreamIncludesProgressiveWhenProvided() async throws {
    let transport = RecordingTransport(response: upstreamImageResponse())

    _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(
        prompt: upstreamImagePrompt,
        providerOptions: ["prodia": .object(["progressive": true])]
    ))

    #expect(try await sentBody(transport) == .object([
        "type": .string(upstreamImageModelID),
        "config": .object(["prompt": .string(upstreamImagePrompt), "progressive": true])
    ]))
}

@Test func prodiaImageUpstreamCallsTheCorrectEndpoint() async throws {
    let transport = RecordingTransport(response: upstreamImageResponse())

    _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(prompt: upstreamImagePrompt))

    let request = try #require(await transport.requests().first)
    #expect(request.method == "POST")
    #expect(request.url.absoluteString == upstreamImageJobURL)
}

@Test func prodiaImageUpstreamSendsAcceptMultipartFormDataHeader() async throws {
    let transport = RecordingTransport(response: upstreamImageResponse())

    _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(prompt: upstreamImagePrompt))

    let request = try #require(await transport.requests().first)
    #expect(prodiaHeader(request, "accept") == "multipart/form-data; image/png")
}

@Test func prodiaImageUpstreamMergesProviderAndRequestHeaders() async throws {
    let transport = RecordingTransport(response: upstreamImageResponse())
    let model = try upstreamImageModel(transport: transport, headers: [
        "Custom-Provider-Header": "provider-header-value",
        "Authorization": "Bearer test-key"
    ])

    _ = try await model.generateImage(ImageGenerationRequest(
        prompt: upstreamImagePrompt,
        headers: ["Custom-Request-Header": "request-header-value"]
    ))

    let request = try #require(await transport.requests().first)
    #expect(prodiaHeader(request, "content-type") == "application/json")
    #expect(prodiaHeader(request, "custom-provider-header") == "provider-header-value")
    #expect(prodiaHeader(request, "custom-request-header") == "request-header-value")
    #expect(prodiaHeader(request, "authorization") == "Bearer test-key")
    #expect(prodiaHeader(request, "accept") == "multipart/form-data; image/png")
}

@Test func prodiaImageUpstreamReturnsImageBytesFromMultipartResponse() async throws {
    let result = try await upstreamImageModel(transport: RecordingTransport(response: upstreamImageResponse()))
        .generateImage(ImageGenerationRequest(prompt: upstreamImagePrompt))

    #expect(result.base64Images.count == 1)
    let image = try #require(result.base64Images.first.flatMap { Data(base64Encoded: $0) })
    #expect(String(decoding: image, as: UTF8.self) == "test-binary-content")
}

@Test func prodiaImageUpstreamReturnsProviderMetadataFromJobResult() async throws {
    let result = try await upstreamImageModel(transport: RecordingTransport(response: upstreamImageResponse()))
        .generateImage(ImageGenerationRequest(prompt: upstreamImagePrompt))

    #expect(result.providerMetadata["prodia"] == .object([
        "images": .array([
            .object([
                "jobId": "job-123",
                "seed": 42,
                "elapsed": 2.5,
                "iterationsPerSecond": 10.5,
                "createdAt": "2025-01-01T00:00:00Z",
                "updatedAt": "2025-01-01T00:00:05Z",
                "dollars": 0.0025
            ])
        ])
    ]))
}

@Test func prodiaImageUpstreamOmitsOptionalMetadataFieldsWhenNotPresentInJobResult() async throws {
    let result = try await upstreamImageModel(transport: RecordingTransport(response: upstreamImageResponse(
        jobResult: #"{"id":"job-456","state":{"current":"completed"},"config":{"prompt":"A cute baby sea otter"}}"#
    ))).generateImage(ImageGenerationRequest(prompt: upstreamImagePrompt))

    #expect(result.providerMetadata["prodia"] == .object(["images": .array([.object(["jobId": "job-456"])])]))
}

@Test func prodiaImageUpstreamWarnsOnInvalidSizeFormat() async throws {
    let result = try await upstreamImageModel(transport: RecordingTransport(response: upstreamImageResponse()))
        .generateImage(ImageGenerationRequest(prompt: upstreamImagePrompt, size: "invalid"))

    #expect(result.warnings == [
        AIWarning(
            type: "unsupported",
            feature: "size",
            message: "Invalid size format: invalid. Expected format: WIDTHxHEIGHT (e.g., 1024x1024)"
        )
    ])
}

@Test func prodiaImageUpstreamHandlesAPIErrors() async throws {
    let transport = RecordingTransport(response: AIHTTPResponse(
        statusCode: 400,
        headers: [:],
        body: Data(#"{"message":"Invalid prompt","detail":"Prompt cannot be empty"}"#.utf8)
    ))

    await #expect(throws: AIError.apiCall(provider: "prodia.image", statusCode: 400, body: "Prompt cannot be empty")) {
        _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(prompt: upstreamImagePrompt))
    }
    let request = try #require(await transport.requests().first)
    #expect(request.url.absoluteString == upstreamImageJobURL)
}

@Test func prodiaImageUpstreamIncludesDollarsInMetadataWhenPriceIsPresent() async throws {
    let result = try await upstreamImageModel(transport: RecordingTransport(response: upstreamImageResponse(
        jobResult: #"{"id":"job-789","state":{"current":"completed"},"config":{"prompt":"A cute baby sea otter"},"price":{"product":"flux-fast.schnell","dollars":0.005}}"#
    ))).generateImage(ImageGenerationRequest(prompt: upstreamImagePrompt))

    #expect(result.providerMetadata["prodia"] == .object(["images": .array([.object(["jobId": "job-789", "dollars": 0.005])])]))
}

@Test func prodiaImageUpstreamOmitsDollarsFromMetadataWhenPriceIsAbsent() async throws {
    let result = try await upstreamImageModel(transport: RecordingTransport(response: upstreamImageResponse(
        jobResult: #"{"id":"job-790","state":{"current":"completed"},"config":{"prompt":"A cute baby sea otter"}}"#
    ))).generateImage(ImageGenerationRequest(prompt: upstreamImagePrompt))

    #expect(result.providerMetadata["prodia"] == .object(["images": .array([.object(["jobId": "job-790"])])]))
}

@Test func prodiaImageUpstreamOmitsDollarsFromMetadataWhenPriceIsNull() async throws {
    let result = try await upstreamImageModel(transport: RecordingTransport(response: upstreamImageResponse(
        jobResult: #"{"id":"job-791","state":{"current":"completed"},"config":{"prompt":"A cute baby sea otter"},"price":null}"#
    ))).generateImage(ImageGenerationRequest(prompt: upstreamImagePrompt))

    #expect(result.providerMetadata["prodia"] == .object(["images": .array([.object(["jobId": "job-791"])])]))
}

@Test func prodiaImageUpstreamIncludesTimestampHeadersAndModelIDInResponseMetadata() async throws {
    // Upstream injects `_internal.currentDate`; Swift has no clock seam, so the
    // timestamp is checked against the request window.
    let before = Date()
    let result = try await upstreamImageModel(transport: RecordingTransport(response: upstreamImageResponse()))
        .generateImage(ImageGenerationRequest(prompt: upstreamImagePrompt))
    let after = Date()

    let timestamp = try #require(result.responseMetadata.timestamp)
    #expect(timestamp >= before && timestamp <= after)
    #expect(result.responseMetadata.modelID == upstreamImageModelID)
    #expect(result.responseMetadata.headers["content-type"] == "multipart/form-data; boundary=test-boundary-12345")
}

// describe('constructor')

@Test func prodiaImageUpstreamExposesCorrectProviderAndModelInformation() throws {
    let model = try #require(try upstreamImageModel(transport: RecordingTransport(response: upstreamImageResponse())) as? ProdiaImageModel)

    #expect(model.providerID == "prodia.image")
    #expect(model.modelID == upstreamImageModelID)
    #expect(model.maxImagesPerCall == 1)
}

// Local: upstream omits empty `loras` (`prodia-image-model.ts`
// `prodiaOptions.loras.length > 0`).

@Test func prodiaImageOmitsEmptyLorasLikeUpstream() async throws {
    let transport = RecordingTransport(response: upstreamImageResponse())

    _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(
        prompt: upstreamImagePrompt,
        providerOptions: ["prodia": .object(["loras": []])]
    ))

    #expect(try await sentBody(transport) == .object([
        "type": .string(upstreamImageModelID),
        "config": .object(["prompt": .string(upstreamImagePrompt)])
    ]))
}
