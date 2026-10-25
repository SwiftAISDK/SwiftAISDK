import Foundation
import SwiftAI
import SwiftAITransport
import SwiftAIOpenAICompatible

#if canImport(SwiftAISDK)
#error("Provider consumers must build without the compatibility aggregate")
#endif

actor FixtureTransport: AITransport {
    var paths: [String] = []
    func send(_ request: AIHTTPRequest) async throws -> AIHTTPResponse {
        precondition(request.url.host == "fixtures.invalid")
        paths.append(request.url.path)
        let value: JSONValue
        switch request.url.path {
        case "/v1/messages":
            value = ["content": [["type": "text", "text": "anthropic"]], "stop_reason": "end_turn", "usage": ["input_tokens": 1, "output_tokens": 1]]
        case "/v1/responses":
            value = ["id": "response_fixture", "status": "completed", "output": [["type": "message", "role": "assistant", "content": [["type": "output_text", "text": "openai", "annotations": []]]]], "usage": ["input_tokens": 1, "output_tokens": 1, "total_tokens": 2]]
        case "/v1/chat/completions":
            value = ["choices": [["message": ["role": "assistant", "content": "compatible"], "finish_reason": "stop"]]]
        default: preconditionFailure("Unexpected fixture route: \(request.url.path)")
        }
        return AIHTTPResponse(statusCode: 200, headers: ["content-type": "application/json"], body: try JSONEncoder().encode(value), url: request.url)
    }
    func count() -> Int { paths.count }
}

@main struct ProviderConsumer {
    static func main() async throws {
        let transport = FixtureTransport()
        let compatible = AIProviders.openAICompatible(configuration: .init(name: "fixture", baseURL: "https://fixtures.invalid/v1", transport: transport))
        let registry = createProviderRegistry(["compatible": compatible])
        let compatibleResult = try await AI.generateText(model: registry.languageModel("compatible:fixture-model"), request: .init(messages: [.user("test")]), retryPolicy: .none)
        precondition(compatibleResult.text == "compatible")
        let requestCount = await transport.count()
        precondition(requestCount == 1)
        print("OPENAICOMPATIBLEONLY_OK")
    }
}
