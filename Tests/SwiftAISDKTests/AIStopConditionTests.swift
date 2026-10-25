@testable import SwiftAIAnthropic
@testable import SwiftAIOpenAICompatible
@testable import SwiftAIOpenAI
@testable import SwiftAI
@testable import SwiftAIProviderUtilities
private typealias AI = SwiftAISDK.AI
private typealias AIProviders = SwiftAISDK.AIProviders
private typealias AICustomProvider = SwiftAISDK.AICustomProvider
import Testing
@testable import SwiftAISDK

@Test func aiStopConditionsMatchUpstreamStepHelpers() async throws {
    let searchStep = AIToolStep(
        index: 0,
        text: "",
        toolCalls: [AIToolCall(id: "call-1", name: "search", arguments: "{}")]
    )
    let finalStep = AIToolStep(
        index: 1,
        text: "",
        toolCalls: [AIToolCall(id: "call-2", name: "finalAnswer", arguments: "{}")]
    )
    let context = AIStopConditionContext(steps: [searchStep, finalStep])

    #expect(try await AIStopCondition.isStepCount(2).evaluate(context))
    #expect(try await !AIStopCondition.isStepCount(1).evaluate(context))
    #expect(try await !AIStopCondition.isLoopFinished().evaluate(context))
    #expect(try await AIStopCondition.hasToolCall("finalAnswer").evaluate(context))
    #expect(try await AIStopCondition.hasToolCall("search", "finalAnswer").evaluate(context))
    #expect(try await !AIStopCondition.hasToolCall("search").evaluate(context))
}
