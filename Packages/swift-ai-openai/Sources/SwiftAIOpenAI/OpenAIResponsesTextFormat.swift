import Foundation
import SwiftAIProvider
import SwiftAIProviderUtilities

/// Validates the stable request format and historical format controls without changing Output parsing.
func openAIResponsesNormalizedTextFormat(_ value: JSONValue, warnings: inout [AIWarning]) throws -> JSONValue {
    guard let object = value.objectValue else {
        throw AIError.invalidArgument(argument: "textFormat", message: "Text format must be an object.")
    }
    if object["type"]?.stringValue == "text" { return ["type": "text"] }
    guard object["type"]?.stringValue == "json_schema",
          let name = object["name"]?.stringValue,
          !name.isEmpty, name.count <= 64,
          name.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil,
          let schema = object["schema"], schema.objectValue != nil,
          object["description"] == nil || object["description"]?.stringValue != nil,
          object["strict"] == nil || object["strict"]?.boolValue != nil else {
        throw AIError.invalidArgument(argument: "textFormat", message: "Text format requires text or a named json_schema with an object schema.")
    }
    let normalized = try normalizeOpenAIJSONSchema(schema)
    warnings.append(contentsOf: normalized.warnings)
    var format: [String: JSONValue] = ["type": "json_schema", "name": .string(name), "schema": normalized.schema]
    format["description"] = object["description"]
    format["strict"] = object["strict"]
    return .object(format)
}

func openAIResponsesValidatedAdditionalTools(_ value: JSONValue) throws -> [JSONValue] {
    guard let definitions = value.arrayValue else {
        throw AIError.invalidArgument(argument: "additionalTools", message: "additionalTools must be an array of tool definitions.")
    }
    func invalid() -> AIError { .invalidArgument(argument: "additionalTools", message: "Invalid additionalTools definition.") }
    func function(_ value: JSONValue) throws {
        let allowed: Set<String> = ["type", "name", "description", "parameters", "strict", "defer_loading"]
        guard let object = value.objectValue, Set(object.keys).isSubset(of: allowed),
              object["type"] == "function", let name = object["name"]?.stringValue, !name.isEmpty,
              object["parameters"]?.objectValue != nil,
              object["description"] == nil || object["description"]?.stringValue != nil,
              object["strict"] == nil || object["strict"]?.boolValue != nil,
              object["defer_loading"] == nil || object["defer_loading"]?.boolValue != nil else { throw invalid() }
    }
    for definition in definitions {
        guard let object = definition.objectValue, let name = object["name"]?.stringValue, !name.isEmpty else { throw invalid() }
        switch object["type"]?.stringValue {
        case "function": try function(definition)
        case "custom":
            guard Set(object.keys).isSubset(of: ["type", "name", "description", "format"]),
                  object["description"] == nil || object["description"]?.stringValue != nil else { throw invalid() }
            if let format = object["format"] {
                guard let format = format.objectValue else { throw invalid() }
                if format["type"] == "text" {
                    guard Set(format.keys) == ["type"] else { throw invalid() }
                } else {
                    guard Set(format.keys) == ["type", "syntax", "definition"], format["type"] == "grammar",
                          ["regex", "lark"].contains(format["syntax"]?.stringValue ?? ""), format["definition"]?.stringValue != nil else { throw invalid() }
                }
            }
        case "namespace":
            guard Set(object.keys).isSubset(of: ["type", "name", "description", "tools"]),
                  object["description"]?.stringValue != nil, let tools = object["tools"]?.arrayValue, !tools.isEmpty else { throw invalid() }
            try tools.forEach(function)
        default: throw invalid()
        }
    }
    return definitions
}
