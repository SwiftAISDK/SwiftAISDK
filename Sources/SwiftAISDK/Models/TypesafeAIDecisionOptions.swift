import Foundation

public struct TypeSafeAIDecisionModelOptions: Equatable, Sendable {
    /// Experimental 262k-token request/question context; slower and less accurate upstream.
    public var longContext: Bool?
    public init(longContext: Bool? = nil) { self.longContext = longContext }
    public var providerOptions: [String: JSONValue] {
        ["typesafe": .object(["longContext": longContext.map(JSONValue.bool)])]
    }
}

public struct TypeSafeAIFilePartProviderOptions: Equatable, Sendable {
    public var reference: String?
    public var insertReference: Bool?
    public init(reference: String? = nil, insertReference: Bool? = nil) {
        self.reference = reference; self.insertReference = insertReference
    }
    public var providerOptions: [String: JSONValue] {
        ["typesafe": .object(["reference": reference.map(JSONValue.string), "insertReference": insertReference.map(JSONValue.bool)])]
    }
}

func typesafeOptions(_ options: [String: JSONValue]) throws -> [String: JSONValue] {
    guard let value = options["typesafe"], value != .null else { return [:] }
    guard let object = value.objectValue else {
        throw AIError.invalidArgument(argument: "providerOptions.typesafe", message: "TypeSafe options must be an object.")
    }
    return object
}

struct TypeSafeImagePart {
    var name: String
    var filename: String
    var mediaType: String
    var bytes: Data
}

func prepareTypesafeState(_ state: [AIDecisionStatePart]) throws -> (state: JSONValue, assets: [String: JSONValue], images: [TypeSafeImagePart]) {
    func strings(_ value: JSONValue) -> [String] {
        switch value {
        case let .string(text): [text]
        case let .array(values): values.flatMap(strings)
        case let .object(values): values.values.flatMap(strings)
        default: []
        }
    }
    let stateStrings = state.flatMap { part -> [String] in
        switch part {
        case let .text(text): [text]
        case let .json(value): strings(value)
        case .file: []
        }
    }
    var parts: [AIDecisionStatePart] = []
    var assets: [String: JSONValue] = [:]
    var images: [TypeSafeImagePart] = []
    for (index, part) in state.enumerated() {
        guard case let .file(mediaType, data, filename, providerOptions) = part else { parts.append(part); continue }
        guard mediaType == "image/png" || mediaType == "image/jpeg" else {
            throw AIDecisionUnsupportedFunctionalityError(functionality: "TypeSafe AI decision image media type: \(mediaType)")
        }
        let bytes: Data
        switch data {
        case let .data(value): bytes = value
        case let .base64(value):
            guard let decoded = Data(base64Encoded: value) else {
                throw AIError.invalidArgument(argument: "state", message: "File data must be valid base64.")
            }
            bytes = decoded
        default: throw AIDecisionUnsupportedFunctionalityError(functionality: "TypeSafe AI decision file input must contain data.")
        }
        let options = try typesafeOptions(providerOptions)
        if let reference = options["reference"],
           reference.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            throw AIError.invalidArgument(argument: "providerOptions.typesafe.reference", message: "Image references must be nonempty strings.")
        }
        if let insert = options["insertReference"], insert.boolValue == nil {
            throw AIError.invalidArgument(argument: "providerOptions.typesafe.insertReference", message: "insertReference must be a boolean.")
        }
        let suppliedReference = options["reference"]?.stringValue
        if options["insertReference"]?.boolValue == false && suppliedReference == nil {
            throw AIError.invalidArgument(argument: "providerOptions.typesafe.reference", message: "TypeSafe images with insertReference: false need an explicit reference.")
        }
        let reference = suppliedReference ?? UUID().uuidString
        guard assets[reference] == nil else {
            throw AIError.invalidArgument(argument: "providerOptions.typesafe.reference", message: "Duplicate TypeSafe image reference: \(reference)")
        }
        let name = "image-\(index)"
        assets[reference] = .object(["type": "image", "part": .string(name)])
        images.append(TypeSafeImagePart(name: name, filename: filename ?? "\(name).\(mediaType == "image/png" ? "png" : "jpeg")", mediaType: mediaType, bytes: bytes))
        if options["insertReference"]?.boolValue ?? !stateStrings.contains(where: { $0.contains(reference) }) { parts.append(.text(reference)) }
    }
    if parts.count == 1, case let .json(value) = parts[0] { return (value, assets, images) }
    let text = try parts.map { part -> String in
        switch part {
        case let .text(value): value
        case let .json(value): try decisionJSONText(value)
        case .file: throw AIDecisionUnsupportedFunctionalityError(functionality: "Unprepared TypeSafe image")
        }
    }.joined(separator: "\n")
    return (.string(text), assets, images)
}
