import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
import SwiftAIOpenAICompatible
@testable import SwiftAITencent

private let tencentChatResponse: JSONValue = ["id": "chatcmpl-1", "object": "chat.completion", "created": 1_794_120_000, "model": "hy4", "choices": [["index": 0, "message": ["role": "assistant", "content": "Hello"], "finish_reason": "stop"]], "usage": ["prompt_tokens": 3, "completion_tokens": 1, "total_tokens": 4]]
private let tencentChatPrompt = [AIMessage.user("Hi")]

@Suite("Tencent provider release-matched upstream scenarios")
struct TencentProviderUpstreamTests {
    @Test func chatFactoryAliases() throws {
        let provider = createTencent(configuration: .init(apiKey: "test-key"))
        let model = provider.chat("hy4")
        #expect(model.providerID == "tencent.chat")
        #expect(model.modelID == "hy4")
        #expect(provider.chat("hy3").modelID == "hy3")
        #expect(try provider.languageModel("hy3").modelID == "hy3")
        #expect(provider.chatModel("hy3").modelID == "hy3")
    }
    @Test func tokenHubChatKeyOptionsUsage() async throws {
        let transport = TencentRecordingTransport(try tencentJSONResponse(tencentChatResponse))
        let provider = createTencent(configuration: .init(apiKey: "test-key", environment: [:], transport: transport))
        let result = try await provider.chat("hy4").generate(.init(messages: tencentChatPrompt,
            providerOptions: ["tencent": ["reasoningEffort": "high", "thinking": ["type": "enabled"]]]))
        let call = try #require(await transport.requests().first)
        #expect(call.url.absoluteString == "https://tokenhub-intl.tencentcloudmaas.com/v1/chat/completions")
        #expect(call.headers["authorization"] == "Bearer test-key")
        #expect(call.headers["user-agent"]?.contains("ai-sdk-tencent/3.0.3") == true)
        #expect(try decodeJSONBody(try #require(call.body)) == ["model": "hy4", "messages": [["role": "user", "content": "Hi"]], "reasoning_effort": "high", "thinking": ["type": "enabled"]])
        #expect(result.text == "Hello")
        #expect(result.content == [.text("Hello")])
        #expect(result.usage?.inputTokens == 3)
    }
    @Test func environmentTokenHubKey() async throws {
        let transport = TencentRecordingTransport(try tencentJSONResponse(tencentChatResponse))
        _ = try await createTencent(configuration: .init(environment: ["TENCENT_TOKENHUB_API_KEY": "env-key"], transport: transport)).chat("hy4").generate(.init(messages: tencentChatPrompt))
        #expect(await transport.requests().first?.headers["authorization"] == "Bearer env-key")
    }
    @Test func missingTokenHubKeyFailsAtRequest() async throws {
        let transport = TencentRecordingTransport(try tencentJSONResponse(tencentChatResponse))
        let model = createTencent(configuration: .init(environment: [:], transport: transport)).chat("hy4")
        await #expect(throws: AIError.missingAPIKey(provider: "tencent", environmentVariables: ["TENCENT_TOKENHUB_API_KEY"])) {
            _ = try await model.generate(.init(messages: tencentChatPrompt))
        }
        #expect(await transport.requests().isEmpty)
    }
    @Test func customTokenHubURLAndHeaders() async throws {
        let transport = TencentRecordingTransport(try tencentJSONResponse(tencentChatResponse))
        _ = try await createTencent(configuration: .init(apiKey: "test-key", baseURL: "https://custom.example.com/v1/", headers: ["x-custom": "value"], transport: transport)).chat("hy4").generate(.init(messages: tencentChatPrompt))
        let call = try #require(await transport.requests().first)
        #expect(call.url.absoluteString == "https://custom.example.com/v1/chat/completions")
        #expect(call.headers["x-custom"] == "value")
    }
    @Test func videoFactoriesAndLazyCredentials() throws {
        let provider = createTencent(configuration: .init(environment: [:]))
        #expect(try provider.video("kling-video-v3").providerID == "tencent.video")
        #expect(try provider.videoModel("vod/VS/2.0").modelID == "vod/VS/2.0")
        #expect(throws: AIError.unsupportedModel(provider: "tencent", capability: .video, modelID: "not-a-model")) { try provider.video("not-a-model") }
    }
    @Test func configuredVodSigningHeaders() async throws {
        let transport = TencentRecordingTransport(try tencentJSONResponse(["Response": ["TaskId": "task-1", "RequestId": "req-1"]]))
        let settings = TencentProviderSettings(secretId: "AKIDEXAMPLE", secretKey: "EXAMPLESECRET", subAppId: "1500000000", region: "ap-singapore", headers: ["x-custom": "value"], environment: [:], transport: transport)
        _ = try await createTencent(configuration: settings).video("vod/VS/2.0").startVideoGeneration(.init(request: .init(prompt: "A cat", count: 1)))
        let call = try #require(await transport.requests().first)
        #expect(call.headers["authorization"]?.hasPrefix("TC3-HMAC-SHA256 Credential=AKIDEXAMPLE/") == true)
        #expect(call.headers["x-tc-region"] == "ap-singapore")
        #expect(call.headers["x-custom"] == "value")
        #expect(call.headers["user-agent"]?.contains("ai-sdk-tencent/3.0.3") == true)
        #expect(try decodeJSONBody(try #require(call.body))["SubAppId"] == 1_500_000_000)
    }
    @Test func environmentVodCredentials() async throws {
        let transport = TencentRecordingTransport(try tencentJSONResponse(["Response": ["TaskId": "task-1"]]))
        let provider = createTencent(configuration: .init(environment: ["TENCENTCLOUD_SECRET_ID": "AKIDENV", "TENCENTCLOUD_SECRET_KEY": "ENVSECRET", "TENCENTCLOUD_VOD_SUB_APP_ID": "1500000001"], transport: transport))
        _ = try await provider.video("vod/VS/2.0").startVideoGeneration(.init(request: .init(prompt: "A cat")))
        let call = try #require(await transport.requests().first)
        #expect(call.headers["authorization"]?.hasPrefix("TC3-HMAC-SHA256 Credential=AKIDENV/") == true)
        #expect(try decodeJSONBody(try #require(call.body))["SubAppId"] == 1_500_000_001)
    }
    @Test(arguments: ["not-a-number", "0", "-1", "1.5", "9007199254740992"])
    func invalidSubAppId(_ id: String) async throws {
        let transport = TencentRecordingTransport(try tencentJSONResponse(["Response": ["TaskId": "task-1"]]))
        let model = try createTencent(configuration: .init(secretId: "AKIDEXAMPLE", secretKey: "EXAMPLESECRET", subAppId: id, environment: [:], transport: transport)).video("vod/VS/2.0")
        await #expect(throws: AIError.invalidArgument(argument: "subAppId", message: "Tencent VOD SubAppId must be a positive integer.")) {
            _ = try await model.startVideoGeneration(.init(request: .init(prompt: "A cat")))
        }
        #expect(await transport.requests().isEmpty)
    }
    @Test func unsupportedModelFamilies() {
        let provider = createTencent()
        #expect(throws: AIError.unsupportedModel(provider: "tencent", capability: .embedding, modelID: "model")) { try provider.embeddingModel("model") }
        #expect(throws: AIError.unsupportedModel(provider: "tencent", capability: .embedding, modelID: "model")) { try provider.textEmbeddingModel("model") }
        #expect(throws: AIError.unsupportedModel(provider: "tencent", capability: .image, modelID: "model")) { try provider.imageModel("model") }
    }
}
