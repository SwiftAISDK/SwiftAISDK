@testable import SwiftAIGateway
@testable import SwiftAIFal
@testable import SwiftAIGoogle
@testable import SwiftAIGoogleVertex
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

@Suite("WeeklyGoogle20261023")
struct WeeklyGoogle20261023Tests {
    private let firstGrounding: JSONValue = [
        "webSearchQueries": ["accessible trails"],
        "groundingChunks": [["web": ["uri": "https://one.example", "title": "First source"]]]
    ]
    private let lastGrounding: JSONValue = [
        "webSearchQueries": ["trail slopes"],
        "groundingChunks": [["web": ["uri": "https://two.example", "title": "Last source"]]]
    ]

    private func model(_ vertex: Bool, transport: any AITransport) throws -> any LanguageModel {
        if vertex {
            return try AIProviders.googleVertex(settings: .init(apiKey: "key", transport: transport)).languageModel("gemini-4-argon")
        }
        return try AIProviders.google(settings: .init(apiKey: "key", transport: transport)).languageModel("gemini-4-argon")
    }

    private func raw(
        text: String = "answer",
        reason: String? = "STOP",
        token: String? = nil,
        grounding: JSONValue? = nil,
        inputTokens: Int = 0,
        outputTokens: Int = 0
    ) throws -> String {
        var candidate: [String: JSONValue] = ["content": ["parts": [["text": .string(text)]]]]
        candidate["finishReason"] = reason.map(JSONValue.string)
        candidate["continuationToken"] = token.map(JSONValue.string)
        candidate["groundingMetadata"] = grounding
        return String(decoding: try encodeJSONBody([
            "candidates": [.object(candidate)],
            "usageMetadata": [
                "promptTokenCount": .number(Double(inputTokens)),
                "candidatesTokenCount": .number(Double(outputTokens))
            ]
        ]), as: UTF8.self)
    }

    private func streamResult(_ model: any LanguageModel, request: LanguageModelRequest = .init(messages: [.user("Hello")])) async throws -> (metadata: [String: JSONValue], usage: TokenUsage?, parts: [LanguageStreamPart]) {
        var parts: [LanguageStreamPart] = []
        var metadata: [String: JSONValue] = [:]
        var usage: TokenUsage?
        for try await part in model.stream(request) {
            parts.append(part)
            if case let .finishMetadata(_, value, info) = part {
                usage = value
                metadata = info
            }
        }
        #expect(parts.filter { if case .finishMetadata = $0 { true } else { false } }.count == 1)
        return (metadata, usage, parts)
    }

    @Test(arguments: [false, true], [false, true])
    func generationPreservesGroundingForEveryContinuedRequest(vertex: Bool, terminalGrounding: Bool) async throws {
        // Same continuation/usage pattern as the published Google grounding fixtures.
        let first = try raw(text: "First", reason: "CONTINUATION", token: "next", grounding: firstGrounding, inputTokens: 363, outputTokens: 32_794)
        let last = try raw(text: "Last", reason: "MAX_TOKENS", grounding: terminalGrounding ? lastGrounding : nil, inputTokens: 32_883, outputTokens: 512)
        let transport = RecordingTransport(responses: [jsonResponse(first), jsonResponse(last)])
        let result = try await model(vertex, transport: transport).generate(.init(messages: [.user("Hello")], maxOutputTokens: 33_280))
        #expect(result.providerMetadata["google"]?["groundingMetadataPerRequest"] == .array([firstGrounding, terminalGrounding ? lastGrounding : .null]))
        #expect(result.providerMetadata["google"]?["groundingMetadata"] == (terminalGrounding ? lastGrounding : .null))
        #expect(result.providerMetadata["google"]?["initialPromptTokenCount"] == 363)
        #expect(result.usage?.inputTokens == 33_246 && result.usage?.outputTokens == 33_306)
        #expect(result.text == "FirstLast")
        #expect(await transport.requests().count == 2)
    }

    @Test(arguments: [false, true], [false, true])
    func streamingPreservesLatestGroundingWithinEachRequest(vertex: Bool, terminalGrounding: Bool) async throws {
        let first = sseResponse("data: " + (try raw(text: "First", reason: nil, grounding: firstGrounding)) + "\n\ndata: " + (try raw(text: "", reason: "CONTINUATION", token: "next", grounding: .null, inputTokens: 363, outputTokens: 32_794)))
        let last = sseResponse("data: " + (try raw(text: "Last", reason: nil, grounding: terminalGrounding ? lastGrounding : nil)) + "\n\ndata: " + (try raw(text: "", reason: "MAX_TOKENS", grounding: .null, inputTokens: 32_883, outputTokens: 512)))
        let transport = RecordingTransport(responses: [first, last])
        let result = try await streamResult(model(vertex, transport: transport))
        #expect(result.metadata["google"]?["groundingMetadataPerRequest"] == .array([firstGrounding, terminalGrounding ? lastGrounding : .null]))
        // Published streams retain the last non-null grounding payload globally.
        #expect(result.metadata["google"]?["groundingMetadata"] == (terminalGrounding ? lastGrounding : firstGrounding))
        #expect(result.usage?.inputTokens == 33_246 && result.usage?.outputTokens == 33_306)
        #expect(await transport.requests().count == 2)
    }

    @Test(arguments: [false, true])
    func multipleContinuationsKeepNullGroundingPositions(stream: Bool) async throws {
        let responses = [
            try raw(text: "One", reason: "CONTINUATION", token: "one"),
            try raw(text: "Two", reason: "CONTINUATION", token: "two", grounding: firstGrounding),
            try raw(text: "Three", grounding: lastGrounding)
        ]
        let transport = RecordingTransport(responses: responses.map { stream ? sseResponse("data: " + $0) : jsonResponse($0) })
        let target = try model(false, transport: transport)
        let metadata: [String: JSONValue]
        if stream {
            metadata = try await streamResult(target).metadata
        } else {
            metadata = try await target.generate(.init(messages: [.user("Hello")])).providerMetadata
        }
        #expect(metadata["google"]?["groundingMetadataPerRequest"] == .array([.null, firstGrounding, lastGrounding]))
        #expect(await transport.requests().count == 3)
    }

    @Test(arguments: [false, true], [false, true])
    func singleRequestAndManualResumeOmitPerRequestArray(vertex: Bool, stream: Bool) async throws {
        let response = try raw(reason: "MAX_TOKENS", token: "next", grounding: firstGrounding)
        let transport = RecordingTransport(response: stream ? sseResponse("data: " + response) : jsonResponse(response))
        let target = try model(vertex, transport: transport)
        let request = LanguageModelRequest(messages: [.user("Hello")], providerOptions: ["google": ["continuationToken": "previous"]])
        let metadata: [String: JSONValue]
        if stream {
            metadata = try await streamResult(target, request: request).metadata
        } else {
            metadata = try await target.generate(request).providerMetadata
        }
        #expect(metadata["google"]?["groundingMetadataPerRequest"] == nil)
        #expect(metadata["google"]?["groundingMetadata"] == firstGrounding)
        #expect(await transport.requests().count == 1)
    }

    @Test(arguments: [false, true])
    func failedFirstContinuationDoesNotInventGroundingResponse(vertex: Bool) async throws {
        let first = try raw(reason: "CONTINUATION", token: "next", grounding: firstGrounding, inputTokens: 10, outputTokens: 5)
        let transport = RecordingTransport(responses: [sseResponse("data: " + first), AIHTTPResponse(statusCode: 400, body: Data(#"{"error":{"message":"Invalid continuation token"}}"#.utf8))])
        let result = try await streamResult(model(vertex, transport: transport))
        #expect(result.metadata["google"]?["groundingMetadataPerRequest"] == nil)
        #expect(result.metadata["google"]?["groundingMetadata"] == firstGrounding)
        #expect(result.metadata["google"]?["continuationToken"] == "next")
        #expect(result.usage?.inputTokens == 10 && result.usage?.outputTokens == 5)
        #expect(result.parts.contains { if case .error = $0 { true } else { false } })
    }

    @Test func laterContinuationFailureKeepsOnlySuccessfulResponseSlots() async throws {
        let first = try raw(reason: "CONTINUATION", token: "one", grounding: firstGrounding)
        let second = try raw(reason: "CONTINUATION", token: "two")
        let transport = RecordingTransport(responses: [sseResponse("data: " + first), sseResponse("data: " + second), AIHTTPResponse(statusCode: 400, body: Data(#"{"error":{"message":"Invalid continuation token"}}"#.utf8))])
        let result = try await streamResult(model(false, transport: transport))
        #expect(result.metadata["google"]?["groundingMetadataPerRequest"] == .array([firstGrounding, .null]))
        #expect(result.metadata["google"]?["continuationToken"] == "two")
    }

    @Test(arguments: [nil, "provider-default", "none", "minimal", "low", "medium", "high", "xhigh", "max"] as [String?])
    func gatewayForwardsDecisionReasoningOnlyWhenSupplied(_ reasoning: String?) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"answers":{"flag":{"type":"boolean","probability":0.8}}}"#))
        let target = try GatewayProvider(settings: .init(apiKey: "key", transport: transport)).decisionModel("test-model")
        var options = AIDecisionModelV4CallOptions(state: [.text("State")], questions: ["flag": .boolean(instructions: "True?")])
        options.reasoning = reasoning
        _ = try await target.doDecide(options)
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["reasoning"] == reasoning.map(JSONValue.string))
        #expect(body["maxOutputTokens"] == nil)
    }

    @Test(arguments: [nil, 512] as [Int?])
    func gatewayForwardsDecisionTokenBudgetOnlyWhenSupplied(_ tokens: Int?) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"answers":{"score":{"type":"score","score":0}}}"#))
        let target = try GatewayProvider(settings: .init(apiKey: "key", transport: transport)).decisionModel("liquid/d1-ultra")
        var options = AIDecisionModelV4CallOptions(state: [.text("State")], questions: ["score": .score(instructions: .null, criteria: ["Only level"])])
        options.maxOutputTokens = tokens
        _ = try await target.doDecide(options)
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["maxOutputTokens"] == tokens.map { .number(Double($0)) })
        #expect(body["reasoning"] == nil)
        #expect(body["questions"]?["score"]?["instructions"] == .null)
        #expect(body["questions"]?["score"]?["criteria"] == ["Only level"])
    }

    @Test func gatewayPreservesRawErrorBodyWhenPrototypeKeysAreRejected() {
        let body = #"{"__proto__":{"polluted":true}}"#
        let error = gatewayErrorFromHTTPStatus(statusCode: 500, body: body, headers: ["x-request-id": "req"])
        #expect(error.response == .string(body))
        #expect(error.cause?.responseBody == body)
        #expect(error.headers["x-request-id"] == "req")
        #expect(error.isRetryable)
    }
}
