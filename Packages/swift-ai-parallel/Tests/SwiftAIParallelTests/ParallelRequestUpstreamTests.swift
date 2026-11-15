import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIParallel

// Translated from parallel-decision-model.test.ts at @ai-sdk/parallel@3.0.9.
@Suite("Parallel matching-release request contract")
struct ParallelRequestUpstreamTests {
    @Test func sendsNativeContractWithConfiguredAuthenticationOptionsAndHeaders() async throws {
        let (transport, model, _) = try parallelSetup()
        var options = parallelOptions()
        options.headers = ["x-call": "custom"]
        options.providerOptions = ["parallel": ["includeExcerpts": false]]
        _ = try await model.doDecide(options)
        let requests = await transport.requests()
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.url.absoluteString == "https://example.com/v1/decisions")
        #expect(request.headers["x-api-key"] == "test-key")
        #expect(request.headers["x-provider"] == "custom")
        #expect(request.headers["x-call"] == "custom")
        #expect(request.headers["content-type"] == "application/json")
        #expect(request.headers["authorization"] == nil)
        #expect(request.headers["user-agent"]?.contains("ai-sdk-parallel/3.0.9") == true)
        #expect(try parallelRequestBody(request) == .object([
            "mode": "fast", "include_excerpts": false,
            "state": ["company": "Parallel", "website": "https://parallel.ai"],
            "questions": [
                "hasSearch": ["type": "noul", "instructions": "Does it offer web search?"],
                "availability": ["type": "choice", "instructions": "Is the API available?", "criteria": [
                    "available": "Publicly available", "unknown": "Insufficient evidence"
                ]],
                "fit": ["type": "score", "instructions": "How well does it fit?", "criteria": ["No fit", "Partial fit", "Full fit"]]
            ]
        ]))
    }

    @Test(arguments: [
        [AIDecisionStatePart](), [.text("A company")], [.json(.null)], [.json([1, "two"])],
        [.text("A company"), .json(["website": "https://example.com"])]
    ])
    func preservesJSONAndTextState(_ state: [AIDecisionStatePart]) async throws {
        let (transport, model, _) = try parallelSetup()
        var options = parallelOptions(); options.state = state
        _ = try await model.doDecide(options)
        let request = try #require(await transport.requests().first)
        let values: [JSONValue] = state.map { part in
            switch part { case let .text(text): .string(text); case let .json(value): value; case .file: .null }
        }
        #expect(try parallelRequestBody(request)["state"] == (values.count == 1 ? values[0] : .array(values)))
    }

    @Test func rejectsUnsupportedInputsAndInvalidOptionsBeforeIO() async throws {
        let (transport, model, _) = try parallelSetup()
        var options = parallelOptions()
        options.questions = ["box": .box(instructions: "Find a box")]
        await #expect(throws: AIDecisionUnsupportedQuestionTypeError.self) { try await model.doDecide(options) }
        options = parallelOptions(); options.state = [.file(mediaType: "image/png", data: .base64("abcd"))]
        await #expect(throws: AIDecisionUnsupportedFunctionalityError.self) { try await model.doDecide(options) }
        options = parallelOptions(); options.providerOptions = ["parallel": ["includeExcerpts": "false"]]
        await #expect(throws: AIError.invalidArgument(argument: "providerOptions.parallel.includeExcerpts", message: "includeExcerpts must be a boolean.")) {
            try await model.doDecide(options)
        }
        #expect(await transport.requests().isEmpty)
    }

    static let invalidQuestions: [[String: AIDecisionQuestion]] = [
        [:], Dictionary(uniqueKeysWithValues: (0..<101).map { ("q\($0)", parallelQuestions["hasSearch"]!) }),
        ["bad name": parallelQuestions["hasSearch"]!],
        ["choice": .choice(instructions: "Is the API available?", criteria: ["only": "One option"])],
        ["choice": .choice(instructions: "Is the API available?", criteria: Dictionary(uniqueKeysWithValues: (0..<256).map { ("c\($0)", JSONValue.string("Option")) }))],
        ["score": .score(instructions: "How well does it fit?", criteria: ["One level"])],
        ["score": .score(instructions: "How well does it fit?", criteria: Array(repeating: "Level", count: 11))]
    ]

    @Test(arguments: invalidQuestions)
    func rejectsInvalidQuestionsBeforeIO(_ questions: [String: AIDecisionQuestion]) async throws {
        let (transport, model, _) = try parallelSetup()
        var options = parallelOptions(); options.questions = questions
        do { _ = try await model.doDecide(options); Issue.record("Expected InvalidArgumentError") }
        catch let error as AIError {
            guard case .invalidArgument = error else { Issue.record("Expected invalidArgument, got \(error)"); return }
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func passesAbortSignalThroughUnchanged() async throws {
        let (transport, model, _) = try parallelSetup()
        let controller = AIAbortController()
        var options = parallelOptions(); options.abortSignal = controller.signal
        _ = try await model.doDecide(options)
        #expect(await transport.requests().first?.abortSignal === controller.signal)
    }

    @Test func warnsAboutUnsupportedGenerationAndProviderOptions() async throws {
        let (_, model, _) = try parallelSetup()
        var options = parallelOptions(); options.maxOutputTokens = 10; options.reasoning = "low"
        options.providerOptions = ["parallel": ["unused": true]]
        let result = try await model.doDecide(options)
        #expect(result.warnings == [
            .init(type: "unsupported", feature: "maxOutputTokens"),
            .init(type: "unsupported", feature: "reasoning"),
            .init(type: "unsupported", feature: "providerOptions.parallel.unused")
        ])
    }

    @Test func usesEnvironmentAuthenticationAndDefaultEndpoint() async throws {
        let transport = try ParallelRecordingTransport()
        let provider = createParallel(configuration: .init(environment: ["PARALLEL_API_KEY": "environment-key"], transport: transport))
        _ = try await provider.decisionModel("fast").doDecide(parallelOptions())
        let request = try #require(await transport.requests().first)
        #expect(request.url.absoluteString == "https://api.parallel.ai/v1/decisions")
        #expect(request.headers["x-api-key"] == "environment-key")
        #expect(parallel.providerID == "parallel")
        #expect(try parallel.decisionModel("fast").providerID == "parallel.decision")
    }

    @Test func rejectsUnsupportedModelFamilies() throws {
        let (_, _, provider) = try parallelSetup()
        #expect(throws: AIError.unsupportedModel(provider: "parallel", capability: .language, modelID: "fast")) { try provider.languageModel("fast") }
        #expect(throws: AIError.unsupportedModel(provider: "parallel", capability: .embedding, modelID: "fast")) { try provider.embeddingModel("fast") }
        #expect(throws: AIError.unsupportedModel(provider: "parallel", capability: .image, modelID: "fast")) { try provider.imageModel("fast") }
        #expect(throws: AIDecisionModelResolutionError.noSuchModel(modelID: "")) { try provider.decisionModel("") }
    }
}
