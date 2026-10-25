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

@Suite("WeeklyApproval20261025")
struct WeeklyApproval20261025Tests {
    @Test(arguments: [true, false])
    func firstDecisionWinsAcrossReplaysConflictsAndApprovalIDs(approved: Bool) throws {
        let call = AIToolCall(id: "call", name: "lookup", arguments: "{}")
        let first = AIToolApprovalResponse(id: "a", approved: approved)
        let responses = [first, first, .init(id: "a", approved: !approved, reason: "replay"),
            .init(id: "b", approved: !approved)]
        let result = try collectToolApprovals(messages: [
            .init(role: .assistant, content: [.toolCall(call),
                .toolApprovalRequest(.init(id: "a", toolName: "lookup", arguments: "{}", toolCallID: "call")),
                .toolApprovalRequest(.init(id: "b", toolName: "lookup", arguments: "{}", toolCallID: "call"))]),
            .toolResponses(approvalResponses: responses)
        ])
        let collected = result.approvedToolApprovals + result.deniedToolApprovals
        #expect(collected.map(\.approvalResponse) == [first])
        #expect(result.approvedToolApprovals.count == (approved ? 1 : 0))
    }

    @Test func restoredDuplicateApprovalsExecuteOnce() async throws {
        let log = ExecutionWrapperLog()
        let tool = AITool(name: "lookup", parameters: ["type": "object"], execute: { _ in
            await log.append("execute"); return "found"
        })
        let response = AIToolApprovalResponse(id: "approval", approved: true)
        let request = LanguageModelRequest(messages: [
            .init(role: .assistant, content: [.toolCall(.init(id: "call", name: "lookup", arguments: "{}")),
                .toolApprovalRequest(.init(id: "approval", toolName: "lookup", arguments: "{}", toolCallID: "call"))]),
            .toolResponses(approvalResponses: [response, response, .init(id: "approval", approved: false)])
        ])
        let result = try await executeHistoricalToolApprovals(request: request, toolsByName: ["lookup": tool], toolApproval: nil)
        #expect(await log.entries() == ["execute"])
        #expect(result.toolResults.count == 1)
    }

    @Test func existingDeniedResultPreventsDuplicateOutput() async throws {
        let response = AIToolApprovalResponse(id: "approval", approved: false)
        let request = LanguageModelRequest(messages: [
            .init(role: .assistant, content: [.toolCall(.init(id: "call", name: "lookup", arguments: "{}")),
                .toolApprovalRequest(.init(id: "approval", toolName: "lookup", arguments: "{}", toolCallID: "call"))]),
            .toolResponses(approvalResponses: [response, response], toolResults: [
                .init(toolCallID: "call", toolName: "lookup", result: ["type": "execution-denied"])
            ])
        ])
        let result = try await executeHistoricalToolApprovals(request: request, toolsByName: [:], toolApproval: nil)
        #expect(result.toolResults.isEmpty)
        #expect(result.responseMessages.isEmpty)
    }
}
