@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAITransport
private typealias AIProviders = SwiftAISDK.AIProviders
import Foundation
import Testing
@testable import SwiftAISDK

// Core passes function-tool metadata (`description`, `providerOptions`,
// `inputExamples`, `strict`) inside each `request.tools` schema. Upstream
// providers send only the tool's input schema as parameters, so none of the
// SDK-only keys may leak into the wire parameters.

private let descriptionSentinel = "TOOL_DESCRIPTION_SENTINEL"
private let optionSentinel = "TOOL_PROVIDER_OPTION_SENTINEL"
private let exampleSentinel = "TOOL_INPUT_EXAMPLE_SENTINEL"

private func sentinelTools() -> [String: JSONValue] {
    [
        "weather": [
            "type": "object",
            "properties": ["city": ["type": "string"]],
            "required": ["city"],
            "description": .string(descriptionSentinel),
            "providerOptions": ["custom": ["flag": .string(optionSentinel)]],
            "inputExamples": [["input": ["city": .string(exampleSentinel)]]]
        ]
    ]
}

private func occurrences(of needle: String, in body: String) -> Int {
    body.components(separatedBy: needle).count - 1
}

@Suite("Tool metadata stays out of wire parameters")
struct ToolMetadataWireUpstreamTests {
    static let cases: [(String, String)] = [
        ("openai", "gpt-5"),
        ("anthropic", "claude-sonnet-4-5"),
        ("google", "gemini-2.5-flash"),
        ("mistral", "mistral-large-latest"),
        ("groq", "llama-3.3-70b-versatile"),
        ("cohere", "command-a-03-2025"),
        ("xai", "grok-4"),
        ("deepseek", "deepseek-chat"),
        ("alibaba", "qwen-plus"),
        ("moonshotai", "kimi-k2-0905-preview"),
        ("baseten", "deepseek-ai/DeepSeek-V3-0324"),
        ("cerebras", "llama3.1-8b"),
        ("deepinfra", "meta-llama/Llama-3.3-70B-Instruct"),
        ("fireworks", "accounts/fireworks/models/llama-v3p3-70b-instruct"),
        ("gmicloud", "deepseek-ai/DeepSeek-V3"),
        ("huggingface", "meta-llama/Llama-3.3-70B-Instruct"),
        ("togetherai", "meta-llama/Llama-3.3-70B-Instruct-Turbo"),
        ("vercel", "v0-1.5-md"),
        ("perplexity", "sonar-pro"),
        ("googleVertex", "gemini-2.5-flash"),
        ("googleVertexMaaS", "meta/llama-4-maverick-17b-128e-instruct-maas"),
        ("gateway", "openai/gpt-5"),
    ]

    private func provider(_ id: String, transport: RecordingTransport) throws -> any AIProvider {
        let settings = ProviderSettings(apiKey: "test-key", transport: transport)
        switch id {
        case "openai": return try AIProviders.openAI(settings: settings)
        case "anthropic": return try AIProviders.anthropic(settings: settings)
        case "google": return try AIProviders.google(settings: settings)
        case "mistral": return try AIProviders.mistral(settings: settings)
        case "groq": return try AIProviders.groq(settings: settings)
        case "cohere": return try AIProviders.cohere(settings: settings)
        case "xai": return try AIProviders.xAI(settings: settings)
        case "deepseek": return try AIProviders.deepSeek(settings: settings)
        case "alibaba": return try AIProviders.alibaba(settings: settings)
        case "moonshotai": return try AIProviders.moonshotAI(settings: settings)
        case "baseten": return try AIProviders.baseten(settings: settings)
        case "cerebras": return try AIProviders.cerebras(settings: settings)
        case "deepinfra": return try AIProviders.deepInfra(settings: settings)
        case "fireworks": return try AIProviders.fireworks(settings: settings)
        case "gmicloud": return try AIProviders.gmiCloud(settings: settings)
        case "huggingface": return try AIProviders.huggingFace(settings: settings)
        case "togetherai": return try AIProviders.togetherAI(settings: settings)
        case "vercel": return try AIProviders.vercel(settings: settings)
        case "perplexity": return try AIProviders.perplexity(settings: settings)
        case "googleVertex": return try AIProviders.googleVertex(settings: GoogleVertexProviderSettings(project: "p", location: "us-central1", apiKey: "test-key", transport: transport))
        case "googleVertexMaaS": return try AIProviders.googleVertexMaaS(project: "p", location: "us-central1", settings: settings)
        case "gateway": return try AIProviders.gateway(settings: settings)
        default: throw AIError.invalidArgument(argument: "provider", message: id)
        }
    }

    @Test(arguments: cases)
    func functionToolParametersCarryOnlyTheInputSchema(_ fixture: (String, String)) async throws {
        let transport = RecordingTransport(response: jsonResponse("{}"))
        let model = try provider(fixture.0, transport: transport).languageModel(fixture.1)
        var request = LanguageModelRequest(messages: [.user("Weather in Paris?")])
        request.tools = sentinelTools()
        _ = try? await model.generate(request)

        let sent = await transport.requests() + transport.sendRequests()
        let body = try #require(sent.first?.body.flatMap { String(data: $0, encoding: .utf8) }, "\(fixture.0): no request body")
        // The gateway forwards the V4 function tool, whose `description`,
        // `inputExamples` and `providerOptions` sit beside `inputSchema`
        // (upstream gateway-language-model `getArgs` posts the call options).
        if fixture.0 == "gateway" {
            let tool = try #require(try decodeJSONBody(Data(body.utf8))["tools"]?[0])
            #expect(tool["inputSchema"] == ["type": "object", "properties": ["city": ["type": "string"]], "required": ["city"]], "gateway leaked metadata into inputSchema: \(body)")
            #expect(tool["providerOptions"]?["custom"]?["flag"] == .string(optionSentinel))
            return
        }
        #expect(occurrences(of: optionSentinel, in: body) == 0, "\(fixture.0) leaked providerOptions: \(body)")
        // Anthropic sends `input_examples` natively (upstream anthropic-prepare-tools).
        if fixture.0 != "anthropic" {
            #expect(occurrences(of: exampleSentinel, in: body) == 0, "\(fixture.0) leaked inputExamples: \(body)")
        }
        #expect(occurrences(of: descriptionSentinel, in: body) <= 1, "\(fixture.0) duplicated description into parameters: \(body)")
    }
}
