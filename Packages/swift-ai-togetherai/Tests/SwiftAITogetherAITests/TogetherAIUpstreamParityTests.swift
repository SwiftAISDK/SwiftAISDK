@testable import SwiftAITogetherAI
@testable import SwiftAIOpenAICompatible
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translations of the @ai-sdk/togetherai 3.0.94 tests:
// togetherai-image-model.test.ts, togetherai-provider.test.ts and
// reranking/togetherai-reranking-model.test.ts.

private let upstreamPrompt = "A cute baby sea otter"
private let upstreamImageResponse = #"{"id":"test-id","data":[{"index":0,"b64_json":"test-base64-content"}],"model":"stabilityai/stable-diffusion-xl","object":"list"}"#
private let upstreamEditingResponse = #"{"id":"test-id","data":[{"index":0,"b64_json":"test-base64-content"}],"model":"black-forest-labs/FLUX.1-kontext-pro","object":"list"}"#

private func upstreamImageModel(
    _ modelID: String = "stabilityai/stable-diffusion-xl",
    transport: any AITransport,
    headers: [String: String] = ["api-key": "test-key"]
) -> TogetherAIImageModel {
    let http = AIProviderHTTPClient(providerID: "togetherai", headers: headers, transport: transport, url: { _, path in
        try providerURL("https://api.example.com\(path)", queryParams: [:])
    })
    return TogetherAIImageModel(modelID: modelID, config: TogetherAIModelConfiguration(http: http, baseURL: "https://api.example.com"))
}

private func firstBody(_ transport: RecordingTransport) async throws -> JSONValue {
    try decodeJSONBody(try #require(await transport.requests().first?.body))
}

private actor AbortAwareTransport: AITransport {
    private(set) var requests: [AIHTTPRequest] = []
    func send(_ request: AIHTTPRequest) async throws -> AIHTTPResponse {
        requests.append(request)
        try request.abortSignal?.throwIfAborted()
        return jsonResponse(upstreamImageResponse)
    }
}

// MARK: - togetherai-image-model.test.ts

@Suite("TogetherAI image model upstream parity")
struct TogetherAIImageModelUpstreamTests {
    // describe('capabilities')
    @Test(arguments: [
        ("black-forest-labs/FLUX.1-kontext-pro", true, false),
        ("black-forest-labs/FLUX.1-kontext-max", true, false),
        ("black-forest-labs/FLUX.1-kontext-dev", true, false),
        ("black-forest-labs/FLUX.1-canny", true, false),
        ("black-forest-labs/FLUX.1-depth", true, false),
        ("black-forest-labs/FLUX.1-redux", true, false),
        ("black-forest-labs/FLUX.2-pro", true, false),
        ("black-forest-labs/FLUX.2-flex", true, false),
        ("black-forest-labs/FLUX.1-schnell", false, false),
        ("black-forest-labs/FLUX.2-dev", false, false),
        ("google/gemini-3-pro-image", false, false),
        ("stabilityai/stable-diffusion-xl-base-1.0", false, false)
    ] as [(String, Bool, Bool)])
    func advertisesKnownFileAndMaskSupport(_ fixture: (String, Bool, Bool)) {
        let model = upstreamImageModel(fixture.0, transport: RecordingTransport(response: jsonResponse(upstreamImageResponse)))
        #expect(model.supportsFileInputs == fixture.1)
        #expect(model.supportsMaskInputs == fixture.2)
    }

    @Test(arguments: [
        "black-forest-labs/custom-model",
        "stabilityai/custom-model",
        "black-forest-labs/FLUX.1-kontext-custom",
        "custom/FLUX.1-kontext-pro",
        "black-forest-labs/FLUX.2-custom",
        "google/gemini-custom",
        "custom/image-model"
    ])
    func advertisesUnknownFileAndMaskSupport(_ modelID: String) {
        let model = upstreamImageModel(modelID, transport: RecordingTransport(response: jsonResponse(upstreamImageResponse)))
        #expect(model.supportsFileInputs == nil)
        #expect(model.supportsMaskInputs == nil)
    }

    // describe('doGenerate')
    @Test func passesTheCorrectParametersIncludingSizeAndSeed() async throws {
        let transport = RecordingTransport(response: jsonResponse(upstreamImageResponse))
        _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(
            prompt: upstreamPrompt, size: "1024x1024", seed: 42, count: 1,
            providerOptions: ["togetherai": ["additional_param": "value"]]
        ))
        #expect(try await firstBody(transport) == [
            "model": "stabilityai/stable-diffusion-xl",
            "prompt": .string(upstreamPrompt),
            "seed": 42,
            "width": 1024,
            "height": 1024,
            "response_format": "base64",
            "additional_param": "value"
        ])
    }

    @Test func omitsSeedFromRequestBodyWhenSeedIsUndefined() async throws {
        let transport = RecordingTransport(response: jsonResponse(upstreamImageResponse))
        _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(prompt: upstreamPrompt, count: 1))
        let body = try await firstBody(transport)
        #expect(body["seed"] == nil)
        #expect(body == [
            "model": "stabilityai/stable-diffusion-xl",
            "prompt": .string(upstreamPrompt),
            "response_format": "base64"
        ])
    }

    @Test func omitsDiffusionOptionsForNonDiffusionModels() async throws {
        let transport = RecordingTransport(response: jsonResponse(upstreamImageResponse))
        let result = try await upstreamImageModel("google/gemini-3-pro-image", transport: transport).generateImage(ImageGenerationRequest(
            prompt: upstreamPrompt, size: "1264x848", seed: 42, count: 1,
            providerOptions: ["togetherai": [
                "steps": 20,
                "guidance": 3.5,
                "negative_prompt": "blurry",
                "disable_safety_checker": true,
                "additional_param": "value"
            ]]
        ))
        #expect(try await firstBody(transport) == [
            "model": "google/gemini-3-pro-image",
            "prompt": .string(upstreamPrompt),
            "width": 1264,
            "height": 848,
            "response_format": "base64",
            "additional_param": "value"
        ])
        #expect(result.warnings == [
            AIWarning(type: "unsupported", feature: "aspectRatio", message: "This model does not support the `aspectRatio` option. Use `size` instead."),
            AIWarning(type: "unsupported", feature: "seed", message: "The google/gemini-3-pro-image model does not support the `seed` option.")
        ])
    }

    @Test func includesNParameterWhenRequestingMultipleImages() async throws {
        let transport = RecordingTransport(response: jsonResponse(upstreamImageResponse))
        _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(prompt: upstreamPrompt, size: "1024x1024", seed: 42, count: 3))
        #expect(try await firstBody(transport) == [
            "model": "stabilityai/stable-diffusion-xl",
            "prompt": .string(upstreamPrompt),
            "seed": 42,
            "n": 3,
            "width": 1024,
            "height": 1024,
            "response_format": "base64"
        ])
    }

    @Test func callsTheCorrectURL() async throws {
        let transport = RecordingTransport(response: jsonResponse(upstreamImageResponse))
        _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(prompt: upstreamPrompt, size: "1024x1024", seed: 42, count: 1))
        let request = try #require(await transport.requests().first)
        #expect(request.method == "POST")
        #expect(request.url.absoluteString == "https://api.example.com/images/generations")
    }

    @Test func passesHeaders() async throws {
        let transport = RecordingTransport(response: jsonResponse(upstreamImageResponse))
        let model = upstreamImageModel(transport: transport, headers: ["Custom-Provider-Header": "provider-header-value"])
        _ = try await model.generateImage(ImageGenerationRequest(
            prompt: upstreamPrompt, count: 1,
            headers: ["Custom-Request-Header": "request-header-value"]
        ))
        let request = try #require(await transport.requests().first)
        var headers = normalizeHeaders(request.headers)
        // Swift's HTTP client always sends a user agent; upstream's test fetch has none.
        #expect(headers.removeValue(forKey: "user-agent") != nil)
        #expect(headers == [
            "content-type": "application/json",
            "custom-provider-header": "provider-header-value",
            "custom-request-header": "request-header-value"
        ])
    }

    @Test func handlesAPIErrors() async throws {
        let transport = RecordingTransport(response: AIHTTPResponse(
            statusCode: 400,
            headers: ["content-type": "application/json"],
            body: Data(#"{"error":{"message":"Bad Request"}}"#.utf8)
        ))
        do {
            _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(prompt: upstreamPrompt, count: 1))
            Issue.record("Expected an API call error.")
        } catch let AIError.apiCall(error) {
            #expect(error.message == "Bad Request")
            #expect(error.statusCode == 400)
            #expect(error.responseBody == #"{"error":{"message":"Bad Request"}}"#)
        }
    }

    // describe('warnings')
    @Test func returnsAspectRatioWarningWhenAspectRatioIsProvided() async throws {
        let transport = RecordingTransport(response: jsonResponse(upstreamImageResponse))
        let result = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(
            prompt: upstreamPrompt, size: "1024x1024", aspectRatio: "1:1", seed: 123, count: 1
        ))
        #expect(result.warnings == [
            AIWarning(type: "unsupported", feature: "aspectRatio", message: "This model does not support the `aspectRatio` option. Use `size` instead.")
        ])
    }

    @Test func respectsTheAbortSignal() async throws {
        let transport = AbortAwareTransport()
        let controller = AIAbortController()
        controller.abort()
        await #expect(throws: AIAbortError.self) {
            _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(
                prompt: upstreamPrompt, count: 1, abortSignal: controller.signal
            ))
        }
        #expect(await transport.requests.first?.abortSignal === controller.signal)
    }

    // describe('response metadata')
    @Test func includesTimestampHeadersAndModelIDInResponse() async throws {
        // Swift has no `_internal.currentDate` hook; the call time is bounded instead.
        let before = Date()
        let transport = RecordingTransport(response: jsonResponse(
            #"{"id":"test-id","created":1,"data":[{"index":0,"b64_json":"test-base64-content"}],"model":"response-model","object":"list"}"#
        ))
        let result = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(prompt: upstreamPrompt, count: 1))
        let timestamp = try #require(result.responseMetadata.timestamp)
        #expect(timestamp >= before && timestamp <= Date())
        #expect(result.responseMetadata.modelID == "stabilityai/stable-diffusion-xl")
        #expect(result.responseMetadata.headers["content-type"] == "application/json")
    }

    @Test func includesResponseHeadersFromAPICall() async throws {
        let transport = RecordingTransport(response: jsonResponse(upstreamImageResponse, headers: [
            "x-request-id": "test-request-id",
            "content-length": "128"
        ]))
        let result = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(prompt: upstreamPrompt, count: 1))
        #expect(result.responseMetadata.headers == [
            "x-request-id": "test-request-id",
            "content-type": "application/json",
            "content-length": "128"
        ])
        #expect(result.base64Images == ["test-base64-content"])
    }

    // describe('constructor')
    @Test func exposesCorrectProviderAndModelInformation() {
        let model = upstreamImageModel(transport: RecordingTransport(response: jsonResponse(upstreamImageResponse)))
        #expect(model.providerID == "togetherai.image")
        #expect(model.modelID == "stabilityai/stable-diffusion-xl")
    }

    // describe('Image Editing')
    @Test(arguments: ["black-forest-labs/FLUX.2-pro", "black-forest-labs/FLUX.2-flex"])
    func sendsStandardizedFileInputsAsImageURL(_ modelID: String) async throws {
        let transport = RecordingTransport(response: jsonResponse(upstreamEditingResponse))
        _ = try await upstreamImageModel(modelID, transport: transport).generateImage(ImageGenerationRequest(
            prompt: "Make the shirt yellow", count: 1,
            files: [ImageInputFile(url: "https://example.com/input.jpg")]
        ))
        #expect(try await firstBody(transport) == [
            "model": .string(modelID),
            "prompt": "Make the shirt yellow",
            "image_url": "https://example.com/input.jpg",
            "response_format": "base64"
        ])
    }

    @Test func sendsImageURLWhenURLFileIsProvided() async throws {
        let transport = RecordingTransport(response: jsonResponse(upstreamEditingResponse))
        _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(
            prompt: "Make the shirt yellow", count: 1,
            files: [ImageInputFile(url: "https://example.com/input.jpg")]
        ))
        #expect(try await firstBody(transport) == [
            "image_url": "https://example.com/input.jpg",
            "model": "stabilityai/stable-diffusion-xl",
            "prompt": "Make the shirt yellow",
            "response_format": "base64"
        ])
    }

    @Test func convertsBinaryFileToDataURI() async throws {
        let transport = RecordingTransport(response: jsonResponse(upstreamEditingResponse))
        _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(
            prompt: "Transform this image", count: 1,
            files: [ImageInputFile(data: Data([137, 80, 78, 71, 13, 10, 26, 10]), mediaType: "image/png")]
        ))
        let body = try await firstBody(transport)
        #expect(body["image_url"]?.stringValue?.hasPrefix("data:image/png;base64,") == true)
        #expect(body["prompt"]?.stringValue == "Transform this image")
    }

    @Test func convertsFileWithBase64DataToDataURI() async throws {
        // Swift files carry bytes, so the upstream base64 string is decoded first.
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        let transport = RecordingTransport(response: jsonResponse(upstreamEditingResponse))
        _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(
            prompt: "Edit this", count: 1,
            files: [ImageInputFile(data: try #require(Data(base64Encoded: base64)), mediaType: "image/png")]
        ))
        #expect(try await firstBody(transport)["image_url"]?.stringValue == "data:image/png;base64,\(base64)")
    }

    @Test func throwsErrorWhenMaskIsProvided() async throws {
        let transport = RecordingTransport(response: jsonResponse(upstreamEditingResponse))
        await #expect(throws: AIError.invalidResponse(
            provider: "togetherai.image",
            message: "Together AI does not support mask-based image editing. Use FLUX Kontext models (e.g., black-forest-labs/FLUX.1-kontext-pro) with a reference image and descriptive prompt instead."
        )) {
            _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(
                prompt: "Inpaint this area", count: 1,
                files: [ImageInputFile(url: "https://example.com/input.jpg")],
                mask: ImageInputFile(url: "https://example.com/mask.png")
            ))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func warnsWhenMultipleFilesAreProvided() async throws {
        let transport = RecordingTransport(response: jsonResponse(upstreamEditingResponse))
        let result = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(
            prompt: "Edit multiple images", count: 1,
            files: [
                ImageInputFile(url: "https://example.com/input1.jpg"),
                ImageInputFile(url: "https://example.com/input2.jpg")
            ]
        ))
        #expect(result.warnings == [
            AIWarning(type: "other", message: "Together AI only supports a single input image. Additional images are ignored.")
        ])
        #expect(try await firstBody(transport)["image_url"]?.stringValue == "https://example.com/input1.jpg")
    }

    @Test func passesProviderOptionsWithImageEditing() async throws {
        let transport = RecordingTransport(response: jsonResponse(upstreamEditingResponse))
        _ = try await upstreamImageModel(transport: transport).generateImage(ImageGenerationRequest(
            prompt: "Transform the style", count: 1,
            files: [ImageInputFile(url: "https://example.com/input.jpg")],
            providerOptions: ["togetherai": ["steps": 28, "guidance": 3.5]]
        ))
        #expect(try await firstBody(transport) == [
            "guidance": 3.5,
            "image_url": "https://example.com/input.jpg",
            "model": "stabilityai/stable-diffusion-xl",
            "prompt": "Transform the style",
            "response_format": "base64",
            "steps": 28
        ])
    }
}

// MARK: - togetherai-provider.test.ts

@discardableResult
private func withTogetherAIEnvironment<T>(_ updates: [String: String?], operation: () async throws -> T) async rethrows -> T {
    var previous: [String: String] = [:]
    for key in updates.keys {
        if let value = getenv(key) { previous[key] = String(cString: value) }
    }
    for (key, value) in updates {
        if let value { setenv(key, value, 1) } else { unsetenv(key) }
    }
    defer {
        for key in updates.keys {
            if let value = previous[key] { setenv(key, value, 1) } else { unsetenv(key) }
        }
    }
    return try await operation()
}

private func sentAuthorization(_ settings: TogetherAIProviderSettings, transport: RecordingTransport) async throws -> String? {
    let model = try TogetherAIProvider(configuration: settings).languageModel("model-id")
    _ = try await model.generate(LanguageModelRequest(messages: [.user("Hi")]))
    return try #require(await transport.requests().first).headers["authorization"]
}

private let upstreamChatResponse = #"{"choices":[{"message":{"content":"ok"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":2}}"#

@Suite("TogetherAI provider upstream parity", .serialized)
struct TogetherAIProviderUpstreamTests {
    @Test func createsProviderWithDefaultOptions() async throws {
        await withTogetherAIEnvironment(["TOGETHER_API_KEY": nil, "TOGETHER_AI_API_KEY": nil]) {
            #expect(throws: AIError.missingAPIKey(provider: "togetherai", environmentVariables: ["TOGETHER_API_KEY", "TOGETHER_AI_API_KEY"])) {
                _ = try TogetherAIProvider(configuration: TogetherAIProviderSettings(transport: RecordingTransport(response: jsonResponse(upstreamChatResponse))))
            }
        }
        try await withTogetherAIEnvironment(["TOGETHER_API_KEY": "env-key", "TOGETHER_AI_API_KEY": nil]) {
            let transport = RecordingTransport(response: jsonResponse(upstreamChatResponse))
            let authorization = try await sentAuthorization(TogetherAIProviderSettings(transport: transport), transport: transport)
            #expect(authorization == "Bearer env-key")
            let request = try #require(await transport.requests().first)
            #expect(request.url.absoluteString == "https://api.together.xyz/v1/chat/completions")
        }
    }

    @Test func createsProviderWithCustomOptions() async throws {
        let transport = RecordingTransport(response: jsonResponse(upstreamChatResponse))
        let authorization = try await sentAuthorization(TogetherAIProviderSettings(
            apiKey: "custom-key", baseURL: "https://custom.url", headers: ["Custom-Header": "value"], transport: transport
        ), transport: transport)
        #expect(authorization == "Bearer custom-key")
        let request = try #require(await transport.requests().first)
        #expect(request.url.absoluteString == "https://custom.url/chat/completions")
        #expect(normalizeHeaders(request.headers)["custom-header"] == "value")
    }

    // The upstream console deprecation warning has no Swift logging equivalent.
    @Test func fallsBackToDeprecatedTogetherAIAPIKey() async throws {
        try await withTogetherAIEnvironment(["TOGETHER_API_KEY": nil, "TOGETHER_AI_API_KEY": "old-key"]) {
            let transport = RecordingTransport(response: jsonResponse(upstreamChatResponse))
            let authorization = try await sentAuthorization(TogetherAIProviderSettings(transport: transport), transport: transport)
            #expect(authorization == "Bearer old-key")
        }
    }

    @Test func prefersTogetherAPIKeyOverDeprecatedKey() async throws {
        try await withTogetherAIEnvironment(["TOGETHER_API_KEY": "new-key", "TOGETHER_AI_API_KEY": "old-key"]) {
            let transport = RecordingTransport(response: jsonResponse(upstreamChatResponse))
            let authorization = try await sentAuthorization(TogetherAIProviderSettings(transport: transport), transport: transport)
            #expect(authorization == "Bearer new-key")
        }
    }

    @Test func prefersExplicitAPIKeyOverDeprecatedKey() async throws {
        try await withTogetherAIEnvironment(["TOGETHER_API_KEY": nil, "TOGETHER_AI_API_KEY": "old-key"]) {
            let transport = RecordingTransport(response: jsonResponse(upstreamChatResponse))
            let authorization = try await sentAuthorization(TogetherAIProviderSettings(apiKey: "explicit-key", transport: transport), transport: transport)
            #expect(authorization == "Bearer explicit-key")
        }
    }

    @Test func constructsModelsOfTheExpectedTypes() throws {
        let provider = try TogetherAIProvider(configuration: TogetherAIProviderSettings(apiKey: "test-key", transport: RecordingTransport(response: jsonResponse("{}"))))
        // provider(modelId) is languageModel(_:) in Swift.
        let functionModel = try provider.languageModel("foo-model-id")
        #expect(functionModel is OpenAICompatibleChatModel)
        #expect(functionModel.providerID == "togetherai.chat")
        let chat = try provider.chatModel("together-chat-model")
        #expect(chat is OpenAICompatibleChatModel)
        #expect(chat.providerID == "togetherai.chat")
        let completion = try provider.completionModel("together-completion-model")
        #expect(completion is OpenAICompatibleCompletionModel)
        #expect(completion.providerID == "togetherai.completion")
        let embedding = try provider.embeddingModel("together-embedding-model")
        #expect(embedding is OpenAICompatibleEmbeddingModel)
        #expect(embedding.providerID == "togetherai.embedding")
        let image = try provider.imageModel("stabilityai/stable-diffusion-xl")
        #expect(image is TogetherAIImageModel)
        #expect(image.providerID == "togetherai.image")
        let reranking = try provider.rerankingModel("Salesforce/Llama-Rank-v1")
        #expect(reranking is TogetherAIRerankingModel)
        #expect(reranking.providerID == "togetherai.reranking")
    }

    @Test func imageAndRerankingModelsUseDefaultBaseURL() async throws {
        let imageTransport = RecordingTransport(response: jsonResponse(upstreamImageResponse))
        let imageProvider = try TogetherAIProvider(configuration: TogetherAIProviderSettings(apiKey: "test-key", transport: imageTransport))
        _ = try await imageProvider.imageModel("stabilityai/stable-diffusion-xl").generateImage(ImageGenerationRequest(prompt: "cat"))
        #expect(try #require(await imageTransport.requests().first).url.absoluteString == "https://api.together.xyz/v1/images/generations")

        let rerankTransport = RecordingTransport(response: jsonResponse(upstreamRerankingFixture))
        let rerankProvider = try TogetherAIProvider(configuration: TogetherAIProviderSettings(apiKey: "test-key", transport: rerankTransport))
        _ = try await rerankProvider.rerankingModel("Salesforce/Llama-Rank-v1").rerank(RerankingRequest(query: "q", documents: ["a"]))
        #expect(try #require(await rerankTransport.requests().first).url.absoluteString == "https://api.together.xyz/v1/rerank")
    }

    @Test func passesCustomBaseURLToImageModel() async throws {
        let transport = RecordingTransport(response: jsonResponse(upstreamImageResponse))
        let provider = try TogetherAIProvider(configuration: TogetherAIProviderSettings(apiKey: "test-key", baseURL: "https://custom.url/", transport: transport))
        _ = try await provider.imageModel("stabilityai/stable-diffusion-xl").generateImage(ImageGenerationRequest(prompt: "cat"))
        #expect(try #require(await transport.requests().first).url.absoluteString == "https://custom.url/images/generations")
    }
}

// MARK: - reranking/togetherai-reranking-model.test.ts

// Verbatim copy of src/reranking/__fixtures__/togetherai-reranking.1.json.
private let upstreamRerankingFixture: String = {
    let url = Bundle.module.url(forResource: "togetherai-reranking.1", withExtension: "json", subdirectory: "Fixtures")
        ?? Bundle.module.url(forResource: "togetherai-reranking.1", withExtension: "json")
    return try! String(contentsOf: url!, encoding: .utf8)
}()

@Suite("TogetherAI reranking model upstream parity")
struct TogetherAIRerankingModelUpstreamTests {
    private func rerank(_ documents: RerankingRequest) async throws -> (RerankingResult, AIHTTPRequest) {
        let transport = RecordingTransport(response: jsonResponse(upstreamRerankingFixture, headers: ["content-length": "304"]))
        let provider = try TogetherAIProvider(configuration: TogetherAIProviderSettings(apiKey: "test-api-key", transport: transport))
        let result = try await provider.rerankingModel("Salesforce/Llama-Rank-v1").rerank(documents)
        return (result, try #require(await transport.requests().first))
    }

    private func expectUpstreamResult(_ result: RerankingResult) throws {
        #expect(result.warnings.isEmpty)
        #expect(result.results == [
            RerankedDocument(index: 0, score: 0.6475887154399037),
            RerankedDocument(index: 5, score: 0.6323295373206566)
        ])
        #expect(result.providerMetadata.isEmpty)
        #expect(result.responseMetadata.id == "oGs6Zt9-62bZhn-99529372487b1b0a")
        #expect(result.responseMetadata.modelID == "Salesforce/Llama-Rank-v1")
        #expect(result.responseMetadata.headers == ["content-length": "304", "content-type": "application/json"])
        #expect(result.responseMetadata.body == (try decodeJSONBody(Data(upstreamRerankingFixture.utf8))))
    }

    private func expectUpstreamHeaders(_ request: AIHTTPRequest) {
        var headers = normalizeHeaders(request.headers)
        // Swift appends the package user agent; upstream's snapshot runs without it.
        #expect(headers.removeValue(forKey: "user-agent") == "ai-sdk-togetherai/3.0.94")
        #expect(headers == ["authorization": "Bearer test-api-key", "content-type": "application/json"])
    }

    // describe('json documents')
    @Test func jsonDocuments() async throws {
        let (result, request) = try await rerank(RerankingRequest(
            query: "rainy day",
            documents: [["example": "sunny day at the beach"], ["example": "rainy day in the city"]],
            topK: 2,
            providerOptions: ["togetherai": ["rankFields": ["example"]]]
        ))
        #expect(try decodeJSONBody(try #require(request.body)) == [
            "documents": [["example": "sunny day at the beach"], ["example": "rainy day in the city"]],
            "model": "Salesforce/Llama-Rank-v1",
            "query": "rainy day",
            "rank_fields": ["example"],
            "return_documents": false,
            "top_n": 2
        ])
        expectUpstreamHeaders(request)
        try expectUpstreamResult(result)
    }

    // describe('text documents')
    @Test func textDocuments() async throws {
        let (result, request) = try await rerank(RerankingRequest(
            query: "rainy day",
            documents: ["sunny day at the beach", "rainy day in the city"],
            topK: 2,
            providerOptions: ["togetherai": ["rankFields": ["example"]]]
        ))
        #expect(try decodeJSONBody(try #require(request.body)) == [
            "documents": ["sunny day at the beach", "rainy day in the city"],
            "model": "Salesforce/Llama-Rank-v1",
            "query": "rainy day",
            "rank_fields": ["example"],
            "return_documents": false,
            "top_n": 2
        ])
        expectUpstreamHeaders(request)
        try expectUpstreamResult(result)
    }
}
