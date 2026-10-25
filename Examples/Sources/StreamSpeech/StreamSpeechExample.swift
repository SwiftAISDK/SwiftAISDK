import Foundation
import SwiftAISDK

@main
struct StreamSpeechExample {
    static func main() async throws {
        let provider = try AIProviders.elevenLabs()
        let model = try provider.speechModel("eleven_flash_v2_5")
        let result = try AI.experimentalStreamSpeech(
            model: model,
            request: .init(
                text: .chunks(["Welcome to SwiftAISDK. ", "Audio arrives as text is synthesized."]),
                voice: ProcessInfo.processInfo.environment["ELEVENLABS_VOICE"] ?? "JBFqnCBsd6RMkjVDRZzb"
            )
        )

        let output = URL(fileURLWithPath: "speech.mp3")
        try Data().write(to: output)
        let file = try FileHandle(forWritingTo: output)
        defer { try? file.close() }
        for try await chunk in try result.audioStream {
            try file.write(contentsOf: chunk)
        }
        let usage = try await result.usage
        print("Wrote \(output.lastPathComponent); usage: \(usage)")
    }
}
