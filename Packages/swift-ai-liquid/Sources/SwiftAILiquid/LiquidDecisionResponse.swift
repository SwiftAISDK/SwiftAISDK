import SwiftAIProvider

struct LiquidDecisionResponse: Decodable {
    let model: String?
    let answers: [String: Answer]
    let usage: Usage?

    var metadata: JSONValue {
        .object([
            "cost": usage?.cost.map(JSONValue.number),
            "confidence": .object(answers.compactMapValues { $0.confidence.map(JSONValue.number) }),
            "legend": .object(answers.compactMapValues(\.legend)),
            "found": .object(answers.compactMapValues { $0.found.map(JSONValue.number) })
        ])
    }

    struct Usage: Decodable {
        let inputTokens: Double?
        let outputTokens: Double?
        let cost: Double?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cost
        }

        var tokens: AIDecisionModelUsage {
            .init(inputTokens: inputTokens.flatMap(Int.init(exactly:)), outputTokens: outputTokens.flatMap(Int.init(exactly:)))
        }
    }

    struct Answer: Decodable {
        let value: AIDecisionAnswer
        let confidence: Double?
        let legend: JSONValue?
        let found: Double?

        enum CodingKeys: String, CodingKey {
            case type, noul, choice, score, probabilities, confidence, legend, found, box
        }

        enum Kind: String, Decodable { case noul, choice, score, box }

        init(from decoder: any Decoder) throws {
            let fields = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try fields.decode(Kind.self, forKey: .type)
            confidence = kind == .noul ? nil : try fields.decodeIfPresent(Probability.self, forKey: .confidence)?.value
            legend = kind == .score ? try fields.decodeIfPresent([String: JSONValue].self, forKey: .legend).map(JSONValue.object) : nil
            found = kind == .box ? try fields.decodeIfPresent(Probability.self, forKey: .found)?.value : nil
            switch kind {
            case .noul:
                value = .boolean(probability: try fields.decode(Probability.self, forKey: .noul).value)
            case .choice:
                let choice = try fields.decode(String.self, forKey: .choice)
                let probabilities = try fields.decode([String: Probability].self, forKey: .probabilities)
                value = .choice(choice: choice, probabilities: probabilities.mapValues(\.value))
            case .score:
                let score = try fields.decode(Double.self, forKey: .score)
                let probabilities = try fields.decode([String: Probability].self, forKey: .probabilities)
                value = .score(score: score, probabilities: probabilities.mapValues(\.value))
            case .box:
                let box = try fields.decodeIfPresent(Box.self, forKey: .box)
                value = box.map { .box(box: $0.value) } ?? .refusal
            }
        }
    }
}

private struct Probability: Decodable {
    let value: Double

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(Double.self)
        guard (0...1).contains(value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a probability between 0 and 1.")
        }
    }
}

private struct Box: Decodable {
    let top: Probability
    let bottom: Probability
    let left: Probability
    let right: Probability

    var value: AIDecisionBox {
        .init(top: top.value, bottom: bottom.value, left: left.value, right: right.value)
    }
}
