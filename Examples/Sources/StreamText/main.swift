import SwiftAISDK

@main
struct StreamTextExample {
    static func main() async throws {
        let provider = try AIProviders.openAI()
        let model = try provider.languageModel("gpt-6.1-sol")

        for try await part in model.streamText("Write a short haiku about APIs.") {
            switch part {
            case let .textDeltaPart(_, delta, _):
                print(delta, terminator: "")
            case let .finishMetadata(reason, usage, _):
                print("\nFinished: \(reason ?? "unknown")")
                print("Tokens: \(usage?.totalTokens ?? 0)")
            default:
                break
            }
        }
    }
}
