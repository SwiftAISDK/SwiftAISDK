import Foundation
import Testing
@testable import SwiftAISDK

@Suite("WeeklyCore20261023")
struct WeeklyCore20261023Tests {
    @Test func decisionControlsReachProviderCallbacksAndTelemetry() async throws {
        let model = DecisionTestModel(), recorder = TelemetryRecorder()
        let callbacks = WeeklyDecisionCallbacks()
        _ = try await AI.experimentalDecide(model: model, state: "state", questions: decisionTestQuestions,
            maxOutputTokens: 200, reasoning: "high", telemetry: .init(integrations: [recorder]),
            onStart: { await callbacks.recordStart($0) }, onEnd: { await callbacks.recordEnd($0) })
        #expect(model.lastOptions?.maxOutputTokens == 200)
        #expect(model.lastOptions?.reasoning == "high")
        #expect(await callbacks.startEvents().first?.maxOutputTokens == 200)
        #expect(await callbacks.endEvents().first?.reasoning == "high")
        let events = await recorder.events()
        #expect(events.count == 4)
        #expect(events.allSatisfy { $0.input?["maxOutputTokens"] == 200 && $0.input?["reasoning"] == "high" })
    }

    @Test(arguments: [0, -1]) func invalidDecisionBudgetFailsBeforeModelCall(budget: Int) async {
        let model = DecisionTestModel()
        await #expect(throws: AIError.self) {
            try await AI.experimentalDecide(model: model, state: "", questions: decisionTestQuestions, maxOutputTokens: budget)
        }
        #expect(model.callCount == 0)
    }

    @Test func languageDecisionAdapterForwardsExplicitControls() async throws {
        let language = DecisionTestLanguageModel(result: .init(text: #"{"q0":0.3}"#, finishReason: "stop", rawValue: .null))
        _ = try await DecisionLanguageModel(model: language).doDecide(.init(
            state: [.text("state")], questions: ["q": .boolean(instructions: "True?")],
            maxOutputTokens: 321, reasoning: "high"
        ))
        #expect(language.lastRequest?.maxOutputTokens == 321)
        #expect(language.lastRequest?.reasoning == "high")
    }

    @Test func decisionAllowsNullInstructionsAndOneScoreLevelWithoutRelaxingEvaluation() throws {
        let questions: [String: AIDecisionQuestion] = [
            "c": .choice(criteria: ["a": .null]), "s": .score(criteria: ["one"]),
            "b": .boolean(criteria: ["true": "valid"])
        ]
        try validateDecisionInput(state: "", questions: questions)
        #expect(throws: AIError.self) { try validateEvaluationInput(state: "", questions: questions) }
        #expect(throws: AIError.self) { try validateDecisionInput(state: "", questions: ["b": .boolean()]) }
        #expect(throws: AIError.self) { try validateDecisionInput(state: "", questions: ["b": .boolean(criteria: ["true": .null])]) }
        #expect(throws: AIError.self) { try validateDecisionInput(state: "", questions: ["box": .box(instructions: .null)]) }
    }

    @Test func pruningDropsOnlyReasoningGroupsWhoseFollowingContentWasRemoved() {
        let call = AIContentPart.toolCall(.init(id: "call", name: "lookup", arguments: "{}"))
        let retained = AIContentPart.toolCall(.init(id: "keep", name: "other", arguments: "{}"))
        let message = AIMessage(role: .assistant, content: [
            .reasoning("old"), .reasoning("old continuation"), call,
            .reasoning("mixed"), call, .text("answer"),
            .reasoning("retained"), retained,
            .reasoning("trailing")
        ])
        let result = pruneMessages([message], toolCalls: [.all(tools: ["lookup"])])
        #expect(result.first?.content == [.reasoning("mixed"), .text("answer"), .reasoning("retained"), retained, .reasoning("trailing")])
        #expect(pruneMessages([.init(role: .assistant, content: [.reasoning("only"), call])], toolCalls: [.all()]).isEmpty)
        #expect(pruneMessages([message], toolCalls: [.beforeLastMessage()]) == [message])
    }

    @Test func reusedUIToolCallIDUpdatesItsNameDuringInputAndCompletion() throws {
        var reducer = AIUIMessageStreamReducer()
        _ = try reducer.consume(.toolInputStart(id: "id", name: "old"))
        _ = try reducer.consume(.toolInputStart(id: "id", name: "new"))
        guard case let .toolCall(started) = try #require(reducer.message.parts.first) else { Issue.record("Missing tool"); return }
        #expect(started.name == "new")
        _ = try reducer.consume(.toolCall(.init(id: "id", name: "final", arguments: "{}")))
        guard case let .toolCall(done) = try #require(reducer.message.parts.first) else { Issue.record("Missing tool"); return }
        #expect(done.name == "final")
        #expect(reducer.message.parts.count == 1)
    }

    @Test(arguments: ["https://service.internal/a", "https://SERVICE.INTERNAL./a"])
    func internalDownloadHostsFailBeforeNetworking(url: String) {
        #expect(throws: AIError.self) { try validateDownloadURL(url) }
    }

    @Test func encodingPathSegmentsPreservesLiteralDotsWithoutPathTraversal() {
        #expect(encodePathSegment("a/b ?#%") == "a%2Fb%20%3F%23%25")
        #expect(encodePathSegment(".") == "%252E")
        #expect(encodePathSegment("..") == "%252E%252E")
        #expect(encodePathSegment("v1.2-_'!()*~") == "v1.2-_'!()*~")
        #expect(encodePathSegment("写真") == "%E5%86%99%E7%9C%9F")
    }
}

private actor WeeklyDecisionCallbacks {
    var starts: [AIDecisionStartEvent] = [], ends: [AIDecisionEndEvent] = []
    func recordStart(_ event: AIDecisionStartEvent) { starts.append(event) }
    func recordEnd(_ event: AIDecisionEndEvent) { ends.append(event) }
    func startEvents() -> [AIDecisionStartEvent] { starts }
    func endEvents() -> [AIDecisionEndEvent] { ends }
}
