@testable import SwiftAIGoogleVertex
@testable import SwiftAIGoogle
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

/// Behavior-parity translations of @ai-sdk/google-vertex 5.0.141 matching-release
/// tests (google-vertex-provider-base, google-vertex-language-model) and of the
/// shared Gemini language-model behavior as observed through Vertex.
@Suite struct UpstreamParityVertexTests {
    private func provider(_ transport: RecordingTransport, baseURL: String? = nil) throws -> GoogleVertexProvider {
        try AIProviders.googleVertex(configuration: GoogleVertexProviderSettings(
            project: "test-project", location: "test-location", accessToken: "token", baseURL: baseURL, transport: transport
        ))
    }

    private let textResponse = #"{"candidates":[{"content":{"parts":[{"text":"Done","thoughtSignature":"sig"}],"role":"model"},"finishReason":"STOP"}]}"#

    @Test func shouldUseATunedModelEndpointsIdWithNoPublishersGoogleSuffix() async throws {
        let transport = RecordingTransport(response: jsonResponse(textResponse))
        _ = try await provider(transport).languageModel("endpoints/1234567890").generate(LanguageModelRequest(messages: [.user("Hello")]))
        #expect(await transport.requests().first?.url.absoluteString == "https://test-location-aiplatform.googleapis.com/v1beta1/projects/test-project/locations/test-location/endpoints/1234567890:generateContent")
    }

    @Test func shouldRespectACustomBaseURLForTunedModelEndpointsIds() async throws {
        let transport = RecordingTransport(response: jsonResponse(textResponse))
        _ = try await provider(transport, baseURL: "https://custom-endpoint.example.com/publishers/google").languageModel("endpoints/1234567890").generate(LanguageModelRequest(messages: [.user("Hello")]))
        #expect(await transport.requests().first?.url.absoluteString == "https://custom-endpoint.example.com/publishers/google/endpoints/1234567890:generateContent")
    }

    @Test func modelIdsWithAPathAreNotPrefixedWithModels() async throws {
        let transport = RecordingTransport(response: jsonResponse(textResponse))
        _ = try await provider(transport).languageModel("models/gemini-4.0-flash").generate(LanguageModelRequest(messages: [.user("Hello")]))
        #expect(await transport.requests().first?.url.absoluteString == "https://test-location-aiplatform.googleapis.com/v1beta1/projects/test-project/locations/test-location/publishers/google/models/gemini-4.0-flash:generateContent")
    }

    @Test func geminiProviderMetadataIsWrittenUnderVertexNamespaces() async throws {
        let transport = RecordingTransport(response: jsonResponse(textResponse))
        let result = try await provider(transport).languageModel("gemini-2.5-flash").generate(LanguageModelRequest(messages: [.user("Hello")]))
        #expect(result.providerMetadata["google"] == nil)
        #expect(result.providerMetadata["googleVertex"]?["groundingMetadata"] == .null)
        #expect(result.providerMetadata["vertex"] == result.providerMetadata["googleVertex"])
        #expect(result.content == [.text("Done", providerMetadata: ["googleVertex": ["thoughtSignature": "sig"], "vertex": ["thoughtSignature": "sig"]])])
    }

    @Test func streamedGeminiProviderMetadataIsWrittenUnderVertexNamespaces() async throws {
        let transport = RecordingTransport(response: sseResponse("data: " + textResponse))
        var parts: [LanguageStreamPart] = []
        for try await part in try provider(transport).languageModel("gemini-2.5-flash").stream(LanguageModelRequest(messages: [.user("Hello")])) {
            parts.append(part)
        }
        #expect(parts.contains { if case let .textStart(_, metadata) = $0 { return metadata["googleVertex"]?["thoughtSignature"] == "sig" && metadata["google"] == nil }; return false })
        guard case let .finishMetadata(_, _, metadata)? = parts.last else { Issue.record("missing finish"); return }
        #expect(metadata["google"] == nil)
        #expect(metadata["googleVertex"]?["usageMetadata"] == .null)
        #expect(metadata["vertex"] != nil)
    }

    @Test func vertexReadsHTTPAndCloudStorageURLsDirectly() throws {
        let model = try provider(RecordingTransport(response: jsonResponse(textResponse))).languageModel("gemini-2.5-flash")
        #expect(isURLSupported(mediaType: "image/*", url: "gs://bucket/image.png", supportedURLs: model.supportedURLs))
        #expect(isURLSupported(mediaType: "image/*", url: "https://example.com/image.png", supportedURLs: model.supportedURLs))
    }

    @Test func vertexRejectsProviderReferencesAndPrefersVertexThoughtSignatures() async throws {
        let transport = RecordingTransport(response: jsonResponse(textResponse))
        let model = try provider(transport).languageModel("gemini-2.5-flash")
        await #expect(throws: AIError.self) {
            _ = try await model.generate(LanguageModelRequest(messages: [AIMessage(role: .user, content: [.providerReference(mimeType: "application/pdf", reference: ["google": "files/abc"])])]))
        }
        let call = AIToolCall(id: "call1", name: "getWeather", arguments: "{}", providerMetadata: ["vertex": ["thoughtSignature": "vertex_sig"], "google": ["thoughtSignature": "google_sig"]])
        _ = try await model.generate(LanguageModelRequest(messages: [.user("Hi"), .assistant(toolCalls: [call])]))
        let body = try decodeJSONBody(try #require(await transport.requests().last?.body))
        #expect(body["contents"]?[1]?["parts"]?[0]?["thoughtSignature"] == "vertex_sig")
        #expect(body["contents"]?[1]?["parts"]?[0]?["functionCall"]?["id"] == nil)
    }
}
