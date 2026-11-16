@testable import SwiftAIMiniMax
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Warning and request-body cases from packages/minimax/src/minimax-video-model.test.ts
// that were not yet asserted by MiniMaxProviderTests.

private func run(
    _ request: VideoGenerationRequest,
    model modelID: String = "MiniMax-H3",
    createResponse: String = #"{"task_id":"task_1"}"#
) async throws -> (VideoGenerationResult, JSONValue) {
    let transport = RecordingTransport(responses: [
        jsonResponse(createResponse),
        jsonResponse(#"{"task":{"status":"succeeded","content":{"url":"https://cdn.example.com/video.mp4"}}}"#)
    ])
    var request = request
    var minimax = request.providerOptions["minimax"]?.objectValue ?? [:]
    minimax["pollIntervalMs"] = 1
    request.providerOptions["minimax"] = .object(minimax)
    let result = try await AIProviders.miniMax(configuration: MiniMaxProviderSettings(apiKey: "key", transport: transport))
        .video(modelID)
        .generateVideo(request)
    let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
    return (result, body)
}

private func warning(_ feature: String, _ message: String) -> AIWarning {
    AIWarning(type: "unsupported", feature: feature, message: message)
}

private let png = ImageInputFile(data: Data([1, 2, 3]), mediaType: "image/png")

@Suite("MiniMax video warnings (upstream)")
struct MiniMaxVideoWarningParityTests {
    @Test func warnsForUnsupportedSharedSettingsWithExactDetails() async throws {
        let (result, body) = try await run(VideoGenerationRequest(prompt: "Clouds", fps: 24, generateAudio: true, seed: 7, count: 2))
        #expect(result.warnings == [
            warning("fps", "MiniMax-H3 does not support a custom frame rate."),
            warning("seed", "MiniMax-H3 does not support a seed."),
            warning("n", "MiniMax-H3 generates a single video per call. Only 1 video will be generated."),
            warning("generateAudio", "The MiniMax-H3 API does not expose an audio parameter. The generateAudio option was ignored.")
        ])
        #expect(body == [
            "model": "MiniMax-H3",
            "content": [["type": "text", "text": "Clouds"]],
            "resolution": "2K",
            "duration": 5,
            "ratio": "16:9"
        ])
    }

    @Test func ignoresAVideoFirstFrameFromTheImageArgument() async throws {
        let (result, body) = try await run(VideoGenerationRequest(prompt: "x", image: ImageInputFile(url: "https://example.com/a.mp4", mediaType: "video/mp4")))
        #expect(result.warnings == [warning("image", "MiniMax-H3 does not accept a video as a frame image. The video was ignored.")])
        #expect(body["content"]?.arrayValue?.count == 1)
    }

    @Test func ignoresANonImageFirstFrameFromFrameImages() async throws {
        let audio = ImageInputFile(url: "https://example.com/a.mp3", mediaType: "audio/mpeg")
        let (result, _) = try await run(VideoGenerationRequest(prompt: "x", frameImages: [VideoFrameImage(image: audio, frameType: .firstFrame)]))
        #expect(result.warnings == [warning("frameImages", "MiniMax-H3 only accepts an image as a frame image; the \"audio/mpeg\" file was ignored.")])
    }

    @Test func requiresAFirstFrameWhenALastFrameIsProvided() async throws {
        let (result, body) = try await run(VideoGenerationRequest(prompt: "x", frameImages: [VideoFrameImage(image: png, frameType: .lastFrame)]))
        #expect(result.warnings == [warning("frameImages", "MiniMax-H3 requires a first_frame when a last_frame is provided. The last_frame was ignored.")])
        #expect(body["content"]?.arrayValue?.count == 1)
        #expect(body["ratio"] == "16:9")
    }

    @Test func ignoresAVideoLastFrame() async throws {
        let video = ImageInputFile(url: "https://example.com/last.mp4", mediaType: "video/mp4")
        let (result, body) = try await run(VideoGenerationRequest(prompt: "x", frameImages: [
            VideoFrameImage(image: png, frameType: .firstFrame),
            VideoFrameImage(image: video, frameType: .lastFrame)
        ]))
        #expect(result.warnings == [warning("frameImages", "MiniMax-H3 does not accept a video as a frame image. The last_frame video was ignored.")])
        #expect(body["content"]?[1]?["role"] == "first_frame")
        #expect(body["content"]?.arrayValue?.count == 2)
        #expect(body["ratio"] == nil)
    }

    @Test func h3MaxIgnoresReferenceInputsAndReferenceAudio() async throws {
        let (result, body) = try await run(VideoGenerationRequest(
            prompt: "x",
            inputReferences: [png],
            providerOptions: ["minimax": ["referenceAudioUrls": ["https://example.com/a.mp3"]]]
        ), model: "MiniMax-H3-Max")
        #expect(result.warnings == [
            warning("inputReferences", "MiniMax-H3-Max does not support reference-to-video inputs. The references were ignored."),
            warning("referenceAudioUrls", "MiniMax-H3-Max does not support reference audio. The audio was ignored.")
        ])
        #expect(body["content"]?.arrayValue?.count == 1)
        #expect(body["resolution"] == "768P")
    }

    @Test func treatsAReferenceWithoutMediaTypeAsAnImage() async throws {
        let (result, body) = try await run(VideoGenerationRequest(prompt: "x", inputReferences: [ImageInputFile(url: "https://example.com/ref")]))
        #expect(result.warnings == [warning("inputReferences", "MiniMax-H3 requires an explicit mediaType to route URL references as video or image. Pass { data: url, mediaType: \"video/mp4\" } for video references. The reference was treated as an image.")])
        #expect(body["content"]?[1] == ["type": "image_url", "image_url": ["url": "https://example.com/ref"], "role": "reference_image"])
        #expect(body["ratio"] == nil)
    }

    @Test func ignoresReferenceAudioWithoutAnImageOrVideoReference() async throws {
        let (result, body) = try await run(VideoGenerationRequest(
            prompt: "x",
            providerOptions: ["minimax": ["referenceAudioUrls": ["https://example.com/a.mp3"]]]
        ))
        #expect(result.warnings == [warning("referenceAudioUrls", "MiniMax-H3 reference audio must be paired with at least one reference image or video. The audio was ignored.")])
        #expect(body["content"]?.arrayValue?.count == 1)
        #expect(body["ratio"] == "16:9")
    }

    @Test func usesTheProviderDefaultRatioForUnsupportedRatiosWithReferences() async throws {
        let (result, body) = try await run(VideoGenerationRequest(prompt: "x", aspectRatio: "5:4", inputReferences: [png]))
        #expect(result.warnings == [warning("aspectRatio", "MiniMax-H3 does not support the aspect ratio \"5:4\". Using the provider default (adaptive).")])
        #expect(body["ratio"] == nil)
    }

    @Test func dropsTheRequestedRatioWhenFrameImagesAreUsed() async throws {
        let (result, body) = try await run(VideoGenerationRequest(prompt: "x", aspectRatio: "9:16", image: png))
        #expect(result.warnings == [warning("aspectRatio", "MiniMax-H3 derives the aspect ratio from the frame image; the requested ratio was ignored.")])
        #expect(body["ratio"] == nil)
        #expect(body["content"]?[1]?["role"] == "first_frame")
    }

    @Test(arguments: [("MiniMax-H3", 4.0), ("MiniMax-H3-Max", 5.0)])
    func clampsShortDurationsToTheModelMinimum(modelID: String, minimum: Double) async throws {
        let (result, body) = try await run(VideoGenerationRequest(prompt: "x", durationSeconds: 2), model: modelID)
        #expect(result.warnings == [warning("duration", "\(modelID) requires at least \(Int(minimum)) seconds. The requested duration of 2 was clamped to \(Int(minimum)).")])
        #expect(body["duration"] == .number(minimum))
    }

    @Test func warnsWhenTheTopLevelResolutionSelectsADifferentProviderResolution() async throws {
        let (result, body) = try await run(VideoGenerationRequest(prompt: "x", resolution: "1366x768", providerOptions: ["minimax": ["resolution": "2K"]]))
        #expect(result.warnings == [warning("resolution", "The resolution \"1366x768\" selects 768P, but providerOptions.minimax.resolution (\"2K\") was used instead.")])
        #expect(body["resolution"] == "2K")
    }

    @Test func warnsWhenTheMappedResolutionIsUnsupportedByTheModel() async throws {
        let (result, body) = try await run(VideoGenerationRequest(prompt: "x", resolution: "2560x1440"), model: "MiniMax-H3-Max")
        #expect(result.warnings == [warning("resolution", "MiniMax-H3-Max does not support the resolution \"2K\". It supports \"480P\" or \"768P\".")])
        #expect(body["resolution"] == "768P")
    }

    @Test func reportsAMissingTaskID() async throws {
        await #expect(throws: AIError.invalidResponse(provider: "minimax.video", message: #"No task_id returned from the MiniMax API. Response: {"base_resp":{"status_code":0}}"#)) {
            _ = try await run(VideoGenerationRequest(prompt: "x"), createResponse: #"{"base_resp":{"status_code":0}}"#)
        }
    }
}
