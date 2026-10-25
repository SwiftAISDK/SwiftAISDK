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

@Test func generateTextRejectsRequiredToolChoiceWithoutMatchingCall() async throws {
    let model = MockLanguageModel(result: TextGenerationResult(
        text: "No tool call.",
        content: [.reasoning("I will not call it."), .text("No tool call.")],
        finishReason: "stop",
        rawValue: .object([:])
    ))
    let tool = AITool(
        name: "lookup",
        parameters: ["type": "object", "properties": [:]]
    ) { _ in ["ok": true] }

    do {
        _ = try await AI.generateText(
            model: model,
            request: LanguageModelRequest(
                messages: [.user("Look it up")],
                toolChoice: "required"
            ),
            executableTools: [tool],
            maxSteps: 1
        )
        Issue.record("Expected required tool choice to be enforced.")
    } catch let error as AIToolChoiceViolationError {
        #expect(error.toolChoice["type"]?.stringValue == "required")
        #expect(error.finishReason == "stop")
        #expect(error.providerID == "mock")
        #expect(error.modelID == "mock-language")
        #expect(error.content == [.reasoning("I will not call it."), .text("No tool call.")])
    }
}

@Test func generateTextRejectsDifferentForcedToolCall() async throws {
    let wrongCall = AIToolCall(id: "call-1", name: "other", arguments: "{}")
    let model = MockLanguageModel(result: TextGenerationResult(
        text: "",
        finishReason: "tool-calls",
        toolCalls: [wrongCall],
        rawValue: .object([:])
    ))
    let lookup = AITool(
        name: "lookup",
        parameters: ["type": "object", "properties": [:]]
    ) { _ in ["ok": true] }
    let other = AITool(
        name: "other",
        parameters: ["type": "object", "properties": [:]]
    ) { _ in ["ok": true] }

    do {
        _ = try await AI.generateText(
            model: model,
            request: LanguageModelRequest(
                messages: [.user("Look it up")],
                toolChoice: ["type": "tool", "toolName": "lookup"]
            ),
            executableTools: [lookup, other],
            maxSteps: 1
        )
        Issue.record("Expected forced tool name to be enforced.")
    } catch let error as AIToolChoiceViolationError {
        #expect(error.description.contains("required tool 'lookup'"))
        #expect(error.content.contains(.toolCall(wrongCall)))
    }
}
