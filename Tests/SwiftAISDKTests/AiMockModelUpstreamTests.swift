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

@Test func aiMockEmbeddingModelReturnsArrayBackedEmbedResultsFromFirstEntryLikeUpstream() async throws {
    let model = MockEmbeddingModel(results: [
        EmbeddingResult(embeddings: [[1]], rawValue: .object([:])),
        EmbeddingResult(embeddings: [[2]], rawValue: .object([:]))
    ])

    let first = try await model.embed(EmbeddingRequest(values: ["first"]))
    let second = try await model.embed(EmbeddingRequest(values: ["second"]))

    #expect(first.embeddings == [[1]])
    #expect(second.embeddings == [[2]])
    #expect(model.requests.map(\.values) == [["first"], ["second"]])
}

@Test func aiMockLanguageModelReturnsArrayBackedGenerateResultsFromFirstEntryLikeUpstream() async throws {
    let model = MockLanguageModel(results: [
        TextGenerationResult(text: "first", rawValue: .object([:])),
        TextGenerationResult(text: "second", rawValue: .object([:]))
    ])

    let first = try await model.generate(LanguageModelRequest(messages: [.user("first")]))
    let second = try await model.generate(LanguageModelRequest(messages: [.user("second")]))

    #expect(first.text == "first")
    #expect(second.text == "second")
    #expect(model.requests.count == 2)
}

@Test func aiMockLanguageModelReturnsArrayBackedStreamResultsFromFirstEntryLikeUpstream() async throws {
    let model = MockLanguageModel(
        result: TextGenerationResult(text: "unused", rawValue: .object([:])),
        streamSequences: [
            [
                .textStart(id: "first"),
                .textDeltaPart(id: "first", delta: "first"),
                .textEnd(id: "first")
            ],
            [
                .textStart(id: "second"),
                .textDeltaPart(id: "second", delta: "second"),
                .textEnd(id: "second")
            ]
        ]
    )

    let first = try await collectMockLanguageStreamText(model.stream(LanguageModelRequest(messages: [.user("first")])))
    let second = try await collectMockLanguageStreamText(model.stream(LanguageModelRequest(messages: [.user("second")])))

    #expect(first == "first")
    #expect(second == "second")
    #expect(model.streamRequests.count == 2)
}

private func collectMockLanguageStreamText(
    _ stream: AsyncThrowingStream<LanguageStreamPart, Error>
) async throws -> String {
    var text = ""

    for try await part in stream {
        switch part {
        case let .textDelta(delta):
            text += delta
        case let .textDeltaPart(_, delta, _):
            text += delta
        default:
            break
        }
    }

    return text
}
