import Foundation
import SwiftAIProvider

struct ParallelParsedResponse {
    var answers: [String: AIDecisionAnswer]
    var usage: AIDecisionModelUsage
    var metadata: JSONValue
    var decisionID: String
}

func parseParallelDecisionResponse(_ raw: JSONValue, questionIDs: Set<String>) throws -> ParallelParsedResponse {
    guard let rawAnswers = raw["answers"]?.objectValue,
          let citations = raw["citations"]?.arrayValue,
          let decisionID = raw["decision_id"]?.stringValue,
          let mode = raw["mode"]?.stringValue,
          let usage = raw["usage"]?.objectValue,
          let inputNumber = usage["input_tokens"]?.doubleValue,
          inputNumber.isFinite, inputNumber >= 0, let inputTokens = Int(exactly: inputNumber),
          usage["output_tokens"] == .number(0) else {
        throw invalidParallelResponse("Invalid Parallel Decisions response envelope.")
    }
    var answers: [String: AIDecisionAnswer] = [:]
    var confidence: [String: JSONValue] = [:]
    var legends: [String: JSONValue] = [:]
    for (id, rawAnswer) in rawAnswers {
        guard let object = rawAnswer.objectValue, let type = object["type"]?.stringValue else {
            throw invalidParallelResponse("Invalid Parallel answer \"\(id)\".")
        }
        switch type {
        case "noul":
            answers[id] = .boolean(probability: try parallelProbability(object["noul"], field: "answers.\(id).noul"))
        case "choice":
            guard let choice = object["choice"]?.stringValue else {
                throw invalidParallelResponse("Parallel Choice answer \"\(id)\" is missing choice.")
            }
            answers[id] = .choice(choice: choice, probabilities: try parallelProbabilities(object["probabilities"], id: id))
            if let value = object["confidence"], value != .null {
                confidence[id] = .number(try parallelProbability(value, field: "answers.\(id).confidence"))
            }
        case "score":
            guard let score = object["score"]?.doubleValue, score.isFinite,
                  let legend = object["legend"]?.objectValue, legend.values.allSatisfy({ $0.stringValue != nil }) else {
                throw invalidParallelResponse("Invalid Parallel Score answer \"\(id)\".")
            }
            answers[id] = .score(score: score, probabilities: try parallelProbabilities(object["probabilities"], id: id))
            legends[id] = .object(legend)
            if let value = object["confidence"], value != .null {
                confidence[id] = .number(try parallelProbability(value, field: "answers.\(id).confidence"))
            }
        case "refusal": answers[id] = .refusal
        default: throw invalidParallelResponse("Unknown Parallel answer type \"\(type)\".")
        }
    }
    let parsedCitations: [JSONValue] = try citations.map { citation in
        guard let url = citation["url"]?.stringValue,
              let excerpts = citation["excerpts"]?.arrayValue, excerpts.allSatisfy({ $0.stringValue != nil }) else {
            throw invalidParallelResponse("Invalid Parallel citation.")
        }
        if let title = citation["title"], title != .null, title.stringValue == nil {
            throw invalidParallelResponse("Parallel citation title must be a string or null.")
        }
        return .object(["url": .string(url), "title": citation["title"], "excerpts": .array(excerpts)])
    }
    guard Set(answers.keys) == questionIDs else {
        throw invalidParallelResponse("Parallel Decisions must return exactly one answer for every question.")
    }
    return .init(answers: answers, usage: .init(inputTokens: inputTokens, outputTokens: 0),
                 metadata: .object(["citations": .array(parsedCitations), "confidence": .object(confidence),
                                    "decisionId": .string(decisionID), "legend": .object(legends), "mode": .string(mode)]),
                 decisionID: decisionID)
}

private func parallelProbability(_ raw: JSONValue?, field: String) throws -> Double {
    guard let value = raw?.doubleValue, value.isFinite, (0...1).contains(value) else {
        throw invalidParallelResponse("Parallel \(field) must be a probability between 0 and 1.")
    }
    return value
}

private func parallelProbabilities(_ raw: JSONValue?, id: String) throws -> [String: Double] {
    guard let object = raw?.objectValue else {
        throw invalidParallelResponse("Parallel answer \"\(id)\" is missing probabilities.")
    }
    return try object.mapValues { try parallelProbability($0, field: "answers.\(id).probabilities") }
}

private func invalidParallelResponse(_ message: String) -> AIError {
    .invalidResponse(provider: "parallel.decision", message: message)
}
