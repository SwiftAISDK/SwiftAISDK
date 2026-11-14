import SwiftAISDK

@main
struct GenerateTextExample {
    static func main() async throws {
        let provider = try AIProviders.openAI()
        let model = try provider.languageModel("gpt-6.1-sol")

        let result = try await model.generateText("Write one sentence about Swift concurrency.")

        print(result.text)
    }
}
