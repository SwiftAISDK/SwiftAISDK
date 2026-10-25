@testable import SwiftAIVercel
import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Testing


@Test func vercelLanguageUsesV0EndpointAndChatProviderID() async throws {
    let transport = RecordingTransport(response: jsonResponse("""
    {"choices":[{"message":{"content":"v0 response"},"finish_reason":"stop"}],"usage":{"total_tokens":3}}
    """))
    let provider = try AIProviders.vercel(configuration: VercelProviderSettings(apiKey: "vercel-key", transport: transport))
    let model = try provider.languageModel("v0-1.5-md")

    let result = try await model.generate(LanguageModelRequest(messages: [.user("Build UI")]))

    #expect(provider.providerID == "vercel")
    #expect(model.providerID == "vercel.chat")
    #expect(result.text == "v0 response")
    let request = try #require(await transport.requests().first)
    #expect(request.url.absoluteString == "https://api.v0.dev/v1/chat/completions")
    #expect(request.headers["authorization"] == "Bearer vercel-key")
    #expect(request.headers["user-agent"] == "ai-sdk/vercel/3.0.30")
    let body = try decodeJSONBody(try #require(request.body))
    #expect(body["model"]?.stringValue == "v0-1.5-md")
    #expect(body["messages"]?[0]?["content"]?.stringValue == "Build UI")
}

@Test func vercelCallableProviderReturnsChatModelLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse("""
    {"choices":[{"message":{"content":"callable v0"},"finish_reason":"stop"}],"usage":{"total_tokens":3}}
    """))
    let provider = try AIProviders.vercel(configuration: VercelProviderSettings(apiKey: "vercel-key", transport: transport))
    let model = try provider("v0-1.5-lg")

    let result = try await model.generate(LanguageModelRequest(messages: [.user("Build UI")]))

    #expect(model.providerID == "vercel.chat")
    #expect(model.modelID == "v0-1.5-lg")
    #expect(result.text == "callable v0")
    let request = try #require(await transport.requests().first)
    #expect(request.url.absoluteString == "https://api.v0.dev/v1/chat/completions")
    #expect(request.headers["authorization"] == "Bearer vercel-key")
    #expect(request.headers["user-agent"] == "ai-sdk/vercel/3.0.30")
    let body = try decodeJSONBody(try #require(request.body))
    #expect(body["model"]?.stringValue == "v0-1.5-lg")
}

@Test func vercelLanguageUsesCustomSettingsLikeUpstreamProvider() async throws {
    let transport = RecordingTransport(response: jsonResponse("""
    {"choices":[{"message":{"content":"custom v0"},"finish_reason":"stop"}]}
    """))
    let provider = try AIProviders.vercel(configuration: VercelProviderSettings(
        apiKey: "ignored-key",
        baseURL: "https://custom.v0.example/v1/",
        headers: [
            "Authorization": "Bearer custom-key",
            "Custom-Header": "custom-value",
            "User-Agent": "CustomApp/1.0"
        ],
        transport: transport
    ))
    let model = try provider("v0-1.0-md")

    _ = try await model.generate(LanguageModelRequest(messages: [.user("Build custom UI")]))

    let request = try #require(await transport.requests().first)
    #expect(request.url.absoluteString == "https://custom.v0.example/v1/chat/completions")
    #expect(request.headers["authorization"] == "Bearer custom-key")
    #expect(request.headers["custom-header"] == "custom-value")
    #expect(request.headers["user-agent"] == "CustomApp/1.0 ai-sdk/vercel/3.0.30")
    let body = try decodeJSONBody(try #require(request.body))
    #expect(body["model"]?.stringValue == "v0-1.0-md")
}

@Test func vercelProviderLoadsAPIKeyBeforeCustomAuthorizationOverrideLikeUpstream() async throws {
    #expect(throws: AIError.missingAPIKey(provider: "vercel", environmentVariables: ["VERCEL_API_KEY"])) {
        _ = try AIProviders.vercel(configuration: VercelProviderSettings(
            headers: ["Authorization": "Bearer custom-key"],
            transport: RecordingTransport(response: jsonResponse("{}"))
        ))
    }

    let transport = RecordingTransport(response: jsonResponse("""
    {"choices":[{"message":{"content":"custom auth"},"finish_reason":"stop"}]}
    """))
    let provider = try AIProviders.vercel(configuration: VercelProviderSettings(
        apiKey: "loaded-key",
        headers: ["Authorization": "Bearer custom-key"],
        transport: transport
    ))
    let model = try provider.languageModel("v0-1.5-md")

    _ = try await model.generate(LanguageModelRequest(messages: [.user("Hi")]))

    let request = try #require(await transport.requests().first)
    #expect(request.headers["authorization"] == "Bearer custom-key")
}

@Test func vercelProviderRejectsUnsupportedModelFamiliesWithVercelID() throws {
    let provider = try AIProviders.vercel(configuration: VercelProviderSettings(apiKey: "vercel-key", transport: RecordingTransport(response: jsonResponse("{}"))))

    #expect(throws: AIError.unsupportedModel(provider: "vercel", capability: .embedding, modelID: "embed")) {
        _ = try provider.embeddingModel("embed")
    }
    #expect(throws: AIError.unsupportedModel(provider: "vercel", capability: .embedding, modelID: "embed")) {
        _ = try provider.textEmbeddingModel("embed")
    }
    #expect(throws: AIError.unsupportedModel(provider: "vercel", capability: .image, modelID: "image")) {
        _ = try provider.imageModel("image")
    }
}