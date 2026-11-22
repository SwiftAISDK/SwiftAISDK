import Foundation
import SwiftAI
import SwiftAIProvider
import SwiftAITransport
import Testing
@testable import SwiftAIAzure

// @ai-sdk/azure@4.0.130: azure-mai-image-model.test.ts and azure-mai-image-generate-image.test.ts.
@Suite struct AzureMAIBackgroundUpstreamTests {
    private let generations = "https://test-resource.services.ai.azure.com/mai/v1/images/generations"
    private let edits = "https://test-resource.services.ai.azure.com/mai/v1/images/edits"
    private let openAIGenerations = "https://test-resource.openai.azure.com/openai/v1/images/generations?api-version=v1"
    private let maiResponse = #"{"created":1791229019,"model":"MAI-Image-2.6-Flash","size":"768x768","usage":{"num_output_tokens":576,"num_input_text_tokens":10,"num_input_image_tokens":0},"data":[{"b64_json":"iVBORw0KGgo="}]}"#
    private let warning = AIWarning(type: "unsupported", feature: "providerOptions.azure.background",
        message: "The MAI image API supports 'transparent' and 'opaque' backgrounds.")

    private func provider(_ transport: RecordingTransport) throws -> AzureOpenAIProvider {
        try AIProviders.azure(resourceName: "test-resource", configuration: .init(apiKey: "test-key", transport: transport))
    }

    @Test func sendsTransparentBackgroundThroughCoreFacade() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"size":"1024x1024","usage":{"num_output_tokens":1024,"num_input_text_tokens":5,"num_input_image_tokens":0},"data":[{"b64_json":"iVBORw0KGgo="}]}"#))
        let model = try provider(transport).image("MAI-Image-2.7-Flash")
        let result = try await model.generateImage("A red apple", providerOptions: ["azure": ["background": "transparent"]])
        let request = try #require(await transport.requests().first)
        #expect(request.url.absoluteString == generations)
        #expect(try decodeJSONBody(#require(request.body)) == [
            "model": "MAI-Image-2.7-Flash", "prompt": "A red apple", "background": "transparent"
        ])
        #expect(result.warnings.isEmpty)
    }

    @Test(arguments: ["transparent", "opaque"])
    func sendsMAIBackground(_ background: String) async throws {
        let transport = RecordingTransport(response: jsonResponse(maiResponse))
        let result = try await provider(transport).image("MAI-Image-2.7").generateImage(.init(prompt: "A red apple",
            providerOptions: ["azure": ["background": .string(background)]]))
        let request = try #require(await transport.requests().first)
        #expect(try decodeJSONBody(#require(request.body)) == [
            "model": "MAI-Image-2.7", "prompt": "A red apple", "background": .string(background)
        ])
        #expect(result.warnings.isEmpty)
    }

    @Test(arguments: [("MAI-Image-2.7-Flash", false), ("my-mai-deployment", true)])
    func dropsAutoBackgroundOnMAIGenerations(modelID: String, usesOverride: Bool) async throws {
        let transport = RecordingTransport(response: jsonResponse(maiResponse))
        var options: [String: JSONValue] = ["background": "auto"]
        if usesOverride { options["api"] = "mai" }
        let result = try await provider(transport).image(modelID).generateImage(.init(prompt: "A red apple",
            providerOptions: ["azure": .object(options)]))
        let request = try #require(await transport.requests().first)
        #expect(request.url.absoluteString == generations)
        #expect(try decodeJSONBody(#require(request.body))["background"] == nil)
        #expect(result.warnings == [warning])
    }

    @Test(arguments: [
        ("gpt-image-1", false, "auto"), ("gpt-image-1", false, "transparent"),
        ("MAI-Image-2.7", true, "auto"), ("MAI-Image-2.7", true, "opaque")
    ])
    func sendsOpenAIBackgroundWithoutWarnings(modelID: String, usesOverride: Bool, background: String) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"data":[{"b64_json":"aGk="}]}"#))
        var options: [String: JSONValue] = ["background": .string(background)]
        if usesOverride { options["api"] = "openai" }
        let result = try await provider(transport).image(modelID).generateImage(.init(prompt: "A red apple",
            providerOptions: ["azure": .object(options)]))
        let request = try #require(await transport.requests().first)
        #expect(request.url.absoluteString == openAIGenerations)
        #expect(try decodeJSONBody(#require(request.body))["background"] == .string(background))
        #expect(result.warnings.isEmpty)
    }

    @Test func sendsAutoBackgroundInOpenAIImageEdits() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"data":[{"b64_json":"aGk="}]}"#))
        let result = try await provider(transport).image("gpt-image-1").generateImage(.init(prompt: "A red apple",
            files: [.init(data: Data([137, 80, 78, 71]), mediaType: "image/png")],
            providerOptions: ["azure": ["background": "auto"]]))
        let request = try #require(await transport.requests().first)
        let body = String(decoding: try #require(request.body), as: UTF8.self)
        #expect(body.contains("name=\"background\"\r\n\r\nauto\r\n"))
        #expect(result.warnings.isEmpty)
    }

    @Test func sendsTransparentMAIBackgroundInFormField() async throws {
        let transport = RecordingTransport(response: jsonResponse(maiResponse))
        _ = try await provider(transport).image("MAI-Image-2.7-Flash").generateImage(.init(prompt: "A red apple",
            files: [.init(data: Data([1]), mediaType: "image/png")], providerOptions: ["azure": ["background": "transparent"]]))
        let request = try #require(await transport.requests().first)
        #expect(request.url.absoluteString == edits)
        let body = String(decoding: try #require(request.body), as: UTF8.self)
        #expect(body.contains("name=\"background\"\r\n\r\ntransparent\r\n"))
    }

    @Test func dropsAutoBackgroundOnMAIImageEdits() async throws {
        let transport = RecordingTransport(response: jsonResponse(maiResponse))
        let result = try await provider(transport).image("MAI-Image-2.7").generateImage(.init(prompt: "A red apple",
            files: [.init(data: Data([1]), mediaType: "image/png")], providerOptions: ["azure": ["background": "auto"]]))
        let request = try #require(await transport.requests().first)
        let body = String(decoding: try #require(request.body), as: UTF8.self)
        #expect(!body.contains("name=\"background\""))
        #expect(result.warnings.contains(warning))
    }

    @Test func rejectsInvalidBackgroundBeforeHTTP() async throws {
        let transport = RecordingTransport(response: jsonResponse(maiResponse))
        let model = try provider(transport).image("MAI-Image-2.7")
        await #expect(throws: AIError.invalidArgument(argument: "providerOptions.azure.background",
                                                       message: "Invalid Azure image option background.")) {
            _ = try await model.generateImage(.init(prompt: "A red apple", providerOptions: ["azure": ["background": "translucent"]]))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func backgroundCatalogOnlyIncludesMAI27() {
        #expect(azureMAIBackgroundModels == ["mai-image-2.7", "mai-image-2.7-flash"])
    }
}
