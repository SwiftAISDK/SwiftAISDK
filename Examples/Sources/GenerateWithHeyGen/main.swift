import Foundation
import SwiftAISDK

@main
struct GenerateWithHeyGenExample {
    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first,
              ["text", "image", "reference", "start", "resume"].contains(command),
              arguments.count == (["image", "reference", "start"].contains(command) ? 3 : 2) else {
            print("""
            Set HEYGEN_API_KEY, then run one of:
              GenerateWithHeyGen text <prompt>
              GenerateWithHeyGen image <prompt> <https-image-url>
              GenerateWithHeyGen reference <prompt> <https-video-url>
              GenerateWithHeyGen start <prompt> <operation-json-file>
              GenerateWithHeyGen resume <operation-json-file>
            These commands call HeyGen. No arguments prints this help without API calls.
            """)
            return
        }
        let heyGen = try AIProviders.heyGen()
        let model = try heyGen.video("heygen-video-1")
        if command == "resume" {
            let saved = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
            let operation = try JSONDecoder().decode(JSONValue.self, from: saved)
            switch try await AI.getVideoStatus(model: model, operation: operation) {
            case .pending: print("Still processing; check this operation again later.")
            case let .failed(message, metadata, _): print(message, metadata)
            case let .completed(result): printResult(result)
            }
            return
        }
        var request = VideoGenerationRequest(
            prompt: arguments[1], durationSeconds: 5,
            providerOptions: HeyGenVideoModelOptions(
                resolution: .p768, promptEnhancement: .turbo
            ).providerOptions
        )
        if command == "image" {
            request.frameImages = [VideoFrameImage(
                image: ImageInputFile(url: arguments[2], mediaType: "image/png"),
                frameType: .firstFrame
            )]
        } else if command == "reference" {
            request.inputReferences = [ImageInputFile(url: arguments[2], mediaType: "video/mp4")]
        }
        if command == "start" {
            let started = try await AI.startVideo(model: model, request: request)
            try JSONEncoder().encode(started.operation).write(to: URL(fileURLWithPath: arguments[2]))
            print("Saved operation:", started.operation)
        } else {
            let result = try await AI.generateVideo(
                model: model, request: request,
                poll: VideoGenerationPollOptions(intervalMilliseconds: 5_000, timeoutMilliseconds: 600_000)
            )
            printResult(result)
        }
    }

    static func printResult(_ result: VideoGenerationResult) {
        print(result.urls.first ?? "No video URL returned")
        print(result.providerMetadata)
    }
}
