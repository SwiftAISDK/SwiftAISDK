import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIAzure

private actor WeeklyAzureKeys {
    var count = 0
    func next() -> String { count += 1; return "key-\(count)" }
}

@Suite struct Weekly20261101AzureTests {
    @Test(arguments: ["azure", "openai"])
    func toolSearchAndDeferredFunctionOptions(_ namespace: String) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"id":"r","status":"completed","output_text":"done"}"#))
        let provider = try AzureOpenAIProvider(resourceName: "weekly", configuration: .init(apiKey: "key", transport: transport))
        _ = try await provider.responses("deployment").generate(.init(messages: [.user("Hi")], tools: [
            "search": AzureOpenAITools.toolSearch(),
            "weather": ["type": "object", "properties": [:], "providerOptions": .object([namespace: ["deferLoading": true]])]
        ]))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["tools"]?.arrayValue?.first { $0["type"] == "function" }?["defer_loading"] == true)
        #expect(body["tools"]?.arrayValue?.contains { $0["type"] == "tool_search" } == true)
    }

    @Test func speech502KeepsOriginalStatusAndIsRetryable() async throws {
        let transport = RecordingTransport(response: .init(statusCode: 502, body: Data("upstream reset reason: protocol error".utf8)))
        let model = try AzureOpenAIProvider(resourceName: "weekly", configuration: .init(apiKey: "key", transport: transport)).speechModel("mai-voice-2")
        do { _ = try await model.speak(.init(text: "Hi")); Issue.record("Expected service error") }
        catch let AIError.apiCall(error) { #expect(error.statusCode == 502); #expect(error.isRetryable) }
    }

    @Test func rotatingAPIKeyReachesOpenAIAndSpeech() async throws {
        let keys = WeeklyAzureKeys()
        let transport = RecordingTransport(responses: [jsonResponse(#"{"id":"r","status":"completed","output_text":"done"}"#), .init(statusCode: 200, body: Data([1]))])
        let provider = try AzureOpenAIProvider(resourceName: "weekly", configuration: .init(transport: transport, apiKeyProvider: { await keys.next() }))
        _ = try await provider.responses("deployment").generate(.init(messages: [.user("Hi")]))
        _ = try await provider.speechModel("mai-voice-2").speak(.init(text: "Hi"))
        let requests = await transport.requests()
        #expect(requests[0].headers.first { $0.key.lowercased() == "api-key" }?.value == "key-1")
        #expect(requests[1].headers.first { $0.key.lowercased() == "ocp-apim-subscription-key" }?.value == "key-2")
    }
}
