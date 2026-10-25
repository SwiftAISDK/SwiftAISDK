@testable import SwiftAIAnthropic
@testable import SwiftAIOpenAICompatible
@testable import SwiftAIOpenAI
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
private typealias AI = SwiftAISDK.AI
private typealias AIProviders = SwiftAISDK.AIProviders
private typealias AICustomProvider = SwiftAISDK.AICustomProvider
import Foundation
import Testing
@testable import SwiftAISDK

let heyGenOperation: JSONValue = ["videoId": "video-1", "mode": "text_to_video", "resolution": "768p"]
let heyGenCreated = #"{"data":{"status":"pending","video_id":"video-1"}}"#
let heyGenCompleted = #"{"data":{"status":"completed","video_url":"https://resource2.heygen.ai/video.mp4","duration":5,"width":1344,"height":768,"aspect_ratio":"16:9","seed":0}}"#
let heyGenImage = ImageInputFile(url: "https://example.com/image.jpg", mediaType: "image/jpeg")
let heyGenVideo = ImageInputFile(url: "https://example.com/video.mp4", mediaType: "video/mp4")
let heyGenAudio = ImageInputFile(url: "https://example.com/audio.mp3", mediaType: "audio/mpeg")

func heyGenTestProvider(_ transport: any AITransport, baseURL: String? = nil, headers: [String: String] = [:]) throws -> SwiftAISDK.OpenAICompatibleProvider {
    try AIProviders.heyGen(settings: ProviderSettings(apiKey: "test-key", baseURL: baseURL, headers: headers, transport: transport))
}

func heyGenTestModel(_ transport: any AITransport) throws -> HeyGenVideoModel {
    try #require(try heyGenTestProvider(transport).videoModel("heygen-video-1") as? HeyGenVideoModel)
}

func heyGenTestStart(_ transport: any AITransport, request: VideoGenerationRequest = VideoGenerationRequest(prompt: "A paper boat floats down a quiet stream.")) async throws -> VideoGenerationOperationStartResult {
    try await heyGenTestModel(transport).startVideoGeneration(VideoGenerationOperationStartRequest(request: request))
}

func heyGenTestRequestBody(_ transport: RecordingTransport, index: Int = 0) async throws -> JSONValue {
    let calls = await transport.requests()
    return try decodeJSONBody(try #require(calls[index].body))
}
