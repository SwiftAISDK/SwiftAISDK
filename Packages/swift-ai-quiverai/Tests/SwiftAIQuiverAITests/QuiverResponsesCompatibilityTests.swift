import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Testing
@testable import SwiftAIQuiverAI


@Test func WeeklyProviderGroupB20260927QuiverArrowUsesResponsesAndCustomTools() async throws {
    let transport = RecordingTransport(response: jsonResponse(#"{"id":"resp-q","status":"completed","output_text":"arrow answer"}"#))
    let provider = try AIProviders.quiverAI(configuration: QuiverAIProviderSettings(apiKey: "quiver-key", transport: transport))
    let result = try await provider.languageModel("arrow-2").generate(LanguageModelRequest(
        messages: [.user("Draw")],
        responseFormat: .json(schema: ["type": "object"], name: "drawing"),
        tools: ["draw": QuiverAITools.customTool(name: "draw", format: QuiverAITools.textFormat())],
        providerOptions: ["quiverai": ["reasoningEffort": "xhigh", "reasoningSummary": "auto"]]
    ))
    let request = try #require(await transport.requests().first)
    let body = try decodeJSONBody(try #require(request.body))
    #expect(request.url.absoluteString == "https://api.quiver.ai/v1/responses")
    #expect(request.headers["user-agent"] == "ai-sdk-quiverai/2.0.69")
    #expect(body["tools"]?[0]?["type"]?.stringValue == "custom")
    #expect(body["reasoning"]?["effort"]?.stringValue == "xhigh")
    #expect(body["reasoning"]?["summary"]?.stringValue == "auto")
    #expect(body["text"] == nil)
    #expect(result.text == "arrow answer")
    #expect(result.warnings.contains { $0.feature == "responseFormat" })

    let responseErrorTransport = RecordingTransport(response: jsonResponse(#"{"error":{"message":"slow down","status_code":429}}"#))
    let responseErrorProvider = try AIProviders.quiverAI(configuration: QuiverAIProviderSettings(apiKey: "quiver-key", transport: responseErrorTransport))
    do {
        _ = try await responseErrorProvider.languageModel("arrow-2").generate(.init(messages: [.user("Draw")]))
        Issue.record("Expected Quiver response error to throw")
    } catch let error as AIError {
        guard case let .apiCall(apiError) = error else {
            Issue.record("Expected Quiver API call error, received \(error)")
            return
        }
        #expect(apiError.statusCode == 429)
        #expect(apiError.isRetryable)
        #expect(apiError.responseBody.contains("status_code"))
    }

    let fractionalStatusTransport = RecordingTransport(response: jsonResponse(#"{"error":{"message":"bad fractional status","status_code":429.5}}"#))
    let fractionalStatusProvider = try AIProviders.quiverAI(configuration: QuiverAIProviderSettings(
        apiKey: "quiver-key",
        transport: fractionalStatusTransport
    ))
    do {
        _ = try await fractionalStatusProvider.languageModel("arrow-2").generate(.init(messages: [.user("Draw")]))
        Issue.record("Expected Quiver fractional response status to throw")
    } catch let error as AIError {
        guard case let .apiCall(apiError) = error else {
            Issue.record("Expected Quiver fractional-status API call error, received \(error)")
            return
        }
        #expect(apiError.statusCode == 400)
        #expect(apiError.isRetryable == false)
        #expect(apiError.responseBody.contains("429.5"))
    }

    let failedResponse = AIHTTPResponse(
        statusCode: 409,
        headers: ["content-type": "application/json"],
        body: Data(#"{"status":409,"code":"conflict","message":"conflict","request_id":"req-1"}"#.utf8)
    )
    let failedTransport = RecordingTransport(response: failedResponse)
    let failedProvider = try AIProviders.quiverAI(configuration: QuiverAIProviderSettings(apiKey: "quiver-key", transport: failedTransport))
    do {
        _ = try await failedProvider.languageModel("arrow-2").generate(.init(messages: [.user("Draw")]))
        Issue.record("Expected Quiver failed HTTP response to throw")
    } catch let error as AIError {
        guard case let .apiCall(apiError) = error else {
            Issue.record("Expected Quiver failed-response API call error, received \(error)")
            return
        }
        #expect(apiError.statusCode == 409)
        #expect(apiError.isRetryable == false)
        #expect(apiError.responseBody == "conflict")
    }
}