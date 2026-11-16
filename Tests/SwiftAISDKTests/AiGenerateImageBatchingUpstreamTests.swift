@testable import SwiftAI
@testable import SwiftAIProvider
private typealias AI = SwiftAISDK.AI
import Foundation
import Testing
@testable import SwiftAISDK

// Translated from upstream `packages/ai/src/generate-image/generate-image.test.ts`
// ("when several calls are required", usage aggregation, provider metadata
// merging and no-image error handling). Upstream starts the calls with
// `Promise.all`; Swift runs them concurrently too, so assertions that depend
// on which call ran first compare call-ordered results instead.

private let pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
private let jpegBase64 = "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD3+iiigD//2Q=="
private let gifBase64 = "R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="

private final class BatchingImageModel: ImageModel, @unchecked Sendable {
    let providerID = "mock-provider"
    let modelID = "mock-model-id"
    let maxImagesPerCall: Int
    private let lock = NSLock()
    private var storedRequests: [ImageGenerationRequest] = []
    private let handler: @Sendable (ImageGenerationRequest, Int) -> ImageGenerationResult

    init(maxImagesPerCall: Int, handler: @escaping @Sendable (ImageGenerationRequest, Int) -> ImageGenerationResult) {
        self.maxImagesPerCall = maxImagesPerCall
        self.handler = handler
    }

    var requests: [ImageGenerationRequest] { lock.withLock { storedRequests } }

    func generateImage(_ request: ImageGenerationRequest) async throws -> ImageGenerationResult {
        let index = lock.withLock { () -> Int in
            storedRequests.append(request)
            return storedRequests.count - 1
        }
        return handler(request, index)
    }
}

private func batchResult(
    _ images: [String],
    warnings: [AIWarning] = [],
    usage: TokenUsage? = nil,
    providerMetadata: [String: JSONValue] = [:],
    isRetryable: Bool? = nil
) -> ImageGenerationResult {
    ImageGenerationResult(
        urls: [],
        base64Images: images,
        rawValue: .object([:]),
        warnings: warnings,
        usage: usage,
        providerMetadata: providerMetadata,
        isRetryable: isRetryable
    )
}

@Suite("generateImage upstream call splitting")
struct AiGenerateImageBatchingUpstreamTests {
    @Test func generatesImagesAcrossSeveralCallsInCallOrder() async throws {
        let model = BatchingImageModel(maxImagesPerCall: 2) { request, _ in
            request.count == 2 ? batchResult([pngBase64, jpegBase64]) : batchResult([gifBase64])
        }
        let result = try await AI.generateImage(
            model: model,
            prompt: "sunny day at the beach",
            size: "1024x1024",
            aspectRatio: "16:9",
            seed: 12345,
            count: 3,
            providerOptions: ["mock-provider": ["style": "vivid"]],
            headers: ["custom-request-header": "request-header-value"]
        )

        #expect(result.base64Images == [pngBase64, jpegBase64, gifBase64])
        #expect(model.requests.compactMap(\.count).sorted() == [1, 2])
        for request in model.requests {
            #expect(request.prompt == "sunny day at the beach")
            #expect(request.size == "1024x1024")
            #expect(request.aspectRatio == "16:9")
            #expect(request.seed == 12345)
            #expect(request.providerOptions == ["mock-provider": ["style": "vivid"]])
            #expect(request.headers["custom-request-header"] == "request-header-value")
        }
        #expect(result.calls.count == 2)
    }

    @Test func aggregatesWarningsInCallOrder() async throws {
        let model = BatchingImageModel(maxImagesPerCall: 2) { request, _ in
            request.count == 2
                ? batchResult([pngBase64, jpegBase64], warnings: [AIWarning(type: "other", message: "1")])
                : batchResult([gifBase64], warnings: [AIWarning(type: "other", message: "2")])
        }
        let result = try await AI.generateImage(model: model, prompt: "prompt", count: 3)

        #expect(result.warnings.map(\.message) == ["1", "2"])
    }

    @Test func aggregatesUsageAcrossCalls() async throws {
        let model = BatchingImageModel(maxImagesPerCall: 1) { _, _ in
            batchResult([pngBase64], usage: TokenUsage(inputTokens: 10, outputTokens: 0, totalTokens: 10))
        }
        let result = try await AI.generateImage(model: model, prompt: "prompt", count: 2)

        #expect(result.usage?.inputTokens == 20)
        #expect(result.usage?.outputTokens == 0)
        #expect(result.usage?.totalTokens == 20)
    }

    @Test func mergesProviderMetadataImagesFromSeveralCalls() async throws {
        let model = BatchingImageModel(maxImagesPerCall: 1) { _, index in
            batchResult(
                [index == 0 ? pngBase64 : jpegBase64],
                providerMetadata: ["testProvider": ["images": [["revisedPrompt": .string("prompt-\(index + 1)")]]]]
            )
        }
        let result = try await AI.generateImage(model: model, prompt: "prompt", count: 2)

        let images = try #require(result.providerMetadata["testProvider"]?.objectValue?["images"]?.arrayValue)
        #expect(Set(images.compactMap { $0.objectValue?["revisedPrompt"]?.stringValue }) == ["prompt-1", "prompt-2"])
        #expect(images.count == 2)
    }

    @Test func callLevelMaxImagesPerCallOverridesTheModel() async throws {
        let model = BatchingImageModel(maxImagesPerCall: 10) { _, _ in batchResult([pngBase64]) }
        let result = try await AI.generateImage(model: model, prompt: "prompt", count: 2, maxImagesPerCall: 1)

        #expect(result.base64Images.count == 2)
        #expect(model.requests.compactMap(\.count) == [1, 1])
    }

    @Test func countWithinTheLimitIsOneCall() async throws {
        let model = BatchingImageModel(maxImagesPerCall: 4) { _, _ in batchResult([pngBase64, jpegBase64, gifBase64]) }
        let result = try await AI.generateImage(model: model, prompt: "prompt", count: 3)

        #expect(result.base64Images.count == 3)
        #expect(model.requests.compactMap(\.count) == [3])
    }

    @Test func middlewareCanOverrideMaxImagesPerCall() async throws {
        let model = BatchingImageModel(maxImagesPerCall: 10) { _, _ in batchResult([pngBase64]) }
        var middleware = AIImageModelMiddleware()
        middleware.overrideMaxImagesPerCall = { _ in 1 }
        let wrapped = wrapImageModel(model, middleware: middleware)

        #expect(wrapped.maxImagesPerCall == 1)
        let result = try await AI.generateImage(model: wrapped, prompt: "prompt", count: 3)
        #expect(result.base64Images.count == 3)
        #expect(model.requests.compactMap(\.count) == [1, 1, 1])
    }

    @Test func terminalEmptyCallContributesNoImages() async throws {
        let model = BatchingImageModel(maxImagesPerCall: 1) { _, index in
            index == 0 ? batchResult([], isRetryable: false) : batchResult([pngBase64])
        }
        let result = try await AI.generateImage(model: model, prompt: "prompt", count: 2, retryPolicy: .none)

        #expect(result.base64Images == [pngBase64])
        #expect(result.calls.count == 2)
    }

    @Test func throwsNoImageGeneratedErrorWhenEveryCallIsEmpty() async throws {
        let model = BatchingImageModel(maxImagesPerCall: 1) { _, _ in batchResult([], isRetryable: false) }
        do {
            _ = try await AI.generateImage(model: model, prompt: "prompt", count: 2, retryPolicy: .none)
            Issue.record("Expected AINoOutputError")
        } catch let error as AINoOutputError {
            #expect(error.kind == .image)
            #expect(error.calls.count == 2)
            #expect(error.responses.count == 2)
        }
    }

    @Test func retriesAnEmptyCallUntilItReturnsImages() async throws {
        let model = BatchingImageModel(maxImagesPerCall: 1) { _, index in
            index == 0 ? batchResult([]) : batchResult([pngBase64])
        }
        let policy = AIRetryPolicy(maxRetries: 2, initialDelayNanoseconds: 0)
        let result = try await AI.generateImage(model: model, prompt: "prompt", count: 2, retryPolicy: policy)

        #expect(result.base64Images == [pngBase64, pngBase64])
        #expect(model.requests.count == 3)
        #expect(result.calls.count == 3)
    }
}
