import Foundation
import Testing
@testable import SwiftAISDK

/// The umbrella `AIProviders.<name>(settings:)` factories must behave like the
/// native provider packages, which follow the upstream `@ai-sdk/*` sources.
@Suite("Umbrella factories match native provider packages")
struct UmbrellaNativeProviderParityTests {
    private let chatResponse = #"{"id":"chat-1","object":"chat.completion","model":"m","choices":[{"index":0,"message":{"role":"assistant","content":"{}"},"finish_reason":"stop"}]}"#

    // openai-chat-language-model.ts: a JSON schema always becomes `json_schema` and is sent
    // unchanged; unsupported service tiers are removed with a warning.
    @Test func openAIChatUsesNativeChatPolicy() async throws {
        let transport = RecordingTransport(response: jsonResponse(chatResponse))
        let provider = try AIProviders.openAI(settings: ProviderSettings(apiKey: "key", transport: transport))
        let schema: JSONValue = ["type": "object", "properties": ["a": ["type": "string"]]]
        let result = try await provider.chatModel("gpt-4o").generate(LanguageModelRequest(
            messages: [.user("Hi")],
            responseFormat: .json(schema: schema),
            providerOptions: ["openai": ["serviceTier": "flex"]]
        ))
        let request = try #require(await transport.requests().first)
        let body = try decodeJSONBody(try #require(request.body))
        #expect(body["response_format"]?["type"]?.stringValue == "json_schema")
        #expect(body["response_format"]?["json_schema"]?["schema"]?["additionalProperties"] == nil)
        #expect(body["service_tier"] == nil)
        #expect(result.warnings.contains { $0.feature == "serviceTier" })
    }

    @Test func moonshotAndDeepSeekRouteToNativeModels() throws {
        let moonshot = try AIProviders.moonshotAI(settings: ProviderSettings(apiKey: "key"))
        #expect(try moonshot.languageModel("kimi-k2.5") is MoonshotAIChatLanguageModel)
        #expect(try moonshot.chatModel("kimi-k2.5").providerID == "moonshotai.chat")

        let deepSeek = try AIProviders.deepSeek(settings: ProviderSettings(apiKey: "key"))
        let responses = try deepSeek.responses("deepseek-v4-flash")
        #expect(responses is DeepSeekResponsesLanguageModel)
        #expect(responses.providerID == "deepseek.responses")
    }

    // Native Baseten, DeepInfra and Fireworks chat return empty content instead of throwing.
    @Test(arguments: ["baseten", "deepinfra", "fireworks"])
    func openAICompatibleFamiliesUseNativeChat(_ providerID: String) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"id":"c","choices":[{"index":0,"message":{"role":"assistant","content":null},"finish_reason":"stop"}]}"#))
        let settings = ProviderSettings(apiKey: "key", transport: transport)
        let provider: OpenAICompatibleProvider = switch providerID {
        case "baseten": try AIProviders.baseten(settings: settings)
        case "deepinfra": try AIProviders.deepInfra(settings: settings)
        default: try AIProviders.fireworks(settings: settings)
        }
        let result = try await provider.chatModel("some/model").generate(LanguageModelRequest(messages: [.user("Hi")]))
        #expect(result.text == "")
        let request = try #require(await transport.requests().first)
        #expect(request.headers["authorization"] == "Bearer key")
    }

    // Upstream baseten-provider.ts rewrites JSON mode for DeepSeek V4 Pro 0813 on Model APIs.
    @Test func basetenAppliesNativeDeepSeekJSONTransform() async throws {
        let transport = RecordingTransport(response: jsonResponse(chatResponse))
        let provider = try AIProviders.baseten(settings: ProviderSettings(apiKey: "key", transport: transport))
        _ = try await provider.languageModel("deepseek-ai/DeepSeek-V4-Pro-0813").generate(LanguageModelRequest(
            messages: [.user("Hi")], responseFormat: .json(schema: ["type": "object"])
        ))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["response_format"] == nil)
    }

    @Test func byteDanceImagesAndDeepgramStreamingAreAvailable() throws {
        let byteDance = try AIProviders.byteDance(settings: ProviderSettings(apiKey: "key"))
        #expect(byteDance.supportedCapabilities.contains(.image))
        #expect(try byteDance.imageModel("seedream-5-0-260128") is ByteDanceImageModel)

        let deepgram = try AIProviders.deepgram(settings: ProviderSettings(apiKey: "key"))
        #expect(try deepgram.streamingTranscriptionModel("nova-3") is DeepgramStreamingTranscriptionModel)
    }

    @Test func alibabaAcceptsNativeEmbeddingURLSetting() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"output":{"embeddings":[{"text_index":0,"embedding":[1]}]}}"#))
        let provider = try AIProviders.alibaba(
            settings: ProviderSettings(apiKey: "key", baseURL: "https://proxy.example/compatible-mode/v1", transport: transport),
            embeddingBaseURL: "https://dashscope.aliyuncs.com/api/v1"
        )
        _ = try await provider.embeddingModel("text-embedding-v4").embed(.init(values: ["one"]))
        let request = try #require(await transport.requests().first)
        #expect(request.url.absoluteString.hasPrefix("https://dashscope.aliyuncs.com/api/v1/"))
    }

    // Each umbrella user agent matches the native package and `Porting/upstream-lock.json`.
    @Test func userAgentsMatchNativePackages() async throws {
        let transport = RecordingTransport(response: jsonResponse(chatResponse))
        let compatible = try AIProviders.openAICompatible(name: "custom", baseURL: "https://example.com/v1", apiKey: "key", transport: transport)
        _ = try await compatible.chatModel("m").generate(LanguageModelRequest(messages: [.user("Hi")]))
        #expect(await transport.requests().first?.headers["user-agent"] == "ai-sdk-openai-compatible/3.0.92")

        let settings = ProviderSettings(apiKey: "key", environment: [:])
        let byteDance = try OpenAICompatibleProvider.buildHeaders(providerID: "bytedance", authorization: .none, settings: settings)
        #expect(byteDance["user-agent"] == nil)
    }
}
