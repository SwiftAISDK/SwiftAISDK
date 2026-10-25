@testable import SwiftAIKlingAI
@testable import SwiftAIFal
@testable import SwiftAILuma
@testable import SwiftAIRevAI
@testable import SwiftAIAlibaba
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

@Suite("WeeklyMediaPaths20261023")
struct WeeklyMediaPaths20261023Tests {
    @Test(arguments: ["a/b?x#y", ".", ".."])
    func pollingIDsStaySinglePathSegments(id: String) async throws {
        let encoded = id == "." ? "%252E" : id == ".." ? "%252E%252E" : "a%2Fb%3Fx%23y"
        let rev = RecordingTransport(responses: [
            jsonResponse("{\"id\":\"\(id)\",\"status\":\"in_progress\"}"),
            jsonResponse("{\"id\":\"\(id)\",\"status\":\"transcribed\"}"), jsonResponse(#"{"monologues":[]}"#)
        ])
        _ = try await AIProviders.revAI(settings: .init(apiKey: "key", transport: rev)).transcriptionModel("machine").transcribe(.init(audio: Data([1]), mimeType: "audio/wav"))
        let revURLs = await rev.requests().map { $0.url.absoluteString }
        #expect(revURLs[1] == "https://api.rev.ai/speechtotext/v1/jobs/\(encoded)")
        #expect(revURLs[2] == "https://api.rev.ai/speechtotext/v1/jobs/\(encoded)/transcript")

        let fal = RecordingTransport(responses: [jsonResponse("{\"request_id\":\"\(id)\"}"), jsonResponse(#"{"text":"ok","chunks":[]}"#)])
        _ = try await AIProviders.fal(settings: .init(apiKey: "key", transport: fal)).transcriptionModel("whisper").transcribe(.init(audio: Data([1]), mimeType: "audio/wav"))
        #expect(await fal.requests().last?.url.absoluteString == "https://queue.fal.run/fal-ai/whisper/requests/\(encoded)")

        let luma = RecordingTransport(responses: [jsonResponse("{\"id\":\"\(id)\",\"state\":\"queued\"}"), jsonResponse(#"{"state":"completed","assets":{"image":"https://example.com/image.png"}}"#), AIHTTPResponse(statusCode: 200, headers: ["content-type": "image/png"], body: Data([1]))])
        _ = try await AIProviders.luma(settings: .init(apiKey: "key", transport: luma)).imageModel("photon-1").generateImage(.init(prompt: "image", providerOptions: ["luma": ["pollIntervalMillis": 1]]))
        #expect(await luma.requests()[1].url.absoluteString == "https://api.lumalabs.ai/dream-machine/v1/generations/\(encoded)")

        let alibaba = RecordingTransport(responses: [jsonResponse("{\"output\":{\"task_id\":\"\(id)\"}}"), jsonResponse(#"{"output":{"task_status":"SUCCEEDED","video_url":"https://example.com/video.mp4"}}"#)])
        _ = try await AIProviders.alibaba(settings: .init(apiKey: "key", transport: alibaba)).videoModel("wan2.6-t2v").generateVideo(.init(prompt: "video"))
        #expect(await alibaba.requests()[1].url.absoluteString.hasSuffix("/api/v1/tasks/\(encoded)") == true)

        let kling = RecordingTransport(response: jsonResponse(#"{"code":0,"data":{"task_status":"processing"}}"#))
        let klingModel = try #require(try AIProviders.klingAI(settings: .init(apiKey: "key", transport: kling)).videoModel("kling-v2-t2v") as? any AsyncVideoModel)
        _ = try await klingModel.videoGenerationStatus(.init(operation: ["taskId": .string(id), "endpointPath": "/v1/videos/text2video"]))
        #expect(await kling.requests().first?.url.absoluteString.hasSuffix("/v1/videos/text2video/\(encoded)") == true)
    }
}
