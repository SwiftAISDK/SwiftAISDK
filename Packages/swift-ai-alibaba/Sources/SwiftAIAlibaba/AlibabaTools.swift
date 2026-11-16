import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities


func alibabaTools(from tools: [String: JSONValue]) -> AlibabaPreparedTools {
    var warnings: [AIWarning] = []
    // Swift tool maps are unordered; sort by name for a deterministic wire order.
    let values = tools.sorted { $0.key < $1.key }.compactMap { name, schema -> JSONValue? in
        let object = schema.objectValue
        if object?["type"]?.stringValue == "provider" || object?["id"]?.stringValue != nil {
            warnings.append(AIWarning(
                type: "unsupported",
                feature: "provider-defined tool \(object?["id"]?.stringValue ?? name)"
            ))
            return nil
        }
        // Upstream sends only `tool.inputSchema` as `parameters`.
        var function: [String: JSONValue] = [
            "name": .string(name),
            "parameters": aiFunctionToolInputSchema(schema)
        ]
        if let description = aiFunctionToolDescription(schema) {
            function["description"] = .string(description)
        }
        if let strict = object?["strict"], strict != .null {
            function["strict"] = strict
        }
        return .object([
            "type": .string("function"),
            "function": .object(function)
        ])
    }
    return AlibabaPreparedTools(tools: values, warnings: warnings)
}

/// Mirrors upstream `prepareTools`: known choices map to the wire format and
/// unrecognized types throw an unsupported-functionality error.
func alibabaToolChoice(from value: JSONValue?) throws -> JSONValue? {
    guard let value, value != .null else { return nil }
    if let string = value.stringValue {
        switch string {
        case "auto", "none", "required":
            return .string(string)
        default:
            throw alibabaUnsupportedToolChoice(string)
        }
    }
    guard let object = value.objectValue else {
        throw alibabaUnsupportedToolChoice("undefined")
    }
    switch object["type"]?.stringValue {
    case let type? where ["auto", "none", "required"].contains(type):
        return .string(type)
    case "tool":
        guard let toolName = object["toolName"]?.stringValue ?? object["tool_name"]?.stringValue else {
            throw AIError.invalidArgument(argument: "toolChoice.toolName", message: "Tool choice of type 'tool' requires a toolName.")
        }
        return .object([
            "type": .string("function"),
            "function": .object(["name": .string(toolName)])
        ])
    case let type:
        throw alibabaUnsupportedToolChoice(type ?? "undefined")
    }
}

private func alibabaUnsupportedToolChoice(_ type: String) -> AIError {
    AIError.invalidArgument(argument: "toolChoice", message: "'tool choice type: \(type)' functionality not supported.")
}

func alibabaAssistantToolCallJSON(_ part: AIContentPart) -> JSONValue? {
    guard case let .toolCall(call) = part else { return nil }
    return .object([
        "id": .string(call.id),
        "type": .string("function"),
        "function": .object([
            "name": .string(call.name),
            "arguments": .string(call.arguments)
        ])
    ])
}

func alibabaToolResultContent(_ result: AIToolResult) -> String {
    let output = result.modelOutput ?? result.result
    switch output["type"]?.stringValue {
    case "text", "error-text":
        return output["value"]?.stringValue ?? ""
    case "execution-denied":
        return output["reason"]?.stringValue ?? "Tool call execution denied."
    case "content", "json", "error-json":
        if let value = output["value"] {
            return alibabaJSONString(value) ?? value.stringValue ?? ""
        }
        return alibabaJSONString(output) ?? output.stringValue ?? ""
    default:
        return alibabaJSONString(output) ?? output.stringValue ?? ""
    }
}