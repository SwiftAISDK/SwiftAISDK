import SwiftAIProvider
import SwiftAIProviderUtilities

private let liquidImageTypes: Set<String> = ["image/jpeg", "image/png", "image/webp"]
private let liquidAudioTypes: Set<String> = ["audio/wav", "audio/mpeg", "audio/flac", "audio/ogg"]

func liquidDecisionBody(modelID: String, options: AIDecisionModelV4CallOptions) throws -> JSONValue {
    guard (1...128).contains(options.questions.count) else {
        throw AIError.invalidArgument(argument: "questions", message: "Liquid decisions support 1 to 128 questions per request.")
    }
    let questions = try options.questions.map { (id, question) in
        (id, try liquidQuestion(question, id: id))
    }
    let evidence = try LiquidDecisionEvidence(options.state)
    if options.questions.values.contains(where: { $0.type == .box }), evidence.images.count != 1 {
        throw AIError.invalidArgument(argument: "state", message: "Liquid Box questions require exactly one image in the state.")
    }
    let fields: [String: JSONValue?] = [
        "model": .string(modelID),
        "state": evidence.state,
        "images": evidence.images.isEmpty ? Optional.none : .array(evidence.images),
        "audio": evidence.audio.isEmpty ? Optional.none : .array(evidence.audio),
        "questions": .object(Dictionary(uniqueKeysWithValues: questions))
    ]
    return .object(fields)
}

private func liquidQuestion(_ question: AIDecisionQuestion, id: String) throws -> JSONValue {
    let argument = "questions.\(id)"
    guard question.instructions != .null else {
        throw AIError.invalidArgument(argument: "\(argument).instructions", message: "Liquid decision questions require instructions.")
    }
    let type: String
    let criteria: JSONValue?
    switch question {
    case let .choice(_, choices):
        guard (2...255).contains(choices.count) else {
            throw AIError.invalidArgument(argument: "\(argument).criteria", message: "Liquid Choice questions support 2 to 255 options.")
        }
        type = "choice"
        criteria = .object(choices)
    case let .score(_, levels):
        guard (2...10).contains(levels.count), !levels.contains(.null) else {
            throw AIError.invalidArgument(argument: "\(argument).criteria", message: "Liquid Score questions require 2 to 10 non-null levels.")
        }
        type = "score"
        criteria = .array(levels)
    case let .boolean(_, labels):
        type = "noul"
        criteria = labels.map(JSONValue.object)
    case .box:
        type = "box"
        criteria = nil
    }
    return .object(["type": .string(type), "instructions": question.instructions, "criteria": criteria])
}

private struct LiquidDecisionEvidence {
    let state: JSONValue
    let images: [String]
    let audio: [String]

    init(_ parts: [AIDecisionStatePart]) throws {
        var values: [JSONValue] = []
        var images: [String] = []
        var audio: [String] = []
        for part in parts {
            switch part {
            case let .text(text): values.append(.string(text))
            case let .json(value): values.append(value)
            case let .file(mediaType, data, _, _):
                let kind = topLevelMediaType(mediaType)
                switch kind {
                case "image": images.append(try liquidDataURL(mediaType: mediaType, kind: kind, data: data, supported: liquidImageTypes))
                case "audio": audio.append(try liquidDataURL(mediaType: mediaType, kind: kind, data: data, supported: liquidAudioTypes))
                default:
                    throw AIDecisionUnsupportedFunctionalityError(functionality: "Liquid decision file media type: \(mediaType)")
                }
            }
        }
        guard images.count <= 8, audio.count <= 8 else {
            throw AIError.invalidArgument(argument: "state", message: "Liquid decisions support at most 8 images and 8 audio clips per request.")
        }
        self.images = images
        self.audio = audio
        switch (values.count, values.first) {
        case (0, _):
            self.state = .null
        case (1, let .some(value)):
            switch value {
            case .string, .object, .array:
                self.state = value
            default:
                self.state = .string(try decisionJSONText(value))
            }
        default:
            self.state = .string(try values.map { value in
                if let text = value.stringValue { return text }
                return try decisionJSONText(value)
            }.joined(separator: "\n"))
        }
    }
}

private func liquidDataURL(
    mediaType: String,
    kind: String,
    data: AIDecisionFileData,
    supported: Set<String>
) throws -> String {
    let bytes: String
    let resolved: String?
    switch data {
    case let .data(value):
        bytes = value.base64EncodedString()
        resolved = isFullMediaType(mediaType) ? mediaType : detectMediaType(data: value, topLevelType: kind)
    case let .base64(value):
        bytes = value
        resolved = isFullMediaType(mediaType) ? mediaType : detectMediaType(base64: value, topLevelType: kind)
    case .url:
        throw AIDecisionUnsupportedFunctionalityError(functionality: "Liquid decision file input: url")
    case .reference:
        throw AIDecisionUnsupportedFunctionalityError(functionality: "Liquid decision file input: reference")
    }
    guard let resolved, supported.contains(resolved) else {
        throw AIDecisionUnsupportedFunctionalityError(functionality: "Liquid decision \(kind) media type: \(resolved ?? mediaType)")
    }
    return "data:\(resolved);base64,\(bytes)"
}
