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

@Suite("WeeklyCore20261018")
struct WeeklyCore20261018Tests {
    private var citation: AICitation {
        AICitation(source: AISource(id: "source", sourceType: "url", url: "https://example.com", title: "Source"), startIndex: 0, endIndex: 4, citedText: "proof")
    }

    @Test func citationConstructorsRetainOriginalUncitedCases() {
        #expect(AIResultContentPart.text("text", citations: []) == .text("text"))
        #expect(LanguageStreamPart.textEnd(id: "t", citations: []) == .textEnd(id: "t"))
        #expect(AIResultContentPart.text("text", citations: [citation]).textValue == "text")
    }

    @Test func citationsSurviveDefaultSimulationFacadeCollectionAndNativeUI() async throws {
        let model = WeeklyCitedModel(content: [.text("text", citations: [citation], providerMetadata: ["test": ["id": "item"]])])
        var collected = LanguageStreamToolStep()
        var reducer = AIUIMessageStreamReducer()
        var endCount = 0
        for try await part in AI.streamText(model: model, request: .init(messages: [.user("test")])) {
            collected.record(part)
            _ = try reducer.consume(part)
            if case .textEndWithCitations = part { endCount += 1 }
        }
        #expect(endCount == 1)
        #expect(collected.orderedContent.flatMap(\.citations) == [citation])
        #expect(collected.sources.isEmpty)
        guard case let .text(text) = try #require(reducer.message.parts.first) else { Issue.record("Missing UI text"); return }
        #expect(text.citations == [citation])
        #expect(text.state == .done)
        #expect(text.providerMetadata["test"]?["id"] == "item")
        #expect(try validateUIMessages([reducer.message]) == [reducer.message])
    }

    @Test func typedTextOutputRetainsSupportingCitations() async throws {
        let model = WeeklyCitedModel(content: [.text("text", citations: [citation]), .text("more", citations: [citation])])
        var finalCitations: [AICitation] = []
        var finalContent: [AIResultContentPart] = []
        for try await part in AI.streamText(model: model, request: .init(messages: [.user("test")]), output: Output.text()) {
            if case let .output(result) = part { finalCitations = result.textResult.citations; finalContent = result.textResult.content }
        }
        #expect(finalCitations == [citation, citation])
        #expect(finalContent.count == 2)
    }

    @Test func simulatedStreamingRetainsCitationOnlyBlocksAndTheirLocalOffsets() async throws {
        let model = WeeklyCitedModel(content: [.text("", citations: [citation]), .text("last")])
        let wrapped = wrapLanguageModel(model, middleware: simulateStreamingMiddleware())
        var collected = LanguageStreamToolStep()
        for try await part in wrapped.stream(.init(messages: [.user("test")])) { collected.record(part) }
        #expect(collected.orderedContent.count == 2)
        #expect(collected.orderedContent[0].citations == [citation])
        #expect(collected.orderedContent[0].textValue == "")
        #expect(collected.text == "last")
    }

    @Test func extractJSONStreamFlushesCitedBlocksExactlyOnce() async throws {
        let model = WeeklyCitedModel(content: [.text("```json\n{\"ok\":true}\n```", citations: [citation])])
        let wrapped = wrapLanguageModel(model, middleware: extractJsonMiddleware())
        var text = "", ends = 0
        for try await part in wrapped.stream(.init(messages: [.user("test")])) {
            if case let .textDeltaPart(_, value, _) = part { text += value }
            if case .textEndWithCitations = part { ends += 1; #expect(part.citations == [citation]) }
        }
        #expect(text == "{\"ok\":true}")
        #expect(ends == 1)
    }

    @Test func citationValidationRejectsNegativeOffsetsAndIncompleteDocumentSources() {
        let bad = AICitation(source: .init(id: "d", sourceType: "document", mediaType: "application/pdf"), startIndex: -1)
        let message = AIUIMessage.assistant(parts: [.text(.init(text: "x", citations: [bad]))])
        #expect(safeValidateUIMessages([message]).issues.count == 2)
    }

    @Test func textEncodedToolInputConcatenatesRawTextAndStoresJSONArguments() throws {
        var reducer = AIUIMessageStreamReducer()
        _ = try reducer.consume(.toolInputStart(id: "tool", name: "shell", inputEncoding: .text))
        _ = try reducer.consume(.toolInputDelta(id: "tool", delta: "echo \"hi", providerMetadata: ["test": ["v": 1]]))
        _ = try reducer.consume(.toolInputDelta(id: "tool", delta: "\"\n"))
        guard case let .toolCall(partial) = try #require(reducer.message.parts.first) else { Issue.record("Missing tool"); return }
        #expect(partial.inputEncoding == .text)
        #expect(try decodeJSONBody(Data(partial.arguments.utf8)) == .string("echo \"hi\"\n"))
        var resumed = AIUIMessageStreamReducer(message: reducer.message)
        _ = try resumed.consume(.toolInputDelta(id: "tool", delta: "next"))
        _ = try resumed.consume(.toolInputEnd(id: "tool"))
        _ = try resumed.consume(.toolCall(.init(id: "tool", name: "shell", arguments: #""echo \"hi\"\nnext""#)))
        guard case let .toolCall(done) = try #require(resumed.message.parts.first) else { Issue.record("Missing completed tool"); return }
        #expect(done.inputEncoding == .text)
        #expect(done.rawInputText == nil)
        #expect(try decodeJSONBody(Data(done.arguments.utf8)) == .string("echo \"hi\"\nnext"))
    }

    @Test func supportedURLMatchingPreservesPathAndQueryCase() {
        let patterns = ["image/*": [AISupportedURLPattern { $0 == "https://example.com/File?token=AbC" }]]
        #expect(isURLSupported(mediaType: "IMAGE/PNG", url: "https://example.com/File?token=AbC", supportedURLs: patterns))
        #expect(!isURLSupported(mediaType: "image/png", url: "https://example.com/file?token=abc", supportedURLs: patterns))
    }

    @Test func boxValidationRequiresFiniteOrderedNormalizedEdges() throws {
        let questions: [String: AIDecisionQuestion] = ["box": .box(instructions: "mug")]
        try validateDecisionInput(state: "image", questions: questions)
        try validateDecisionAnswers(questions: questions, answers: ["box": .box(box: .init(top: 0.1, bottom: 0.9, left: 0.2, right: 1))], rounding: nil, providerID: "test")
        for box in [AIDecisionBox(top: 0, bottom: 0, left: 0, right: 1), .init(top: 0, bottom: 1, left: 0.5, right: 0.4), .init(top: -.infinity, bottom: 1, left: 0, right: 1)] {
            #expect(throws: AIError.self) { try validateDecisionAnswers(questions: questions, answers: ["box": .box(box: box)], rounding: nil, providerID: "test") }
        }
    }

    @Test func choiceMaximumAllowsDeclaredRoundingErrorOnBothProbabilities() throws {
        let questions: [String: AIDecisionQuestion] = ["q": .choice(instructions: "choose", criteria: ["a": .null, "b": .null])]
        try validateDecisionAnswers(questions: questions, answers: ["q": .choice(choice: "a", probabilities: ["a": 0.49, "b": 0.51])], rounding: .init(probabilityDecimals: 1), providerID: "test")
        #expect(throws: AIError.self) { try validateDecisionAnswers(questions: questions, answers: ["q": .choice(choice: "a", probabilities: ["a": 0.4, "b": 0.6])], rounding: .init(probabilityDecimals: 1), providerID: "test") }
    }

    @Test func typesafeBoxAndImagesUseMultipartAndOptInHeaders() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"answers":{"target":{"type":"box","box":{"top":0.1,"bottom":0.9,"left":0.2,"right":0.8},"confidence":0.92}},"usage":{}}"#))
        let model = try TypeSafeAIProvider(settings: .init(apiKey: "key", baseURL: "https://example.com", transport: transport)).decisionModel("jev-preview")
        let result = try await model.doDecide(.init(state: [.text("Inspect"), .file(mediaType: "image/png", data: .base64("AQID"), filename: "photo.png", providerOptions: TypeSafeAIFilePartProviderOptions(reference: "[photo]").providerOptions)], questions: ["target": .box(instructions: "Mug")], providerOptions: ["typesafe": ["longContext": true, "temperature": 0]]))
        #expect(model.supportedQuestionTypes.contains(.box))
        #expect(result.answers["target"] == .box(box: .init(top: 0.1, bottom: 0.9, left: 0.2, right: 0.8)))
        #expect(result.providerMetadata["typesafe"]?["confidence"]?["target"] == 0.92)
        #expect(result.warnings == [.init(type: "unsupported", feature: "providerOptions.typesafe.temperature")])
        let request = try #require(await transport.requests().first)
        #expect(request.headers["typesafe-danger-zone-images"] == "true")
        #expect(request.headers["typesafe-danger-zone-long-context"] == "true")
        #expect(request.headers["content-type"]?.hasPrefix("multipart/form-data; boundary=") == true)
        let data = try #require(request.body), body = String(decoding: data, as: UTF8.self)
        #expect(body.contains("name=\"request\"; filename=\"request.json\""))
        #expect(body.contains("name=\"image-1\"; filename=\"photo.png\""))
        #expect(body.contains("[photo]"))
        #expect(data.range(of: Data([1,2,3])) != nil)
    }

    @Test func typesafeBoxWithoutImageUsesJSONAndEnablesOnlyImageHeader() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"answers":{"q":{"type":"box","box":{"top":0,"bottom":1,"left":0,"right":1}}},"usage":{}}"#))
        let model = try TypeSafeAIProvider(settings: .init(apiKey: "key", transport: transport)).decisionModel("jev-latest")
        _ = try await model.doDecide(.init(state: [.text("state")], questions: ["q": .box(instructions: "box")]))
        let request = try #require(await transport.requests().first)
        #expect(request.headers["typesafe-danger-zone-images"] == "true")
        #expect(request.headers["typesafe-danger-zone-long-context"] == nil)
        #expect(try decodeJSONBody(try #require(request.body))["questions"]?["q"] == ["type": "box", "instructions": "box"])
    }

    @Test func typesafeStateReferencesSearchValuesAndPreserveSingleJSON() throws {
        let options = TypeSafeAIFilePartProviderOptions(reference: "[photo]").providerOptions
        let image: AIDecisionStatePart = .file(mediaType: "image/jpeg", data: .data(Data([1])), providerOptions: options)
        let existing = try prepareTypesafeState([.json(["nested": ["[photo]"]]), image])
        #expect(existing.state == ["nested": ["[photo]"]])
        let keyOnly = try prepareTypesafeState([.json(["[photo]": "value"]), image])
        #expect(keyOnly.state.stringValue?.hasSuffix("\n[photo]") == true)
        let questionOnly = try prepareTypesafeState([.text("state"), .file(mediaType: "image/png", data: .data(Data()), providerOptions: TypeSafeAIFilePartProviderOptions(reference: "[q]", insertReference: false).providerOptions)])
        #expect(questionOnly.state == "state")
        #expect(questionOnly.assets["[q]"]?["part"] == "image-1")
    }

    @Test func typesafeRejectsDuplicateBlankAndImplicitQuestionOnlyReferences() {
        let data = AIDecisionFileData.data(Data([1]))
        let image: AIDecisionStatePart = .file(mediaType: "image/png", data: data, providerOptions: ["typesafe": ["reference": "x"]])
        #expect(throws: AIError.self) { try prepareTypesafeState([image, image]) }
        for options: [String: JSONValue] in [["reference": "  "], ["reference": .null], ["insertReference": .null], ["insertReference": false], ["reference": 1], ["insertReference": "false"]] {
            #expect(throws: AIError.self) { try prepareTypesafeState([.file(mediaType: "image/png", data: data, providerOptions: ["typesafe": .object(options)])]) }
        }
    }

    @Test(arguments: [JSONValue.null, .string("true"), .number(1)])
    func typesafeLongContextInvalidTypesFailBeforeHTTP(value: JSONValue) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"answers":{}}"#))
        let model = try TypeSafeAIProvider(settings: .init(apiKey: "key", transport: transport)).decisionModel("jev-latest")
        await #expect(throws: AIError.self) {
            try await model.doDecide(.init(state: [], questions: ["q": .boolean(instructions: "yes?")], providerOptions: ["typesafe": ["longContext": value]]))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test(arguments: [false, true])
    func publicGenerateAndStreamApplySequentialToolLimit(stream: Bool) async throws {
        let tracker = WeeklyConcurrencyTracker()
        let calls = [0,1,2].map { AIToolCall(id: "call-\($0)", name: "lookup", arguments: "{\"value\":\($0)}") }
        let model = MockLanguageModel(result: TextGenerationResult(text: "", finishReason: "tool-calls", toolCalls: calls, rawValue: .null), streamParts: calls.map(LanguageStreamPart.toolCall) + [.finish(reason: "tool-calls", usage: nil)])
        let tool = AITool(name: "lookup", parameters: ["type": "object", "properties": ["value": ["type": "number"]], "required": ["value"]]) { input in
            let value = input["value"]?.intValue ?? -1
            await tracker.begin(value)
            await Task.yield()
            await tracker.end()
            return .number(Double(value))
        }
        var request = LanguageModelRequest(messages: [.user("lookup")]); request.toolCallConcurrency = 1
        if stream {
            var results: [String] = []
            for try await part in AI.streamText(model: model, request: request, executableTools: [tool], maxSteps: 1) {
                if case let .toolResult(result) = part { results.append(result.toolCallID) }
            }
            #expect(results == calls.map(\.id))
        } else {
            let generated = try await AI.generateText(model: model, request: request, executableTools: [tool], maxSteps: 1)
            #expect(generated.toolResults.map(\.toolCallID) == calls.map(\.id))
        }
        #expect(await tracker.started == [0,1,2])
        #expect(await tracker.peak == 1)
    }

    @Test func toolConcurrencyPreservesOrderAndCapsSimultaneousExecutions() async throws {
        let tracker = WeeklyConcurrencyTracker()
        let output = try await mapToolCallsWithConcurrency([0,1,2,3], concurrency: 2, abortSignal: nil) { value in
            await tracker.begin(value)
            try await Task.sleep(nanoseconds: value == 0 ? 30_000_000 : 10_000_000)
            await tracker.end()
            return value
        }
        #expect(output == [0,1,2,3])
        #expect(await tracker.peak == 2)
    }

    @Test func sequentialToolsStartInOrderAndAbortLeavesQueuedWorkUntouched() async throws {
        let tracker = WeeklyConcurrencyTracker(), controller = AIAbortController()
        await #expect(throws: AIAbortError.self) {
            try await mapToolCallsWithConcurrency([0,1,2], concurrency: 1, abortSignal: controller.signal) { value in
                await tracker.begin(value)
                controller.abort(reason: "stop")
                await tracker.end()
                return value
            }
        }
        #expect(await tracker.started == [0])
        #expect(await tracker.peak == 1)
    }

    @Test func invalidConcurrencyFailsBeforeCallingModel() async {
        let model = MockLanguageModel(result: .init(text: "unused", rawValue: .null))
        var request = LanguageModelRequest(messages: [.user("x")]); request.toolCallConcurrency = 0
        await #expect(throws: AIError.self) { try await AI.generateText(model: model, request: request) }
    }

    @Test func approvalAloneDoesNotReplaceMissingLocalToolResults() {
        let messages: [AIMessage] = [
            .init(role: .assistant, content: [.toolCall(.init(id: "call", name: "tool", arguments: "{}")), .toolApprovalRequest(.init(id: "approval", toolName: "tool", arguments: "{}", toolCallID: "call"))]),
            .init(role: .tool, content: [.toolApprovalResponse(.init(id: "approval", approved: true))])
        ]
        #expect(throws: AIMissingToolResultsError.self) { try convertToLanguageModelPrompt(.init(messages: messages)) }
    }

    @Test func cartesiaFutureTranscriptionUsesStreamingAndWhisperSnapshotsStayBatch() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"text":"batch"}"#))
        let provider = try CartesiaProvider(settings: .init(apiKey: "key", environment: [:], transport: transport))
        for id in ["ink-3", "future-transcription"] {
            await #expect(throws: AIError.self) { try await provider.transcriptionModel(id).transcribe(.init(audio: Data())) }
        }
        #expect(await transport.requests().isEmpty)
        let result = try await provider.transcriptionModel("ink-whisper-2025-06-04").transcribe(.init(audio: Data()))
        #expect(result.text == "batch")
    }

    @Test func restoredApprovalsUseOriginalModelCallOrder() throws {
        let calls = [0,1].map { AIToolCall(id: "call-\($0)", name: "tool", arguments: "{}") }
        let requests = calls.map { AIToolApprovalRequest(id: "approval-\($0.id)", toolName: "tool", arguments: "{}", toolCallID: $0.id) }
        let content: [AIContentPart] = calls.map(AIContentPart.toolCall) + requests.map(AIContentPart.toolApprovalRequest)
        let messages: [AIMessage] = [.init(role: .assistant, content: content), .init(role: .tool, content: requests.reversed().map { .toolApprovalResponse(.init(id: $0.id, approved: true)) })]
        #expect(try collectToolApprovals(messages: messages).approvedToolApprovals.map(\.toolCall.id) == calls.map(\.id))
    }

    @Test func managedSubscriptionsRepresentNullableApplicationTTL() {
        let input = MCPManagedSubscribeInput(name: "event", idempotencyKey: "key", ttlMs: nil)
        guard case .indefinite = input.lifetime else { Issue.record("Expected indefinite subscription"); return }
        let bounded = MCPManagedSubscribeInput(name: "event", idempotencyKey: "key", ttlMs: 1000)
        guard case .milliseconds(1000) = bounded.lifetime else { Issue.record("Expected bounded subscription"); return }
    }
}

private struct WeeklyCitedModel: LanguageModel {
    let providerID = "weekly.citations", modelID = "test"
    let content: [AIResultContentPart]
    func generate(_ request: LanguageModelRequest) async throws -> TextGenerationResult {
        .init(text: content.compactMap(\.textValue).joined(), content: content, rawValue: .null)
    }
}

private actor WeeklyConcurrencyTracker {
    var running = 0, peak = 0
    var started: [Int] = []
    func begin(_ value: Int) { started.append(value); running += 1; peak = max(peak, running) }
    func end() { running -= 1 }
}
