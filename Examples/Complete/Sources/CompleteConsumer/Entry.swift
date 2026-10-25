import Foundation
import SwiftAISDK

actor FixtureTransport: AITransport {
    private var calls = 0
    func send(_ request: AIHTTPRequest) async throws -> AIHTTPResponse {
        precondition(request.url.host == "fixtures.invalid")
        calls += 1
        let value: JSONValue = ["id": "response_fixture", "status": "completed", "output": [
            ["type": "message", "role": "assistant", "content": [
                ["type": "output_text", "text": "complete", "annotations": []]
            ]]
        ], "usage": ["input_tokens": 1, "output_tokens": 1, "total_tokens": 2]]
        return AIHTTPResponse(statusCode: 200, headers: ["content-type": "application/json"],
            body: try JSONEncoder().encode(value), url: request.url)
    }
    func count() -> Int { calls }
}

@main struct CompleteConsumer {
    static func main() async throws {
        let _: SwiftAISDK.TextGenerationResult.Type = TextGenerationResult.self
        let _: SwiftAISDK.GoogleGenerativeAIProvider.Type = GoogleGenerativeAIProvider.self
        let _: SwiftAISDK.VideoGenerationOperationStartResult.Type = VideoGenerationOperationStartResult.self
        let _: SwiftAISDK.MCPClient.Type = MCPClient.self
        let _: SwiftAISDK.AIChatSession.Type = AIChatSession.self
        let transport = FixtureTransport()
        let provider = try AIProviders.openAI(settings: .init(apiKey: "offline-fixture",
            baseURL: "https://fixtures.invalid/v1", environment: [:], transport: transport))
        let result = try await AI.generateText(model: provider.languageModel("fixture"),
            request: .init(messages: [.user("Hello")]), retryPolicy: .none)
        precondition(result.text == "complete")
        let scoped = try await AIDefaultProvider.withProvider(provider) { @Sendable in
            try await AI.generateText(model: "fixture", prompt: "Hello", retryPolicy: .none)
        }
        precondition(scoped.text == "complete")
        let calls = await transport.count()
        precondition(calls == 2)
        precondition(!AIProviderCapabilities.all.isEmpty)
        print("COMPLETE_CONSUMER_OK")
    }
}
