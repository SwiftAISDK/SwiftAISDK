@testable import SwiftAIFal
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translated from packages/fal/src/fal-image-model.test.ts, fal-video-model.test.ts,
// fal-transcription-model.test.ts and fal-error.test.ts at the pinned release.

private let falImageBinary = AIHTTPResponse(statusCode: 200, headers: ["content-type": "image/png"], body: Data("test-binary-content".utf8))

private func falImageModel(_ responses: [AIHTTPResponse]) throws -> (any ImageModel, RecordingTransport) {
    let transport = RecordingTransport(responses: responses)
    let provider = try AIProviders.fal(configuration: FalProviderSettings(apiKey: "test-key", baseURL: "https://api.example.com", transport: transport))
    return (try provider.imageModel("fal-ai/qwen-image"), transport)
}

private func falVideoModel(_ responses: [AIHTTPResponse]) throws -> (any AsyncVideoModel, RecordingTransport) {
    let transport = RecordingTransport(responses: responses)
    let provider = try AIProviders.fal(configuration: FalProviderSettings(apiKey: "test-key", transport: transport))
    return (try #require(try provider.videoModel("luma-dream-machine") as? any AsyncVideoModel), transport)
}

@Suite("fal upstream parity")
struct FalUpstreamParityTests {
    @Test("should convert aspect ratio to size (num_images defaults to n = 1)")
    func convertsAspectRatioAndAlwaysSendsNumImages() async throws {
        let (model, transport) = try falImageModel([
            jsonResponse(#"{"images":[{"url":"https://api.example.com/image.png","width":1024,"height":1024,"content_type":"image/png"}]}"#),
            falImageBinary
        ])
        _ = try await model.generateImage(ImageGenerationRequest(prompt: "A cute baby sea otter", aspectRatio: "16:9"))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body == ["prompt": "A cute baby sea otter", "image_size": "landscape_16_9", "num_images": 1])
    }

    @Test("should handle API errors")
    func formatsValidationErrors() async throws {
        let (model, _) = try falImageModel([
            AIHTTPResponse(statusCode: 400, headers: ["content-type": "application/json"],
                           body: Data(#"{"detail":[{"loc":["prompt"],"msg":"Invalid prompt","type":"value_error"}]}"#.utf8))
        ])
        do {
            _ = try await model.generateImage(ImageGenerationRequest(prompt: "A cute baby sea otter"))
            Issue.record("Expected an API error")
        } catch let error as AIError {
            let apiError = try #require(error.apiCallError)
            #expect(apiError.message == "prompt: Invalid prompt")
            #expect(apiError.statusCode == 400)
            #expect(apiError.url == "https://api.example.com/fal-ai/qwen-image")
        }
    }

    @Test("providerMetaData for lora")
    func loraProviderMetadata() async throws {
        let (model, _) = try falImageModel([
            jsonResponse("""
            {"images":[{"url":"https://api.example.com/image.png","width":1024,"height":1024,"content_type":"image/png","file_data":"<image file_data>","file_size":123,"file_name":"<image file_name>"}],
             "prompt":"<prompt>","seed":123,"has_nsfw_concepts":[true],
             "debug_latents":{"url":"<debug_latents url>","content_type":"<debug_latents content_type>","file_name":"<debug_latents file_name>","file_data":"<debug_latents file_data>","file_size":123},
             "debug_per_pass_latents":{"url":"<debug_per_pass_latents url>","content_type":"<debug_per_pass_latents content_type>","file_name":"<debug_per_pass_latents file_name>","file_data":"<debug_per_pass_latents file_data>","file_size":456}}
            """),
            falImageBinary
        ])
        let result = try await model.generateImage(ImageGenerationRequest(prompt: "A cute baby sea otter", count: 1))
        #expect(result.providerMetadata == ["fal": [
            "images": [[
                "width": 1024, "height": 1024, "contentType": "image/png", "fileName": "<image file_name>",
                "fileData": "<image file_data>", "fileSize": 123, "nsfw": true
            ]],
            "seed": 123,
            "debug_latents": [
                "url": "<debug_latents url>", "content_type": "<debug_latents content_type>",
                "file_name": "<debug_latents file_name>", "file_data": "<debug_latents file_data>", "file_size": 123
            ],
            "debug_per_pass_latents": [
                "url": "<debug_per_pass_latents url>", "content_type": "<debug_per_pass_latents content_type>",
                "file_name": "<debug_per_pass_latents file_name>", "file_data": "<debug_per_pass_latents file_data>", "file_size": 456
            ]
        ]])
    }

    @Test("providerMetaData for lcm")
    func lcmProviderMetadata() async throws {
        let (model, _) = try falImageModel([
            jsonResponse(#"{"images":[{"url":"https://api.example.com/image.png","width":1024,"height":1024}],"seed":123,"num_inference_steps":456,"nsfw_content_detected":[false]}"#),
            falImageBinary
        ])
        let result = try await model.generateImage(ImageGenerationRequest(prompt: "A cute baby sea otter", count: 1))
        #expect(result.providerMetadata == ["fal": [
            "images": [["width": 1024, "height": 1024, "nsfw": false]],
            "seed": 123,
            "num_inference_steps": 456
        ]])
    }

    @Test("should handle null file_name and file_size values")
    func nullFileNameAndSize() async throws {
        let (model, _) = try falImageModel([
            jsonResponse(#"{"images":[{"url":"https://api.example.com/image.png","content_type":"image/png","file_name":null,"file_size":null,"width":944,"height":1104}],"timings":{"inference":5.875932216644287},"seed":328395684,"has_nsfw_concepts":[false],"prompt":"A female model holding this book, keeping the book unchanged."}"#),
            falImageBinary
        ])
        let result = try await model.generateImage(ImageGenerationRequest(prompt: "A cute baby sea otter", count: 1))
        #expect(result.base64Images.count == 1)
        let fal = try #require(result.providerMetadata["fal"])
        #expect(fal["images"] == [["width": 944, "height": 1104, "contentType": "image/png", "fileName": .null, "fileSize": .null, "nsfw": false]])
        #expect(fal["timings"] == ["inference": 5.875932216644287])
        #expect(fal["seed"] == 328395684)
    }

    @Test("should handle empty timings object")
    func emptyTimings() async throws {
        let (model, _) = try falImageModel([
            jsonResponse(#"{"images":[{"url":"https://api.example.com/image.png","content_type":"image/png","file_name":null,"file_size":null,"width":880,"height":1184}],"timings":{},"seed":235205040,"has_nsfw_concepts":[false],"prompt":"Change the plates to colorful ones"}"#),
            falImageBinary
        ])
        let result = try await model.generateImage(ImageGenerationRequest(prompt: "A cute baby sea otter", count: 1))
        let fal = try #require(result.providerMetadata["fal"])
        #expect(fal["images"] == [["width": 880, "height": 1184, "contentType": "image/png", "fileName": .null, "fileSize": .null, "nsfw": false]])
        #expect(fal["timings"] == .object([:]))
        #expect(fal["seed"] == 235205040)
    }

    @Test("should handle null width and height values with images array only")
    func nullWidthAndHeight() async throws {
        let (model, _) = try falImageModel([
            jsonResponse(#"{"images":[{"url":"https://api.example.com/image.png","content_type":"image/png","file_name":"output.png","file_size":663399,"width":null,"height":null}],"description":"here is an image with null width and height"}"#),
            falImageBinary
        ])
        let result = try await model.generateImage(ImageGenerationRequest(prompt: "A cute baby sea otter", count: 1))
        let fal = try #require(result.providerMetadata["fal"])
        #expect(fal["images"] == [["width": .null, "height": .null, "contentType": "image/png", "fileName": "output.png", "fileSize": 663399]])
        #expect(fal["description"] == "here is an image with null width and height")
    }

    @Test("should parse single image response")
    func singleImageResponse() async throws {
        let (model, _) = try falImageModel([
            jsonResponse(#"{"image":{"url":"https://api.example.com/image.png","width":1024,"height":1024,"content_type":"image/png"}}"#),
            falImageBinary
        ])
        let result = try await model.generateImage(ImageGenerationRequest(prompt: "A cute baby sea otter", count: 1))
        #expect(result.base64Images.count == 1)
        #expect(result.providerMetadata["fal"]?["images"] == [["width": 1024, "height": 1024, "contentType": "image/png"]])
    }

    @Test("should include provider metadata in completed status")
    func videoCompletedProviderMetadata() async throws {
        let (model, _) = try falVideoModel([
            jsonResponse(#"{"video":{"url":"https://fal.media/files/video-output.mp4","width":1920,"height":1080,"duration":5.0,"fps":24,"content_type":"video/mp4"},"seed":12345,"timings":{"inference":45.5}}"#)
        ])
        let status = try await model.videoGenerationStatus(VideoGenerationOperationStatusRequest(operation: [
            "responseUrl": "https://queue.fal.run/fal-ai/luma-dream-machine/requests/test-request-id-123",
            "submitUrl": "https://queue.fal.run/fal-ai/luma-dream-machine"
        ]))
        guard case let .completed(result) = status else {
            Issue.record("Expected completed status")
            return
        }
        #expect(result.urls == ["https://fal.media/files/video-output.mp4"])
        #expect(result.mediaType == "video/mp4")
        #expect(result.providerMetadata == ["fal": [
            "videos": [[
                "url": "https://fal.media/files/video-output.mp4", "width": 1920, "height": 1080,
                "duration": 5.0, "fps": 24, "contentType": "video/mp4"
            ]],
            "seed": 12345,
            "timings": ["inference": 45.5]
        ]])
    }

    @Test("should return error status for non-polling API errors")
    func videoErrorStatusUsesFalErrorMessage() async throws {
        let (model, _) = try falVideoModel([
            AIHTTPResponse(statusCode: 500, headers: ["content-type": "application/json"],
                           body: Data(#"{"error":{"message":"Internal server error","code":500}}"#.utf8))
        ])
        let status = try await model.videoGenerationStatus(VideoGenerationOperationStatusRequest(operation: [
            "responseUrl": "https://queue.fal.run/fal-ai/luma-dream-machine/requests/test-id",
            "submitUrl": "https://queue.fal.run/fal-ai/luma-dream-machine"
        ]))
        guard case let .failed(message, _, _) = status else {
            Issue.record("Expected failed status")
            return
        }
        #expect(message == "Internal server error")
    }

    @Test("should parse Fal resource exhausted error")
    func parsesResourceExhaustedError() {
        let body = #"{"error":{"message":"{\n  \"error\": {\n    \"code\": 429,\n    \"message\": \"Resource has been exhausted (e.g. check quota).\",\n    \"status\": \"RESOURCE_EXHAUSTED\"\n  }\n}\n","code":429}}"#
        #expect(falErrorDataMessage(Data(body.utf8)) == "{\n  \"error\": {\n    \"code\": 429,\n    \"message\": \"Resource has been exhausted (e.g. check quota).\",\n    \"status\": \"RESOURCE_EXHAUSTED\"\n  }\n}\n")
    }

    @Test("transcription keeps every chunk and reports the last chunk end")
    func transcriptionChunksMatchUpstreamMapping() async throws {
        let transport = RecordingTransport(responses: [
            jsonResponse(#"{"request_id":"test-id"}"#),
            jsonResponse(#"{"text":"Hello world!","chunks":[{"text":"Hello","timestamp":[0,1]},{"text":"","timestamp":null},{"text":" world!","timestamp":[1,2.5]}],"inferred_languages":["en"],"duration":99}"#)
        ])
        let provider = try AIProviders.fal(configuration: FalProviderSettings(apiKey: "test-key", transport: transport))
        let result = try await provider.transcriptionModel("wizper").transcribe(AudioTranscriptionRequest(audio: Data("audio".utf8), mimeType: "audio/wav"))
        #expect(result.segments == [
            TranscriptionSegment(text: "Hello", startSecond: 0, endSecond: 1),
            TranscriptionSegment(text: "", startSecond: 0, endSecond: 0),
            TranscriptionSegment(text: " world!", startSecond: 1, endSecond: 2.5)
        ])
        #expect(result.durationInSeconds == 2.5)
        #expect(result.language == "en")
    }

    @Test("speech posts to fal.run independently of baseURL, like upstream")
    func speechUsesFalRunURL() async throws {
        let transport = RecordingTransport(responses: [
            jsonResponse(#"{"audio":{"url":"https://fal.media/audio.mp3"}}"#),
            AIHTTPResponse(statusCode: 200, headers: ["content-type": "audio/mpeg"], body: Data("audio".utf8))
        ])
        let provider = try AIProviders.fal(configuration: FalProviderSettings(apiKey: "test-key", baseURL: "https://proxy.example.com", transport: transport))
        _ = try await provider.speechModel("fal-ai/minimax/speech-02-hd").speak(SpeechRequest(text: "Hello from the AI SDK!"))
        let requests = await transport.requests()
        #expect(requests.first?.url.absoluteString == "https://fal.run/fal-ai/minimax/speech-02-hd")
        #expect(requests.first?.headers["content-type"] == "application/json")
    }
}
