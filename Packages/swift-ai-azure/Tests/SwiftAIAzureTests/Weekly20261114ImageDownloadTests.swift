import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIAzure

private actor WeeklyAzureTokenCounter {
    var count = 0
    func token() -> String { count += 1; return "entra-token" }
}

@Suite struct Weekly20261114ImageDownloadTests {
    @Test(arguments: ["MAI-Image-2.6", "gpt-image-1"], [true, false]) func untrustedImageDownloadsUseRawTransportWithoutProviderCredentials(modelID: String, usesToken: Bool) async throws {
        let png = AIHTTPResponse(statusCode: 200, headers: ["content-type": "image/png"], body: Data([0x89, 0x50, 0x4e, 0x47]))
        let redirect = AIHTTPResponse(statusCode: 302, headers: ["location": "https://cdn.example.com/image.png"], body: Data())
        var responses = [redirect, png]
        if modelID == "gpt-image-1" { responses.append(png) }
        responses.append(jsonResponse(#"{"data":[{"b64_json":"iVBORw0KGgo="}]}"#))
        let transport = RecordingTransport(responses: responses)
        let tokens = WeeklyAzureTokenCounter()
        let tokenProvider: AzureOpenAITokenProvider? = usesToken ? { @Sendable in await tokens.token() } : nil
        let provider = try AzureOpenAIProvider(resourceName: "test-resource", tokenProvider: tokenProvider, configuration: .init(apiKey: usesToken ? nil : "azure-key", headers: ["x-provider-secret": "provider-secret"], transport: transport))
        let result = try await provider.imageModel(modelID).generateImage(.init(prompt: "Edit", files: [.init(url: "https://files.example.com/image.png")], mask: modelID == "gpt-image-1" ? .init(url: "https://files.example.com/mask.png") : nil))
        #expect(result.base64Images.count == 1)
        let sent = await transport.requests()
        #expect(sent.count == (modelID == "gpt-image-1" ? 4 : 3))
        for download in sent.dropLast() {
            #expect(download.headers["authorization"] == nil)
            #expect(download.headers["api-key"] == nil)
            #expect(download.headers["x-provider-secret"] == nil)
        }
        if usesToken { #expect(sent.last?.headers["authorization"] == "Bearer entra-token") }
        else { #expect(sent.last?.headers["api-key"] == "azure-key") }
        #expect(sent.last?.headers["x-provider-secret"] == "provider-secret")
        #expect(await tokens.count == (usesToken ? 1 : 0))
    }
}
