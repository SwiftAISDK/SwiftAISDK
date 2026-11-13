import Foundation
import Testing
@testable import SwiftAIGoogleVertex
import SwiftAIProvider
import SwiftAITransport

@Suite("Weekly20261114 Vertex downloaded assets")
struct Weekly20261114DownloadTests {
    @Test func configuredTransportDownloadsToolFilesWithoutExpressCredentials() async throws {
        let transport = RecordingTransport(responses: [.init(statusCode: 200, headers: ["content-type": "image/png"], body: Data([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a])),
            jsonResponse(#"{"candidates":[{"content":{"parts":[{"text":"done"}]},"finishReason":"STOP"}]}"#)])
        let provider = try GoogleVertexProvider(settings: .init(apiKey: "private-key", transport: transport))
        let model = try provider.languageModel("gemini-4-carbon")
        let result = AIToolResult(toolCallID: "call", toolName: "image", result: ["type": "content", "value": [["type": "file", "mediaType": "image/png", "data": ["type": "url", "url": "https://cdn.example.com/file.png"]]]])
        _ = try await model.generate(.init(messages: [.user("Hi"), .init(role: .tool, content: [.toolResult(result)])]))
        let requests = await transport.requests()
        #expect(requests.count == 2)
        #expect(requests[0].url.host == "cdn.example.com")
        #expect(normalizeHeaders(requests[0].headers)["x-goog-api-key"] == nil)
        #expect(normalizeHeaders(requests[0].headers)["authorization"] == nil)
        #expect(normalizeHeaders(requests[1].headers)["x-goog-api-key"] == "private-key")
    }
    @Test func maaSImageRedirectsUseConfiguredTransportWithoutBearerHeaders() async throws {
        let transport = RecordingTransport(responses: [jsonResponse(#"{"data":[{"url":"https://images.example.com/a"}]}"#),
            .init(statusCode: 302, headers: ["location": "https://cdn.example.com/b"]), .init(statusCode: 200, body: Data([1,2,3]))])
        let provider = try GoogleVertexHostedProvider(endpoint: .maaS, configuration: .init(apiKey: "private-token", baseURL: "https://api.example.com/v1", headers: ["x-provider-key": "secret"], transport: transport))
        let result = try await provider.imageModel("image").generateImage(.init(prompt: "blue"))
        let requests = await transport.requests()
        #expect(result.base64Images == ["AQID"])
        #expect(requests.count == 3)
        #expect(normalizeHeaders(requests[0].headers)["authorization"] == "Bearer private-token")
        for request in requests.dropFirst() {
            #expect(normalizeHeaders(request.headers)["authorization"] == nil)
            #expect(normalizeHeaders(request.headers)["x-provider-key"] == nil)
            #expect(!request.followRedirects)
        }
    }

    @Test func cancelledToolDownloadPreservesSignalAndAvoidsProviderRequest() async throws {
        let signal = AIAbortController()
        let transport = RecordingTransport(response: jsonResponse("{}"))
        let provider = try GoogleVertexProvider(settings: .init(apiKey: "key", transport: transport))
        signal.abort(reason: "cancelled")
        let result = AIToolResult(toolCallID: "c", toolName: "image", result: ["type": "content", "value": [["type": "file", "mediaType": "image/png", "data": ["type": "url", "url": "https://cdn.example.com/file.png"]]]])
        await #expect(throws: (any Error).self) { try await provider.languageModel("gemini-4-carbon").generate(.init(messages: [.init(role: .tool, content: [.toolResult(result)])], abortSignal: signal.signal)) }
        #expect(await transport.requests().isEmpty)
    }
}
