import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Testing
import SwiftAI
@testable import SwiftAIAnthropicAWS

// Translations of @ai-sdk/anthropic-aws 2.0.98 provider tests covering the
// behavior aligned in the parity audit.

private let anthropicAWSParityResponse = #"{"content":[{"type":"text","text":"ok"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}"#

// Upstream `apiKey ? createApiKeyFetchFunction : createSigV4FetchFunction`:
// an empty key is falsy, so the request is signed with SigV4 instead.
@Test func anthropicAWSEmptyAPIKeyFallsBackToSigV4LikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(anthropicAWSParityResponse))
    let provider = try AIProviders.anthropicAWS(configuration: AnthropicAWSProviderSettings(
        region: "us-west-2",
        workspaceID: "wrkspc_test",
        apiKey: "",
        accessKeyID: "AKIDEXAMPLE",
        secretAccessKey: "secret",
        transport: transport
    ))

    _ = try await provider.languageModel("claude-sonnet-4-6").generate(LanguageModelRequest(messages: [.user("Hello")]))

    let request = try #require(await transport.requests().first)
    #expect(request.headers["x-api-key"] == nil)
    #expect(request.headers["authorization"]?.contains("/us-west-2/aws-external-anthropic/aws4_request") == true)
}

// "wraps credentialProvider rejections with a guided message"
@Test func anthropicAWSWrapsCredentialProviderRejections() async throws {
    struct STSDenied: Error, CustomStringConvertible {
        var description: String { "STS denied" }
    }
    let transport = RecordingTransport(response: jsonResponse(anthropicAWSParityResponse))
    let provider = try AIProviders.anthropicAWS(configuration: AnthropicAWSProviderSettings(
        region: "us-west-2",
        workspaceID: "wrkspc_test",
        credentialProvider: { throw STSDenied() },
        transport: transport
    ))

    do {
        _ = try await provider.languageModel("claude-sonnet-4-6").generate(LanguageModelRequest(messages: [.user("Hello")]))
        Issue.record("expected the credential provider failure")
    } catch {
        #expect(String(describing: error).contains("AWS credential provider failed: STS denied"))
    }
    #expect(await transport.requests().isEmpty)
}
