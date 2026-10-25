@testable import SwiftAIAzure
@testable import SwiftAIFal
@testable import SwiftAIDeepSeek
@testable import SwiftAIAnthropic
@testable import SwiftAIOpenAICompatible
@testable import SwiftAIOpenAI
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
private typealias AI = SwiftAISDK.AI
private typealias AIProviders = SwiftAISDK.AIProviders
private typealias AICustomProvider = SwiftAISDK.AICustomProvider
import Foundation
import Testing
@testable import SwiftAISDK

@Test func azureDeepSeekUsesNativeStructuredOutputsLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"{\"value\":\"ok\"}"},"finish_reason":"stop"}],"usage":{"total_tokens":5}}"#))
    let provider = try AIProviders.azure(settings: ProviderSettings(
        apiKey: "azure-key",
        baseURL: "https://resource.openai.azure.com/openai/v1",
        transport: transport
    ))
    let model = try provider.deepseek("deepseek-r1")

    _ = try await model.generate(LanguageModelRequest(
        messages: [.user("Answer.")],
        responseFormat: .json(
            schema: [
                "type": "object",
                "properties": ["value": ["type": "string"]],
                "required": ["value"]
            ],
            name: "answer",
            description: "Answer schema"
        ),
        providerOptions: ["deepseek": ["strictJsonSchema": false]]
    ))

    let request = try #require(await transport.requests().first)
    #expect(request.headers["user-agent"] == "ai-sdk-azure/4.0.110")
    let body = try decodeJSONBody(try #require(request.body))
    #expect(body["messages"]?[0]?["role"]?.stringValue == "user")
    #expect(body["response_format"]?["type"]?.stringValue == "json_schema")
    #expect(body["response_format"]?["json_schema"]?["name"]?.stringValue == "answer")
    #expect(body["response_format"]?["json_schema"]?["description"]?.stringValue == "Answer schema")
    #expect(body["response_format"]?["json_schema"]?["schema"]?["type"]?.stringValue == "object")
    #expect(body["response_format"]?["json_schema"]?["strict"]?.boolValue == false)
    #expect(body["strictJsonSchema"] == nil)
    #expect(body["responseFormat"] == nil)
}
