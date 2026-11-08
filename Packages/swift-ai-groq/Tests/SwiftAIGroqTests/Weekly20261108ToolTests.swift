import Foundation
import Testing
@testable import SwiftAIGroq
import SwiftAIProvider

@Suite("Weekly20261108 Groq tool replay")
struct Weekly20261108ToolTests {
    @Test(arguments: [#"{"city":"Tokyo"}"#, "null", "42", "raw arguments\n\"quoted\"", ""])
    func toolArgumentsPreserveJSONAndQuoteMalformedText(_ input: String) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"ok"},"finish_reason":"stop"}]}"#))
        let provider = try GroqProvider(configuration: .init(apiKey: "key", transport: transport))
        _ = try await provider.languageModel("llama-3.3-70b-versatile").generate(.init(messages: [
            .init(role: .assistant, content: [.toolCall(.init(id: "call", name: "lookup", arguments: input))])
        ]))
        let sent = try #require(await transport.requests().first)
        let body = try JSONDecoder().decode(JSONValue.self, from: #require(sent.body))
        let arguments = try #require(body["messages"]?[0]?["tool_calls"]?[0]?["function"]?["arguments"]?.stringValue)
        if let parsed = try? JSONDecoder().decode(JSONValue.self, from: Data(input.utf8)) {
            #expect(arguments == input)
            #expect(try JSONDecoder().decode(JSONValue.self, from: Data(arguments.utf8)) == parsed)
        } else {
            #expect(try JSONDecoder().decode(JSONValue.self, from: Data(arguments.utf8)) == .string(input))
        }
    }
}
