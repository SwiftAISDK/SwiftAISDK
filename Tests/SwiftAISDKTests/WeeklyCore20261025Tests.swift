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

@Suite("WeeklyCore20261025")
struct WeeklyCore20261025Tests {
    @Test func jsonSelectionPreservesDraftContent() async throws {
        let draft = #"{"value":"draft"}"#, final = #"{"value":"final"}"#
        let model = MockLanguageModel(result: .init(
            text: draft + final, structuredOutputText: final,
            content: [.reasoning("Checking"), .text(draft), .text(final)],
            finishReason: "stop", rawValue: ["source": "raw"]
        ))
        let result = try await AI.generateText(model: model, prompt: "json", output: Output.json())
        #expect(result.output == ["value": "final"])
        #expect(result.text == draft + final)
        #expect(result.textResult.text == draft + final)
        #expect(result.textResult.content == [.reasoning("Checking"), .text(draft), .text(final)])
        #expect(result.textResult.structuredOutputText == final)
    }

    @Test func generateObjectParsesSelectionWhileStepCallbackRetainsRawText() async throws {
        let log = ExecutionWrapperLog()
        let draft = #"{"value":"draft"}"#, final = #"{"value":"final"}"#
        let model = MockLanguageModel(result: .init(text: draft + final, structuredOutputText: final,
            finishReason: "stop", rawValue: .null))
        let result = try await AI.generateObject(model: model, prompt: "json", as: WeeklySelectedValue.self,
            callbacks: .init(onStepFinish: { event in await log.append(event.text) }))
        #expect(result.object.value == "final")
        #expect(result.textResult.text == draft + final)
        #expect(await log.entries() == [draft + final])
    }

    @Test(arguments: ["", #"{"value":"#])
    func invalidSelectedJSONNeverFallsBackToValidDraft(selection: String) async {
        let model = MockLanguageModel(result: .init(text: #"{"value":"draft"}"#,
            structuredOutputText: selection, finishReason: "stop", rawValue: .null))
        await #expect(throws: AIObjectGenerationError.self) {
            try await AI.generateText(model: model, prompt: "json", output: Output.json())
        }
    }

    @Test func explicitTextOutputIgnoresStructuredSelection() async throws {
        let model = MockLanguageModel(result: .init(text: "Draft. Final.",
            structuredOutputText: "Final.", finishReason: "stop", rawValue: .null))
        let result = try await AI.generateText(model: model, prompt: "text", output: Output.text())
        #expect(result.output == "Draft. Final.")
    }

    @Test(arguments: [false, true])
    func selectedJSONSurvivesFinalToolStepWithoutReusingPreviousSelection(explicitFinal: Bool) async throws {
        let final = #"{"value":"final"}"#, draft = #"{"value":"draft"}"#
        let model = MockLanguageModel(results: [
            .init(text: draft, structuredOutputText: draft, finishReason: "tool-calls",
                toolCalls: [.init(id: "call", name: "lookup", arguments: "{}")], rawValue: .null),
            .init(text: explicitFinal ? draft + final : final,
                structuredOutputText: explicitFinal ? final : nil, finishReason: "stop", rawValue: .null)
        ])
        let tool = AITool(name: "lookup", parameters: ["type": "object"], execute: { _ in "found" })
        let result = try await AI.generateText(model: model, request: .init(messages: [.user("json")]),
            output: Output.json(), executableTools: [tool], maxSteps: 2)
        #expect(result.output == ["value": "final"])
        #expect(result.text == (explicitFinal ? draft + final : final))
        #expect(result.textResult.steps.count == 2)
    }

    @Test(arguments: ["stop", "tool-calls", "interrupted"])
    func toolChoiceNoneRejectsBeforeRepairsRefinersCallbacksAndExecution(reason: String) async throws {
        let log = ExecutionWrapperLog()
        let tool = AITool(name: "lookup", parameters: ["type": "object"],
            onInputStart: { _ in await log.append("start") },
            onInputAvailable: { _ in await log.append("available") },
            refineArguments: { input in await log.append("refine"); return input },
            execute: { _ in await log.append("execute"); return "found" })
        let call = AIToolCall(id: "call", name: "lookup", arguments: "invalid json")
        let model = MockLanguageModel(result: .init(text: "", finishReason: reason,
            toolCalls: [call], rawValue: .null))
        do {
            _ = try await AI.generateText(model: model,
                request: .init(messages: [.user("x")], toolChoice: "none"), executableTools: [tool],
                repairToolCall: { _ in await log.append("repair"); return nil })
            Issue.record("Expected tool choice violation")
        } catch let error as AIToolChoiceViolationError {
            #expect(error.toolChoice == ["type": "none"])
            #expect(error.finishReason == reason)
            #expect(error.description == "Model response contained a tool call even though tool choice was none.")
        }
        #expect(await log.entries().isEmpty)
        #expect(model.requests.count == 1)
    }

    @Test func streamingNoneWithholdsEveryToolPartAndNeverRetries() async throws {
        let log = ExecutionWrapperLog()
        let tool = AITool(name: "lookup", parameters: ["type": "object"],
            onInputStart: { _ in await log.append("start") },
            onInputDelta: { _ in await log.append("delta") },
            onInputAvailable: { _ in await log.append("available") },
            refineArguments: { input in await log.append("refine"); return input },
            execute: { _ in await log.append("execute"); return "found" })
        let call = AIToolCall(id: "call", name: "lookup", arguments: "{}")
        let model = MockLanguageModel(result: .init(text: "", rawValue: .null), streamParts: [
            .textStart(id: "text"), .textDeltaPart(id: "text", delta: "Visible"), .textEnd(id: "text"),
            .toolInputStart(id: "call", name: "lookup"), .toolInputDelta(id: "call", delta: "{}"),
            .toolInputEnd(id: "call"), .toolCall(call),
            .toolResult(.init(toolCallID: "call", toolName: "lookup", result: "remote", providerExecuted: true)),
            .toolApprovalRequest(.init(id: "approval", toolName: "lookup", arguments: "{}", toolCallID: "call")),
            .finishMetadata(reason: "tool-calls", usage: nil)
        ])
        var parts: [LanguageStreamPart] = []
        do {
            for try await part in AI.streamText(model: model,
                request: .init(messages: [.user("x")], toolChoice: "none"), executableTools: [tool],
                repairToolCall: { _ in await log.append("repair"); return nil }) {
                parts.append(part)
            }
            Issue.record("Expected tool choice violation")
        } catch let error as AIToolChoiceViolationError {
            #expect(error.content.contains(.toolCall(call)))
        }
        #expect(await log.entries().isEmpty)
        #expect(model.streamRequests.count == 1)
        #expect(parts.contains(.textDeltaPart(id: "text", delta: "Visible")))
        #expect(!parts.contains { part in
            switch part {
            case .toolInputStart, .toolInputStartText, .toolInputDelta, .toolInputEnd,
                 .toolCall, .toolResult, .toolApprovalRequest, .toolApprovalResponse: return true
            default: return false
            }
        })
    }

    @Test func nonePreservesToolDefinitionsAndAllowsText() async throws {
        let model = MockLanguageModel(result: .init(text: "No tool call.", finishReason: "stop", rawValue: .null))
        let tool = AITool(name: "lookup", parameters: ["type": "object"], execute: { _ in "unused" })
        let result = try await AI.generateText(model: model,
            request: .init(messages: [.user("x")], toolChoice: "none"), executableTools: [tool])
        #expect(result.text == "No tool call.")
        #expect(model.requests.first?.tools["lookup"] != nil)
        #expect(model.requests.first?.toolChoice == "none")
    }

    @Test func noneSuppressesOrphanApprovalWithoutResolvingToolInput() async throws {
        let model = MockLanguageModel(result: .init(text: "", rawValue: .null), streamParts: [
            .toolApprovalRequest(.init(id: "approval", toolName: "lookup", arguments: "{}", toolCallID: "missing")),
            .finishMetadata(reason: "stop", usage: nil)
        ])
        var approvals = 0
        for try await part in AI.streamText(model: model,
            request: .init(messages: [.user("x")], toolChoice: "none")) {
            if case .toolApprovalRequest = part { approvals += 1 }
        }
        #expect(approvals == 0)
    }

    @Test(arguments: [JSONValue.string("required"), ["type": "tool", "toolName": "lookup"]])
    func interruptedGenerationPreservesPartialAnswerWithoutForcedToolViolation(choice: JSONValue) async throws {
        let model = MockLanguageModel(result: .init(text: "Partial", finishReason: "interrupted", rawValue: .null),
            streamParts: [.textStart(id: "t"), .textDeltaPart(id: "t", delta: "Partial"),
                .textEnd(id: "t"), .finishMetadata(reason: "interrupted", usage: nil)])
        let request = LanguageModelRequest(messages: [.user("x")], toolChoice: choice)
        #expect(try await AI.generateText(model: model, request: request).finishReason == "interrupted")
        var finish: String?
        for try await part in AI.streamText(model: model, request: request) {
            if case let .finishMetadata(reason, _, _) = part { finish = reason }
        }
        #expect(finish == "interrupted")
    }

    @Test func interruptedToolResponseNeitherExecutesNorContinues() async throws {
        let log = ExecutionWrapperLog()
        let tool = AITool(name: "lookup", parameters: ["type": "object"], execute: { _ in
            await log.append("execute"); return "found"
        })
        let call = AIToolCall(id: "call", name: "lookup", arguments: "{}")
        let model = MockLanguageModel(result: .init(text: "Partial", finishReason: "interrupted",
            toolCalls: [call], rawValue: .null), streamParts: [.toolCall(call), .finishMetadata(reason: "interrupted", usage: nil)])
        _ = try await AI.generateText(model: model, request: .init(messages: [.user("x")]), executableTools: [tool])
        for try await _ in AI.streamText(model: model, request: .init(messages: [.user("x")]), executableTools: [tool]) {}
        #expect(await log.entries().isEmpty)
        #expect(model.requests.count == 1)
        #expect(model.streamRequests.count == 1)
    }

    @MainActor @Test func interruptedChatBlocksAutomaticContinuationAndLateToolUpdates() async throws {
        let transport = WeeklyInterruptedChatTransport()
        var automaticCalls = 0
        let session = AIChatSession(transport: transport, generateMessageID: { "response" },
            sendAutomaticallyWhen: { _ in automaticCalls += 1; return automaticCalls == 1 })
        await session.sendMessage("x", id: "user").value
        #expect(session.messages.last?.metadata["finishReason"] == "interrupted")
        #expect(session.status == .ready)
        session.addToolOutput(.init(toolCallID: "call", toolName: "lookup", result: "late"))
        session.addToolApprovalResponse(.init(id: "approval", approved: true))
        #expect(transport.sendCount == 1)
        #expect(automaticCalls == 0)
        #expect(session.error == nil)
    }
}

private struct WeeklySelectedValue: Codable, Sendable { var value: String }

private final class WeeklyInterruptedChatTransport: AIChatTransport, @unchecked Sendable {
    var sendCount = 0
    func sendMessages(_ request: AIChatTransportRequest) throws -> AsyncThrowingStream<AIUIMessage, Error> {
        sendCount += 1
        return AsyncThrowingStream { continuation in
            continuation.yield(.assistant(id: request.responseMessageID ?? "response", parts: [
                .text(.init(text: "Partial")),
                .toolCall(.init(id: "call", name: "lookup", arguments: "{}")),
                .toolApprovalRequest(.init(id: "approval", toolName: "lookup", arguments: "{}", toolCallID: "call"))
            ], metadata: ["finishReason": "interrupted"]))
            continuation.finish()
        }
    }
}
