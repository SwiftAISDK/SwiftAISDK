import Testing
@testable import SwiftAISDK

@Suite("WeeklyMiddleware20261025")
struct WeeklyMiddleware20261025Tests {
    @Test func extractJSONTransformsEachContentBlockAndStructuredSelection() async throws {
        let final = "```json\n{\"value\":\"final\"}\n```"
        let model = wrapLanguageModel(MockLanguageModel(result: .init(
            text: #"{"value":"draft"}"# + final, structuredOutputText: final,
            content: [.text(#"{"value":"draft"}"#), .text(final, providerMetadata: ["test": true])],
            finishReason: "stop", rawValue: .null)), middleware: extractJsonMiddleware())
        let result = try await AI.generateText(model: model, prompt: "json", output: Output.json())
        #expect(result.output == ["value": "final"])
        #expect(result.text == #"{"value":"draft"}{"value":"final"}"#)
        #expect(result.textResult.content.last == .text(#"{"value":"final"}"#, providerMetadata: ["test": true]))
    }

    @Test func reasoningExtractionTransformsSelectedTextWithoutLosingDraft() async throws {
        let selected = #"{<think>First</think>"value":"final"<think>Second</think>}"#
        let model = wrapLanguageModel(MockLanguageModel(result: .init(
            text: #"{"value":"draft"}"# + selected, structuredOutputText: selected,
            content: [.text(#"{"value":"draft"}"#), .text(selected)],
            finishReason: "stop", rawValue: .null)), middleware: extractReasoningMiddleware(tagName: "think", separator: " "))
        let result = try await AI.generateText(model: model, prompt: "json", output: Output.json())
        #expect(result.output == ["value": "final"])
        #expect(result.reasoning == "First Second")
        #expect(result.text == #"{"value":"draft"}{ "value":"final" }"#)
        #expect(result.textResult.structuredOutputText == #"{ "value":"final" }"#)
    }

    @Test func omittedCustomOpeningDelimiterTransformsIndependentSelection() async throws {
        let selected = #"Checking<channel|>{"value":"final"}"#
        let middleware = try extractReasoningMiddleware(delimiters: .init(opening: "<|channel>thought\n", closing: "<channel|>"), startWithReasoning: true)
        let model = wrapLanguageModel(MockLanguageModel(result: .init(text: selected,
            structuredOutputText: selected, finishReason: "stop", rawValue: .null)), middleware: middleware)
        let result = try await AI.generateText(model: model, prompt: "json", output: Output.json())
        #expect(result.output == ["value": "final"])
        #expect(result.reasoning == "Checking")
    }

    @Test func customJSONTransformPreservesExplicitEmptySelection() async throws {
        let model = wrapLanguageModel(MockLanguageModel(result: .init(text: "PREFIX{}SUFFIX",
            structuredOutputText: "", finishReason: "stop", rawValue: .null)),
            middleware: extractJsonMiddleware(transform: { $0.replacingOccurrences(of: "PREFIX", with: "").replacingOccurrences(of: "SUFFIX", with: "") }))
        let result = try await model.generate(.init(messages: [.user("x")]))
        #expect(result.text == "{}")
        #expect(result.structuredOutputText == "")
    }
}
