@testable import SwiftAIReplicate
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translated from packages/replicate/src/replicate-video-model.test.ts (doStart/doStatus)
// and the n default from replicate-image-model.test.ts at the pinned release.

private func replicatePrediction(id: String = "test-prediction-id", status: String = "succeeded",
                                 output: String? = "https://replicate.delivery/video.mp4", error: String? = nil,
                                 metrics: JSONValue = ["predict_time": 25.5]) -> AIHTTPResponse {
    let body: JSONValue = [
        "id": .string(id), "status": .string(status), "output": output.map(JSONValue.string) ?? .null,
        "error": error.map(JSONValue.string) ?? .null,
        "urls": ["get": .string("https://api.replicate.com/v1/predictions/\(id)")], "metrics": metrics
    ]
    return AIHTTPResponse(statusCode: 200, headers: ["content-type": "application/json"], body: try! encodeJSONBody(body))
}

private func replicateVideo(_ modelID: String = "minimax/video-01", responses: [AIHTTPResponse]) throws -> (any AsyncVideoModel, RecordingTransport) {
    let transport = RecordingTransport(responses: responses)
    let provider = try AIProviders.replicate(configuration: ReplicateProviderSettings(apiKey: "test-api-token", transport: transport))
    return (try #require(try provider.videoModel(modelID) as? any AsyncVideoModel), transport)
}

private func status(_ model: any AsyncVideoModel, _ id: String = "status-pred-123") async throws -> VideoGenerationOperationStatusResult {
    try await model.videoGenerationStatus(VideoGenerationOperationStatusRequest(
        operation: ["getUrl": .string("https://api.replicate.com/v1/predictions/\(id)")]
    ))
}

@Suite("Replicate video operations (upstream doStart/doStatus)")
struct ReplicateVideoOperationUpstreamTests {
    @Test("should return operation with getUrl")
    func returnsOperationWithGetURL() async throws {
        let (model, _) = try replicateVideo(responses: [replicatePrediction(id: "start-pred-123")])
        let result = try await model.startVideoGeneration(.init(request: VideoGenerationRequest(prompt: "A rocket launching into space")))
        #expect(result.operation == ["getUrl": "https://api.replicate.com/v1/predictions/start-pred-123"])
        #expect(result.warnings.isEmpty)
        #expect(result.responseMetadata.modelID == "minimax/video-01")
    }

    @Test("should pass correct request body and NOT send prefer header")
    func passesBodyWithoutPreferHeader() async throws {
        let (model, transport) = try replicateVideo(responses: [replicatePrediction()])
        _ = try await model.startVideoGeneration(.init(request: VideoGenerationRequest(prompt: "A rocket launching into space")))
        let request = try #require(await transport.requests().first)
        #expect(request.url.absoluteString == "https://api.replicate.com/v1/models/minimax/video-01/predictions")
        #expect(request.headers["prefer"] == nil)
        let body = try decodeJSONBody(try #require(request.body))
        #expect(body["input"]?["prompt"] == "A rocket launching into space")
        #expect(body["webhook"] == nil)
        #expect(body["webhook_events_filter"] == nil)
    }

    @Test("should use correct URL for versioned models")
    func versionedModelURL() async throws {
        let (model, transport) = try replicateVideo("stability-ai/stable-video-diffusion:abc123", responses: [replicatePrediction()])
        _ = try await model.startVideoGeneration(.init(request: VideoGenerationRequest(prompt: "A rocket launching into space")))
        let request = try #require(await transport.requests().first)
        #expect(request.url.absoluteString == "https://api.replicate.com/v1/predictions")
        #expect(try decodeJSONBody(try #require(request.body))["version"] == "abc123")
    }

    @Test("should pass webhookUrl as webhook body parameter")
    func passesWebhook() async throws {
        let (model, transport) = try replicateVideo(responses: [replicatePrediction()])
        #expect(model.supportsVideoGenerationWebhooks)
        _ = try await model.startVideoGeneration(.init(
            request: VideoGenerationRequest(prompt: "A rocket launching into space"),
            webhookURL: "https://example.com/webhook"
        ))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["webhook"] == "https://example.com/webhook")
        #expect(body["webhook_events_filter"] == ["completed"])
    }

    @Test("should return completed with video data and providerMetadata when succeeded")
    func completedStatus() async throws {
        let (model, transport) = try replicateVideo(responses: [
            replicatePrediction(id: "meta-pred-456", output: "https://replicate.delivery/video.mp4", metrics: ["predict_time": 30.2])
        ])
        guard case let .completed(result) = try await status(model, "meta-pred-456") else {
            Issue.record("Expected completed status")
            return
        }
        #expect(result.urls == ["https://replicate.delivery/video.mp4"])
        #expect(result.mediaType == "video/mp4")
        #expect(result.providerMetadata == ["replicate": [
            "videos": [["url": "https://replicate.delivery/video.mp4"]],
            "predictionId": "meta-pred-456",
            "metrics": ["predict_time": 30.2]
        ]])
        #expect(await transport.requests().first?.headers["authorization"] == "Bearer test-api-token")
    }

    @Test(arguments: ["processing", "starting"])
    func pendingStatus(predictionStatus: String) async throws {
        let (model, _) = try replicateVideo(responses: [replicatePrediction(status: predictionStatus, output: nil)])
        guard case let .pending(_, _, responseMetadata) = try await status(model) else {
            Issue.record("Expected pending status")
            return
        }
        #expect(responseMetadata.modelID == "minimax/video-01")
    }

    @Test("should return error status on failed prediction")
    func failedStatus() async throws {
        let (model, _) = try replicateVideo(responses: [replicatePrediction(status: "failed", output: nil, error: "GPU out of memory")])
        guard case let .failed(message, _, _) = try await status(model) else {
            Issue.record("Expected failed status")
            return
        }
        #expect(message.contains("GPU out of memory"))
    }

    @Test("should return error status on canceled prediction")
    func canceledStatus() async throws {
        let (model, _) = try replicateVideo(responses: [replicatePrediction(status: "canceled", output: nil)])
        guard case let .failed(message, _, _) = try await status(model) else {
            Issue.record("Expected failed status")
            return
        }
        #expect(message.contains("canceled"))
    }

    @Test("should throw when no output on succeeded")
    func throwsWithoutOutput() async throws {
        let (model, _) = try replicateVideo(responses: [replicatePrediction(output: nil)])
        await #expect(throws: AIError.invalidResponse(provider: "replicate.video", message: "No video URL in response")) {
            _ = try await status(model)
        }
    }

    @Test("image requests always send num_outputs (n defaults to 1)")
    func imageAlwaysSendsNumOutputs() async throws {
        let transport = RecordingTransport(responses: [
            jsonResponse(#"{"id":"p","status":"succeeded","output":["https://replicate.delivery/image.png"],"urls":{"get":"https://api.replicate.com/v1/predictions/p"}}"#),
            AIHTTPResponse(statusCode: 200, headers: ["content-type": "image/png"], body: Data("png".utf8))
        ])
        let provider = try AIProviders.replicate(configuration: ReplicateProviderSettings(apiKey: "test-api-token", transport: transport))
        _ = try await provider.imageModel("black-forest-labs/flux-schnell").generateImage(ImageGenerationRequest(prompt: "The Loch Ness monster getting a manicure"))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["input"] == ["prompt": "The Loch Ness monster getting a manicure", "num_outputs": 1])
    }
}
