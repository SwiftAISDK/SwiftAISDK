import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIProdia

@Test func weekly20261114ProdiaURLVideoInputUsesInjectedTransportAndPreservesCancellation() async throws {
    let controller = AIAbortController()
    let bytes = Data("downloaded-image".utf8)
    let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 200, headers: ["content-type": "image/webp"], body: bytes))
    let resolved = try await prodiaVideoInputImage(
        from: .init(url: "https://cdn.example.test/input.webp"),
        transport: transport, abortSignal: controller.signal
    )
    #expect(resolved.data == bytes)
    #expect(resolved.mimeType == "image/webp")
    let request = try #require(await transport.requests().first)
    #expect(request.method == "GET")
    #expect(request.headers.isEmpty)
    #expect(request.abortSignal?.isAborted == false)
    controller.abort()
    #expect(request.abortSignal?.isAborted == true)
}
