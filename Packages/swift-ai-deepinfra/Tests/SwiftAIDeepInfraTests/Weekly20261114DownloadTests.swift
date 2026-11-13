import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIDeepInfra

@Test func weekly20261114DeepInfraURLImagesAndMaskUseInjectedTransportWithoutProviderCredentials() async throws {
    let transport = RecordingTransport(responses: [
        AIHTTPResponse(statusCode: 200, headers: ["content-type": "image/png"], body: Data("input-image".utf8)),
        AIHTTPResponse(statusCode: 200, headers: ["content-type": "image/png"], body: Data("input-mask".utf8)),
        jsonResponse(#"{"data":[{"b64_json":"edited"}]}"#)
    ])
    let provider = try DeepInfraProvider(configuration: .init(apiKey: "provider-secret", transport: transport))
    let result = try await provider.imageModel("black-forest-labs/FLUX.1-Kontext-dev").generateImage(.init(
        prompt: "edit", files: [.init(url: "https://cdn.example.test/image.png")],
        mask: .init(url: "https://cdn.example.test/mask.png")
    ))
    #expect(result.base64Images == ["edited"])
    let requests = await transport.requests()
    #expect(requests.map(\.method) == ["GET", "GET", "POST"])
    #expect(requests.prefix(2).allSatisfy { $0.headers["authorization"] == nil && $0.headers["Authorization"] == nil })
    #expect(requests.last?.headers["authorization"] == "Bearer provider-secret")
    let body = String(data: try #require(requests.last?.body), encoding: .utf8) ?? ""
    #expect(body.contains("input-image"))
    #expect(body.contains("input-mask"))
}
