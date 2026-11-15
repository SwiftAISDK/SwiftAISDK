import Foundation
import SwiftAIProvider

public typealias ParallelDecisionModelID = String
public typealias Experimental_ParallelDecisionModelId = ParallelDecisionModelID

public struct ParallelDecisionModelOptions: Equatable, Sendable {
    /// Include evidence excerpts in citations. The service defaults to true.
    public var includeExcerpts: Bool?
    public init(includeExcerpts: Bool? = nil) { self.includeExcerpts = includeExcerpts }
    public var providerOptions: [String: JSONValue] {
        ["parallel": .object(["includeExcerpts": includeExcerpts.map(JSONValue.bool)])]
    }
}

public struct ParallelDecisionProviderMetadata: Equatable, Sendable, Codable {
    public struct Citation: Equatable, Sendable, Codable {
        public var url: String
        public var title: String?
        public var excerpts: [String]
        public init(url: String, title: String? = nil, excerpts: [String]) {
            self.url = url; self.title = title; self.excerpts = excerpts
        }
    }
    public var citations: [Citation]
    public var confidence: [String: Double]
    public var decisionID: String
    public var legend: [String: [String: String]]
    public var mode: String

    public init(citations: [Citation], confidence: [String: Double], decisionID: String,
                legend: [String: [String: String]], mode: String) {
        self.citations = citations; self.confidence = confidence; self.decisionID = decisionID
        self.legend = legend; self.mode = mode
    }

    enum CodingKeys: String, CodingKey { case citations, confidence, decisionID = "decisionId", legend, mode }
}

public let parallelDecisionModelIDs = ["fast"]
public let parallelSupportedQuestionTypes: [AIDecisionQuestionType] = [.boolean, .choice, .score]
public let parallelProviderOptions: AIProviderOptionDefinitions = [
    .decision: ["includeExcerpts": .init(description: "Include evidence excerpts in citations. Defaults to true.")]
]

public func getParallelDecisionModelEntry(_ modelID: String) -> AIModelEntry<JSONValue> {
    .init(capabilities: .init(decision: .init(
        questionTypes: .init(boolean: .supported, choice: .supported, score: .supported, box: .unsupported),
        inputs: .init(image: .unsupported), reasoning: .unsupported, maxOutputTokens: .unsupported)),
          providerOptions: [.decision: ["includeExcerpts": parallelDecisionModelIDs.contains(modelID) ? .supported : .unknown]])
}

public let parallelModelCatalog = Dictionary(uniqueKeysWithValues: parallelDecisionModelIDs.map { ($0, getParallelDecisionModelEntry($0)) })
