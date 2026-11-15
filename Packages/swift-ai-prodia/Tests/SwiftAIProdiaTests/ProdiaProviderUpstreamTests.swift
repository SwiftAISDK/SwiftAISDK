@testable import SwiftAIProdia
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translated from upstream `@ai-sdk/prodia` 2.0.84 `prodia-provider.test.ts`,
// plus local checks for the shared job-part schema and request URL handling.

private func upstreamProviderResponse() -> AIHTTPResponse {
    prodiaUpstreamMultipartResponse([
        prodiaUpstreamJobPart(#"{"id":"job-123","state":{"current":"completed"},"config":{"prompt":"test"}}"#),
        (name: "output", fileName: "output.png", contentType: "image/png", body: Data("test-image".utf8))
    ])
}

private func defaultProvider(transport: RecordingTransport = RecordingTransport(response: upstreamProviderResponse())) throws -> ProdiaProvider {
    try AIProviders.prodia(configuration: ProdiaProviderSettings(apiKey: "test-api-key", transport: transport))
}

@Test func prodiaProviderUpstreamCreatesImageModelsViaImageAndImageModel() throws {
    let provider = try defaultProvider()

    let imageModel = try provider.image("inference.flux-fast.schnell.txt2img.v2")
    let imageModel2 = try provider.imageModel("inference.flux.schnell.txt2img.v2")

    #expect(imageModel.providerID == "prodia.image")
    #expect(imageModel.modelID == "inference.flux-fast.schnell.txt2img.v2")
    #expect(imageModel2.modelID == "inference.flux.schnell.txt2img.v2")
}

@Test func prodiaProviderUpstreamCreatesLanguageModelsViaLanguageModel() throws {
    let model = try defaultProvider().languageModel("inference.nano-banana.img2img.v2")

    #expect(model.providerID == "prodia.language")
    #expect(model.modelID == "inference.nano-banana.img2img.v2")
}

@Test func prodiaProviderUpstreamCreatesVideoModelsViaVideoAndVideoModel() throws {
    let provider = try defaultProvider()

    let videoModel = try provider.video("inference.wan2-2.lightning.txt2vid.v0")
    let videoModel2 = try provider.videoModel("inference.wan2-2.lightning.img2vid.v0")

    #expect(videoModel.providerID == "prodia.video")
    #expect(videoModel.modelID == "inference.wan2-2.lightning.txt2vid.v0")
    #expect(videoModel2.modelID == "inference.wan2-2.lightning.img2vid.v0")
}

@Test func prodiaProviderUpstreamConfiguresBaseURLAndHeadersCorrectly() async throws {
    let transport = RecordingTransport(response: upstreamProviderResponse())
    let provider = try AIProviders.prodia(configuration: ProdiaProviderSettings(
        apiKey: "test-api-key",
        baseURL: "https://api.example.com/v2",
        headers: ["x-extra-header": "extra"],
        transport: transport
    ))

    _ = try await provider.image("inference.flux-fast.schnell.txt2img.v2").generateImage(ImageGenerationRequest(
        prompt: "A serene mountain landscape at sunset"
    ))

    let request = try #require(await transport.requests().first)
    #expect(request.url.absoluteString == "https://api.example.com/v2/job?price=true")
    #expect(request.method == "POST")
    #expect(prodiaHeader(request, "authorization") == "Bearer test-api-key")
    #expect(prodiaHeader(request, "x-extra-header") == "extra")
    #expect(prodiaHeader(request, "accept") == "multipart/form-data; image/png")
    let body = try decodeJSONBody(try #require(request.body))
    #expect(body["type"]?.stringValue == "inference.flux-fast.schnell.txt2img.v2")
    #expect(body["config"]?["prompt"]?.stringValue == "A serene mountain landscape at sunset")
    #expect(prodiaHeader(request, "user-agent")?.contains("ai-sdk-prodia/") == true)
}

@Test func prodiaProviderUpstreamThrowsNoSuchModelErrorForUnsupportedModelTypes() throws {
    #expect(throws: AIError.unsupportedModel(provider: "prodia", capability: .embedding, modelID: "some-id")) {
        _ = try defaultProvider().embeddingModel("some-id")
    }
}

// Local: upstream `prodiaJobResultSchema` (`prodia-api.ts`) is enforced on the
// multipart `job` part by every model.

@Test func prodiaModelsValidateJobPartLikeUpstreamSchema() async throws {
    func response(job: String, output: (contentType: String, fileName: String)) -> AIHTTPResponse {
        prodiaUpstreamMultipartResponse([
            prodiaUpstreamJobPart(job),
            (name: "output", fileName: output.fileName, contentType: output.contentType, body: Data("bytes".utf8))
        ])
    }
    func provider(_ response: AIHTTPResponse) throws -> ProdiaProvider {
        try AIProviders.prodia(configuration: ProdiaProviderSettings(apiKey: "test-api-key", transport: RecordingTransport(response: response)))
    }
    let invalidJobs = [
        #"{"state":{"current":"completed"}}"#,
        #"{"id":42}"#,
        #"{"id":"job","created_at":null}"#,
        #"{"id":"job","state":{}}"#,
        #"{"id":"job","config":{"seed":"7"}}"#,
        #"{"id":"job","metrics":{"ips":"fast"}}"#,
        #"{"id":"job","price":{"product":"flux"}}"#,
        #"[]"#
    ]
    for job in invalidJobs {
        await #expect(throws: AITypeValidationError.self, "image \(job)") {
            _ = try await provider(response(job: job, output: ("image/png", "output.png")))
                .imageModel("sdxl").generateImage(ImageGenerationRequest(prompt: "cat"))
        }
        await #expect(throws: AITypeValidationError.self, "video \(job)") {
            _ = try await provider(response(job: job, output: ("video/mp4", "output.mp4")))
                .videoModel("veo").generateVideo(VideoGenerationRequest(prompt: "cat"))
        }
        await #expect(throws: AITypeValidationError.self, "language \(job)") {
            _ = try await provider(response(job: job, output: ("text/plain", "message.txt")))
                .languageModel("inference.nano-banana.img2img.v2").generate(LanguageModelRequest(messages: [.user("cat")]))
        }
    }

    await #expect(throws: AIJSONParseError.self) {
        _ = try await provider(response(job: "{not json", output: ("image/png", "output.png")))
            .imageModel("sdxl").generateImage(ImageGenerationRequest(prompt: "cat"))
    }

    // Unknown keys stay allowed, and `price` is nullish.
    let result = try await provider(response(
        job: #"{"id":"job-ok","extra":true,"config":{"prompt":"cat","custom":1},"price":null}"#,
        output: ("image/png", "output.png")
    )).imageModel("sdxl").generateImage(ImageGenerationRequest(prompt: "cat"))
    #expect(result.providerMetadata["prodia"] == .object(["images": .array([.object(["jobId": "job-ok"])])]))

    // Missing job part keeps the upstream message for every model.
    let noJob = prodiaUpstreamMultipartResponse([
        (name: "output", fileName: "message.txt", contentType: "text/plain", body: Data("text".utf8))
    ])
    await #expect(throws: AIError.invalidResponse(provider: "prodia.language", message: "Prodia multipart response missing job part")) {
        _ = try await provider(noJob).languageModel("inference.nano-banana.img2img.v2").generate(LanguageModelRequest(messages: [.user("cat")]))
    }
    await #expect(throws: AIError.invalidResponse(provider: "prodia.video", message: "Prodia multipart response missing job part")) {
        _ = try await provider(noJob).videoModel("veo").generateVideo(VideoGenerationRequest(prompt: "cat"))
    }
}

// Local: every Prodia request uses the same `${baseURL}/job?price=true` URL
// builder, so provider-settings query parameters apply to multipart requests.

@Test func prodiaMultipartRequestsApplyProviderQueryParameters() async throws {
    let videoTransport = RecordingTransport(response: prodiaUpstreamMultipartResponse([
        prodiaUpstreamJobPart(#"{"id":"job-video"}"#),
        (name: "output", fileName: "output.mp4", contentType: "video/mp4", body: Data("mp4".utf8))
    ]))
    _ = try await AIProviders.prodia(configuration: ProdiaProviderSettings(
        apiKey: "test-api-key",
        baseURL: "https://api.example.com/v2",
        queryParams: ["tenant": "acme"],
        transport: videoTransport
    )).videoModel("inference.wan2-2.lightning.img2vid.v0").generateVideo(VideoGenerationRequest(
        prompt: "cat",
        image: ImageInputFile(data: Data([1, 2, 3, 4]), mediaType: "image/png")
    ))
    let videoRequest = try #require(await videoTransport.requests().first)
    #expect(videoRequest.url.absoluteString == "https://api.example.com/v2/job?price=true&tenant=acme")
    #expect(prodiaHeader(videoRequest, "content-type")?.hasPrefix("multipart/form-data; boundary=") == true)
    #expect(prodiaHeader(videoRequest, "user-agent") == "ai-sdk-prodia/2.0.84")

    let languageTransport = RecordingTransport(response: prodiaUpstreamMultipartResponse([
        prodiaUpstreamJobPart(#"{"id":"job-language"}"#),
        (name: "output", fileName: "message.txt", contentType: "text/plain", body: Data("ok".utf8))
    ]))
    _ = try await AIProviders.prodia(configuration: ProdiaProviderSettings(
        apiKey: "test-api-key",
        baseURL: "https://api.example.com/v2",
        queryParams: ["tenant": "acme"],
        transport: languageTransport
    )).languageModel("inference.nano-banana.img2img.v2").generate(LanguageModelRequest(messages: [.user("cat")]))
    let languageRequest = try #require(await languageTransport.requests().first)
    #expect(languageRequest.url.absoluteString == "https://api.example.com/v2/job?price=true&tenant=acme")
}
