import Foundation
import Testing
@testable import SwiftAIBlackForestLabs
import SwiftAIProvider
import SwiftAITransport

@Suite("Weekly20261108 BFL webhook fallback")
struct Weekly20261108WebhookTests {
    @Test func invalidPollingURLIsNotTreatedAsMissing() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"id":"job","polling_url":42}"#))
        let provider = try BlackForestLabsProvider(configuration: .init(apiKey: "key", transport: transport))
        await #expect(throws: AIError.invalidResponse(provider: "black-forest-labs.image", message: "Black Forest Labs polling_url must be a string or null.")) {
            try await provider.imageModel("flux-2-pro").generateImage(.init(prompt: "cat"))
        }
        #expect(await transport.requests().count == 1)
    }

    @Test(arguments: [200, 404])
    func taskRegistrationDelayRetriesOnlyFallback(_ statusCode: Int) async throws {
        let transport = RecordingTransport(responses: [
            jsonResponse(#"{"id":"webhook job","webhook_url":"https://app.example.com/webhook"}"#),
            AIHTTPResponse(statusCode: statusCode, body: Data(#"{"status":"Task not found"}"#.utf8)),
            jsonResponse(#"{"status":"Ready","result":{"sample":"https://api.example.com/image.png"}}"#),
            AIHTTPResponse(statusCode: 200, body: Data("image".utf8))
        ])
        let provider = try BlackForestLabsProvider(configuration: .init(apiKey: "key", baseURL: "https://api.example.com/v1", transport: transport))
        let result = try await provider.imageModel("flux-2-pro").generateImage(.init(prompt: "cat", providerOptions: ["blackForestLabs": ["pollIntervalMillis": 1, "pollTimeoutMillis": 1000]]))
        #expect(result.base64Images == [Data("image".utf8).base64EncodedString()])
        let requests = await transport.requests()
        #expect(requests.count == 4)
        #expect(requests[1].url.absoluteString == "https://api.example.com/v1/get_result?id=webhook%20job")
        #expect(requests[1].headers["x-key"] == "key")
    }
    @Test(arguments: [200, 404])
    func explicitPollingURLDoesNotRetryTaskNotFound(_ statusCode: Int) async throws {
        let transport = RecordingTransport(responses: [jsonResponse(#"{"id":"job","polling_url":"https://api.example.com/poll"}"#), AIHTTPResponse(statusCode: statusCode, body: Data(#"{"status":"Task not found"}"#.utf8))])
        let provider = try BlackForestLabsProvider(configuration: .init(apiKey: "key", baseURL: "https://api.example.com/v1", transport: transport))
        await #expect(throws: AIError.self) { try await provider.imageModel("flux-2-pro").generateImage(.init(prompt: "cat")) }
        #expect(await transport.requests().count == 2)
    }
    @Test(arguments: [200, 404])
    func permanentlyUnknownWebhookIsBoundedAtTwentyAttempts(_ statusCode: Int) async throws {
        let notFound = AIHTTPResponse(statusCode: statusCode, body: Data(#"{"state":"Task not found"}"#.utf8))
        let transport = RecordingTransport(responses: [jsonResponse(#"{"id":"job"}"#)] + Array(repeating: notFound, count: 20))
        let provider = try BlackForestLabsProvider(configuration: .init(apiKey: "key", baseURL: "https://api.example.com/v1", transport: transport))
        do { _ = try await provider.imageModel("flux-2-pro").generateImage(.init(prompt: "cat", providerOptions: ["blackForestLabs": ["pollIntervalMillis": 1, "pollTimeoutMillis": 5000]])); Issue.record("Expected bounded missing task") }
        catch { #expect(String(describing: error).contains("not found via get_result")) }
        #expect(await transport.requests().count == 21)
    }

    @Test func unrelatedNotFoundDoesNotEnterRegistrationRetryLoop() async throws {
        let transport = RecordingTransport(responses: [
            jsonResponse(#"{"id":"job"}"#),
            AIHTTPResponse(statusCode: 404, body: Data(#"{"detail":"Model not found"}"#.utf8))
        ])
        let provider = try BlackForestLabsProvider(configuration: .init(apiKey: "key", baseURL: "https://api.example.com/v1", transport: transport))
        do { _ = try await provider.imageModel("flux-2-pro").generateImage(.init(prompt: "cat")); Issue.record("Expected HTTP error") }
        catch AIError.apiCall(let error) { #expect(error.statusCode == 404) }
        #expect(await transport.requests().count == 2)
    }
}
