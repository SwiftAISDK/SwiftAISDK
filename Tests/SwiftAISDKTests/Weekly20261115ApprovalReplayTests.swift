// Exact ai@7.0.173 tool-approval-follow-up.test.ts fixture, both APIs and both
// preserved-schema-input branches. See private core-ui-review.json for provenance.
import Foundation
import Testing
import SwiftAIProvider
import SwiftAIProviderUtilities
@testable import SwiftAI
@testable import SwiftAISDK

@Suite("Weekly20261115ApprovalReplay", .serialized)
struct Weekly20261115ApprovalReplayTests {
    @Test(arguments: [false, true], [false, true])
    func signedReplayPreservesApprovedOperationAndOriginalMessages(_ streaming: Bool, _ hasSchemaInput: Bool) async throws {
        let input: JSONValue = ["counter": ["value": 2]], arguments = try decisionJSONText(input)
        let signature = signToolApproval(secret: "test-secret", approvalID: "approval", toolCallID: "call", toolName: "record", input: input)
        let messages: [AIMessage] = [
            .assistant(toolCalls: [.init(id: "call", name: "record", arguments: arguments)], toolApprovalRequests: [
                .init(id: "approval", toolName: "record", arguments: arguments, toolCallID: "call",
                      inputSchemaInput: hasSchemaInput ? ["counter": ["value": 1]] : nil, providerMetadata: ["signature": .string(signature)])]),
            .toolResponses(approvalResponses: [.init(id: "approval", approved: true)])
        ]
        let originalMessages = messages, state = WeeklyReplayState(), model = WeeklyReplayModel()
        let tool = AITool(name: "record", parameters: ["type": "object"], refineArguments: { input in
            var object = try #require(input.objectValue), counter = try #require(object["counter"]?.objectValue)
            counter["value"] = .number(try #require(counter["value"]?.doubleValue) + 1)
            object["counter"] = .object(counter)
            return .object(object)
        }) { input in await state.executed(input); return "recorded" }
        let responseResults: [AIToolResult]
        if streaming {
            var results: [AIToolResult] = []
            for try await part in SwiftAISDK.AI.streamText(model: model, request: .init(messages: messages), executableTools: [tool], maxSteps: 3,
                toolApproval: { _ in .userApproval }, toolApprovalSecret: "test-secret", retryPolicy: .none,
                onError: { event in await state.error(String(describing: event.error)) }) {
                if case let .toolResult(result) = part { results.append(result) }
            }
            responseResults = results
            #expect(await state.errors.isEmpty)
        } else {
            let result = try await SwiftAISDK.AI.generateText(model: model, request: .init(messages: messages), executableTools: [tool], maxSteps: 3,
                toolApproval: { _ in .userApproval }, toolApprovalSecret: "test-secret", retryPolicy: .none)
            #expect(result.text == "OK")
            responseResults = result.responseMessages.filter { $0.role == .tool }.flatMap(\.content).compactMap {
                if case let .toolResult(value) = $0 { return value }; return nil
            }
        }
        let executed = await state.inputs
        #expect(executed == (hasSchemaInput ? [input] : []))
        #expect(messages == originalMessages)
        #expect(responseResults.count == 1)
        let result = try #require(responseResults.first)
        #expect(result.toolCallID == "call")
        #expect(result.toolName == "record")
        if hasSchemaInput {
            #expect(!result.isError)
            #expect(result.result == "recorded")
        } else {
            #expect(result.isError)
            #expect(result.result["type"] == "error-text")
            #expect(result.result["value"]?.stringValue?.contains("does not match the validated schema output") == true)
        }
    }

    @Test(arguments: [false, true])
    func tamperedSignatureFailsBeforeExecutionInBothAPIs(_ streaming: Bool) async throws {
        let input: JSONValue = ["counter": ["value": 2]], arguments = try decisionJSONText(input)
        let signature = signToolApproval(secret: "test-secret", approvalID: "approval", toolCallID: "call", toolName: "record", input: ["counter": ["value": 1]])
        let messages: [AIMessage] = [
            .assistant(toolCalls: [.init(id: "call", name: "record", arguments: arguments)], toolApprovalRequests: [
                .init(id: "approval", toolName: "record", arguments: arguments, toolCallID: "call", providerMetadata: ["signature": .string(signature)])]),
            .toolResponses(approvalResponses: [.init(id: "approval", approved: true)])
        ]
        let state = WeeklyReplayState(), model = WeeklyReplayModel()
        let tool = AITool(name: "record", parameters: ["type": "object"]) { input in await state.executed(input); return "recorded" }
        do {
            if streaming {
                for try await _ in SwiftAISDK.AI.streamText(model: model, request: .init(messages: messages), executableTools: [tool], maxSteps: 3,
                    toolApproval: { _ in .userApproval }, toolApprovalSecret: "test-secret", retryPolicy: .none) {}
            } else {
                _ = try await SwiftAISDK.AI.generateText(model: model, request: .init(messages: messages), executableTools: [tool], maxSteps: 3,
                    toolApproval: { _ in .userApproval }, toolApprovalSecret: "test-secret", retryPolicy: .none)
            }
            Issue.record("Expected invalid signature to reject approval replay")
        } catch let error as AIInvalidToolApprovalSignatureError {
            #expect(error.approvalID == "approval")
            #expect(error.toolCallID == "call")
            #expect(error.reason == "invalid signature")
        }
        #expect(await state.inputs.isEmpty)
    }
}

private actor WeeklyReplayState {
    var inputs: [JSONValue] = [], errors: [String] = []
    func executed(_ input: JSONValue) { inputs.append(input) }
    func error(_ message: String) { errors.append(message) }
}
private struct WeeklyReplayModel: LanguageModel {
    let providerID = "test-provider", modelID = "test-model"
    func generate(_ request: LanguageModelRequest) async throws -> TextGenerationResult {
        .init(text: "OK", finishReason: "stop", usage: .init(inputTokens: 1, outputTokens: 1, inputTokensNoCache: 1, outputTextTokens: 1), rawValue: [:])
    }
    func stream(_ request: LanguageModelRequest) -> AsyncThrowingStream<LanguageStreamPart, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.streamStart(warnings: []))
            continuation.yield(.finish(reason: "stop", usage: .init(inputTokens: 1, outputTokens: 1, inputTokensNoCache: 1, outputTextTokens: 1)))
            continuation.finish()
        }
    }
}
