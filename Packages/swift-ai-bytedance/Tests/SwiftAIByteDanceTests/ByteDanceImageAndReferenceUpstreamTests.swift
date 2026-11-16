@testable import SwiftAIByteDance
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translated from packages/bytedance/src/bytedance-image-model.test.ts and the
// inputReferences/webhook/failure cases of bytedance-video-model.test.ts.

private let seedreamPrompt = "A salamander in a forest pond at dusk surrounded by fireflies"
private let pngBytes = Data([137, 80, 78, 71])

private func imageResponse(_ json: String = #"{"data":[{"b64_json":"test1234"},{"b64_json":"test5678"}]}"#) -> AIHTTPResponse {
    jsonResponse(json)
}

private func byteDanceProvider(_ responses: [AIHTTPResponse], headers: [String: String] = [:]) throws -> (ByteDanceProvider, RecordingTransport) {
    let transport = RecordingTransport(responses: responses)
    let provider = try AIProviders.byteDance(configuration: ByteDanceProviderSettings(
        apiKey: "test-key", baseURL: "https://api.example.com", headers: headers, transport: transport))
    return (provider, transport)
}

private func generate(_ request: ImageGenerationRequest, response: AIHTTPResponse = imageResponse(),
                      headers: [String: String] = [:]) async throws -> (ImageGenerationResult, AIHTTPRequest) {
    let (provider, transport) = try byteDanceProvider([response], headers: headers)
    let result = try await provider.imageModel("seedream-5-0-260128").generateImage(request)
    return (result, try #require(await transport.requests().first))
}

@Suite("ByteDance image model (upstream)")
struct ByteDanceImageUpstreamTests {
    @Test(arguments: [
        ("seedream-5-0-260128", true), ("dola-seedream-5-0-pro-260628", true), ("seedream-5-0-lite-260128", true),
        ("seedream-4-5-251128", true), ("seedream-4-0-250828", true), ("not-seedream", false),
        ("custom-seedream-model", false), ("seedream-future", false), ("custom-image-model", false)
    ])
    func advertisesCapabilities(modelID: String, supported: Bool) async throws {
        let (provider, _) = try byteDanceProvider([])
        let model = try provider.imageModel(modelID)
        #expect(await model.supportsFileInputs == (supported ? true : nil))
        #expect(await model.supportsMaskInputs == (supported ? false : nil))
    }

    @Test("should expose correct provider and model information")
    func exposesProviderAndModel() throws {
        let (provider, _) = try byteDanceProvider([])
        let model = try #require(try provider.imageModel("seedream-5-0-260128") as? ByteDanceImageModel)
        #expect(model.providerID == "bytedance.image")
        #expect(model.modelID == "seedream-5-0-260128")
        #expect(model.maxImagesPerCall == 1)
        #expect(provider.supportedCapabilities.contains(.image))
    }

    @Test("should send a JSON text-to-image request to /images/generations")
    func sendsTextToImageRequest() async throws {
        let (_, request) = try await generate(ImageGenerationRequest(
            prompt: seedreamPrompt, size: "2048x2048", providerOptions: ["bytedance": ["watermark": false]]))
        #expect(request.url.absoluteString == "https://api.example.com/images/generations")
        #expect(try decodeJSONBody(try #require(request.body)) == [
            "model": "seedream-5-0-260128", "prompt": .string(seedreamPrompt), "size": "2048x2048",
            "watermark": false, "response_format": "b64_json"
        ])
    }

    @Test("should map typed provider options to ByteDance request fields")
    func mapsTypedProviderOptions() async throws {
        let (_, request) = try await generate(ImageGenerationRequest(prompt: seedreamPrompt, providerOptions: ["bytedance": [
            "sequentialImageGeneration": "auto", "maxImages": 4, "outputFormat": "png", "optimizePromptMode": "fast"
        ]]))
        #expect(try decodeJSONBody(try #require(request.body)) == [
            "model": "seedream-5-0-260128", "prompt": .string(seedreamPrompt),
            "sequential_image_generation": "auto", "sequential_image_generation_options": ["max_images": 4],
            "output_format": "png", "optimize_prompt_options": ["mode": "fast"], "response_format": "b64_json"
        ])
    }

    @Test("should let a resolution-level size override the top-level pixel size and pass unknown options")
    func sizeOverrideAndPassthrough() async throws {
        let (_, request) = try await generate(ImageGenerationRequest(
            prompt: seedreamPrompt, size: "2048x2048", providerOptions: ["bytedance": ["size": "2K", "seed": 42]]))
        let body = try decodeJSONBody(try #require(request.body))
        #expect(body["size"] == "2K")
        #expect(body["seed"] == 42)
    }

    @Test("should warn for unsupported settings (aspectRatio, seed, mask)")
    func warnsForUnsupportedSettings() async throws {
        let (result, _) = try await generate(ImageGenerationRequest(
            prompt: seedreamPrompt, aspectRatio: "16:9", seed: 123, mask: ImageInputFile(data: Data([1]), mediaType: "image/png")))
        #expect(result.warnings.map(\.feature) == ["aspectRatio", "seed", "mask"])
    }

    @Test("should pass headers")
    func passesHeaders() async throws {
        let (_, request) = try await generate(
            ImageGenerationRequest(prompt: seedreamPrompt, headers: ["Custom-Request-Header": "request-header-value"]),
            headers: ["Custom-Provider-Header": "provider-header-value"])
        // HTTP header names are case-insensitive; fetch lowercases them in the upstream harness.
        let headers = normalizeHeaders(request.headers)
        #expect(headers["custom-provider-header"] == "provider-header-value")
        #expect(headers["custom-request-header"] == "request-header-value")
        #expect(headers["content-type"] == "application/json")
    }

    @Test("should handle API errors")
    func handlesAPIErrors() async throws {
        let response = AIHTTPResponse(statusCode: 400, headers: ["content-type": "application/json"],
                                      body: Data(#"{"error":{"message":"Invalid prompt content","code":"InvalidParameter"}}"#.utf8))
        do {
            _ = try await generate(ImageGenerationRequest(prompt: seedreamPrompt), response: response)
            Issue.record("Expected an API error")
        } catch let error as AIError {
            let apiError = try #require(error.apiCallError)
            #expect(apiError.message == "Invalid prompt content")
            #expect(apiError.statusCode == 400)
            #expect(apiError.url == "https://api.example.com/images/generations")
        }
    }

    @Test("should return the raw b64_json content and response metadata")
    func returnsRawBase64() async throws {
        let (result, _) = try await generate(ImageGenerationRequest(prompt: seedreamPrompt))
        #expect(result.base64Images == ["test1234", "test5678"])
        #expect(result.responseMetadata.modelID == "seedream-5-0-260128")
        #expect(result.usage == nil)
    }

    @Test(arguments: [
        (#"{"data":[{"b64_json":"test1234"}],"usage":{"generated_images":1,"output_tokens":4096,"total_tokens":4096}}"#, 4096),
        (#"{"data":[{"b64_json":"test1234"},{"b64_json":"test5678"}],"usage":{"generated_images":2,"output_tokens":8192,"total_tokens":8192}}"#, 8192)
    ])
    func mapsArkTokenUsage(json: String, tokens: Int) async throws {
        let (result, _) = try await generate(ImageGenerationRequest(prompt: seedreamPrompt), response: imageResponse(json))
        #expect(result.usage == TokenUsage(inputTokens: nil, outputTokens: tokens, totalTokens: tokens))
    }

    @Test("should map null token fields to undefined")
    func mapsNullTokenFields() async throws {
        let (result, _) = try await generate(ImageGenerationRequest(prompt: seedreamPrompt), response: imageResponse(
            #"{"data":[{"b64_json":"test1234"}],"usage":{"generated_images":1,"output_tokens":null,"total_tokens":null}}"#))
        #expect(result.usage == TokenUsage())
    }

    @Test("should send single, multiple and URL input images in the `image` field")
    func sendsInputImages() async throws {
        let (single, singleRequest) = try await generate(ImageGenerationRequest(
            prompt: "Change the salamander to a snow weasel", files: [ImageInputFile(data: pngBytes, mediaType: "image/png")]))
        #expect(try decodeJSONBody(try #require(singleRequest.body)) == [
            "model": "seedream-5-0-260128", "prompt": "Change the salamander to a snow weasel",
            "image": "data:image/png;base64,iVBORw==", "response_format": "b64_json"
        ])
        #expect(single.base64Images == ["test1234", "test5678"])

        let (_, multipleRequest) = try await generate(ImageGenerationRequest(prompt: "Combine these images", files: [
            ImageInputFile(data: pngBytes, mediaType: "image/png"), ImageInputFile(data: pngBytes, mediaType: "image/png")
        ]))
        #expect(try decodeJSONBody(try #require(multipleRequest.body))["image"] == [
            "data:image/png;base64,iVBORw==", "data:image/png;base64,iVBORw=="
        ])

        let (_, urlRequest) = try await generate(ImageGenerationRequest(
            prompt: "Edit this", files: [ImageInputFile(url: "https://example.com/input.png")]))
        #expect(try decodeJSONBody(try #require(urlRequest.body))["image"] == "https://example.com/input.png")
    }
}

private func startVideo(_ request: VideoGenerationRequest, modelID: String = "dreamina-seedance-2-0-260128",
                        webhookURL: String? = nil) async throws -> (VideoGenerationOperationStartResult, JSONValue) {
    let (provider, transport) = try byteDanceProvider([jsonResponse(#"{"id":"test-task-id-123"}"#)])
    let model = try #require(try provider.videoModel(modelID) as? any AsyncVideoModel)
    let result = try await model.startVideoGeneration(.init(request: request, webhookURL: webhookURL))
    return (result, try decodeJSONBody(try #require(await transport.requests().first?.body)))
}

private let videoPrompt = "A futuristic city with flying cars"

@Suite("ByteDance video references (upstream)")
struct ByteDanceVideoReferenceUpstreamTests {
    @Test("should add a reference video from inputReferences with video media type")
    func referenceVideoFromInputReferences() async throws {
        let (_, body) = try await startVideo(VideoGenerationRequest(prompt: videoPrompt, inputReferences: [
            ImageInputFile(url: "https://example.com/a.mp4", mediaType: "video/mp4")
        ]))
        #expect(body["content"] == [
            ["type": "text", "text": .string(videoPrompt)],
            ["type": "video_url", "video_url": ["url": "https://example.com/a.mp4"], "role": "reference_video"]
        ])
    }

    @Test("should route a mix of video and image inputReferences by media type")
    func routesMixedReferences() async throws {
        let (_, body) = try await startVideo(VideoGenerationRequest(prompt: videoPrompt, inputReferences: [
            ImageInputFile(url: "https://example.com/a.mp4", mediaType: "video/mp4"),
            ImageInputFile(url: "https://example.com/b.png", mediaType: "image/png")
        ]))
        #expect(body["content"] == [
            ["type": "text", "text": .string(videoPrompt)],
            ["type": "video_url", "video_url": ["url": "https://example.com/a.mp4"], "role": "reference_video"],
            ["type": "image_url", "image_url": ["url": "https://example.com/b.png"], "role": "reference_image"]
        ])
    }

    @Test("should warn when a URL inputReference has no mediaType and treat it as an image reference")
    func warnsForURLReferenceWithoutMediaType() async throws {
        let (result, body) = try await startVideo(VideoGenerationRequest(prompt: videoPrompt, inputReferences: [
            ImageInputFile(url: "https://example.com/a.mp4")
        ]))
        #expect(result.warnings.contains(AIWarning(
            type: "unsupported", feature: "inputReferences",
            message: "ByteDance requires an explicit mediaType to route URL references as video or image. Pass { data: url, mediaType: \"video/mp4\" } for video references. The reference was treated as an image.")))
        #expect(body["content"] == [
            ["type": "text", "text": .string(videoPrompt)],
            ["type": "image_url", "image_url": ["url": "https://example.com/a.mp4"], "role": "reference_image"]
        ])
    }

    @Test("inputReferences replace provider reference videos, and frame images suppress them")
    func inputReferencesAndFramesSuppressProviderReferences() async throws {
        let (_, withReferences) = try await startVideo(VideoGenerationRequest(
            prompt: videoPrompt,
            inputReferences: [ImageInputFile(url: "https://example.com/new-ref.png", mediaType: "image/png")],
            providerOptions: ["bytedance": ["referenceVideos": ["https://example.com/legacy.mp4"]]]))
        #expect(withReferences["content"]?.arrayValue?.contains { $0["video_url"] != nil } == false)

        let (_, withFrames) = try await startVideo(VideoGenerationRequest(
            prompt: videoPrompt,
            frameImages: [VideoFrameImage(image: ImageInputFile(url: "https://example.com/last.png"), frameType: .lastFrame)],
            providerOptions: ["bytedance": ["referenceVideos": ["https://example.com/legacy.mp4"]]]))
        #expect(withFrames["content"] == [
            ["type": "text", "text": .string(videoPrompt)],
            ["type": "image_url", "image_url": ["url": "https://example.com/last.png"], "role": "last_frame"]
        ])
    }

    @Test("a start image becomes a reference image when only reference videos are present")
    func startImageWithReferenceVideos() async throws {
        let (_, body) = try await startVideo(VideoGenerationRequest(
            prompt: videoPrompt, image: ImageInputFile(url: "https://example.com/start.png"),
            providerOptions: ["bytedance": ["referenceVideos": ["https://example.com/ref.mp4"]]]))
        #expect(body["content"]?[1] == ["type": "image_url", "image_url": ["url": "https://example.com/start.png"], "role": "reference_image"])
    }

    @Test(arguments: [
        ("https://example.com/webhook", nil, "https://example.com/webhook"),
        (nil, nil, nil),
        (nil, "https://example.com/raw", "https://example.com/raw"),
        ("https://example.com/webhook", "https://example.com/raw", "https://example.com/webhook")
    ] as [(String?, String?, String?)])
    func submitsWebhook(webhookURL: String?, rawURL: String?, expected: String?) async throws {
        let options: JSONValue = rawURL.map { ["callback_url": .string($0)] } ?? .object([:])
        let (_, body) = try await startVideo(
            VideoGenerationRequest(prompt: videoPrompt, providerOptions: ["bytedance": options]),
            modelID: "seedance-1-0-pro-250528", webhookURL: webhookURL)
        #expect(body["callback_url"] == expected.map(JSONValue.string))
    }
}
