import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities


func mistralMessagesJSON(_ messages: [AIMessage]) throws -> [JSONValue] {
    try messages.enumerated().flatMap { index, message in
        try mistralMessageJSONs(message, isLastMessage: index == messages.count - 1)
    }
}

func mistralMessageJSONs(_ message: AIMessage, isLastMessage: Bool) throws -> [JSONValue] {
    switch message.role {
    case .system:
        return [.object(["role": .string("system"), "content": .string(message.combinedText)])]
    case .assistant:
        let hasReasoning = message.content.contains { part in
            if case .reasoning = part { return true }
            return false
        } || message.reasoning != nil
        var output: [String: JSONValue] = [
            "role": .string("assistant"),
            "content": hasReasoning
                ? .array(mistralAssistantContent(from: message))
                : .string(mistralAssistantText(from: message))
        ]
        if isLastMessage {
            output["prefix"] = true
        }
        let toolCalls = message.content.compactMap(mistralAssistantToolCallJSON)
        if !toolCalls.isEmpty {
            output["tool_calls"] = .array(toolCalls)
        }
        return [.object(output)]
    case .tool:
        // Upstream maps tool results only; approval responses produce no message.
        return message.content.compactMap(mistralToolMessageJSON)
    case .user:
        return [.object([
            "role": .string("user"),
            "content": .array(try message.content.map(mistralContentPartJSON))
        ])]
    }
}

func mistralAssistantText(from message: AIMessage) -> String {
    message.content.compactMap(\.text).joined()
}

func mistralAssistantContent(from message: AIMessage) -> [JSONValue] {
    var content: [JSONValue] = message.content.compactMap { part in
        switch part {
        case let .text(text, _):
            return .object(["type": .string("text"), "text": .string(text)])
        case let .reasoning(text, _):
            return .object([
                "type": .string("thinking"),
                "thinking": .array([.object(["type": .string("text"), "text": .string(text)])]),
                "closed": true
            ])
        default:
            return nil
        }
    }
    if let reasoning = message.reasoning, !reasoning.isEmpty {
        content.append(.object([
            "type": .string("thinking"),
            "thinking": .array([.object(["type": .string("text"), "text": .string(reasoning)])]),
            "closed": true
        ]))
    }
    return content
}

func mistralAssistantToolCallJSON(_ part: AIContentPart) -> JSONValue? {
    guard case let .toolCall(call) = part else { return nil }
    return .object([
        "id": .string(call.id),
        "type": .string("function"),
        "function": .object([
            "name": .string(call.name),
            "arguments": .string(mistralSerializeToolArguments(call.arguments))
        ])
    ])
}

func mistralToolMessageJSON(_ part: AIContentPart) -> JSONValue? {
    guard case let .toolResult(result) = part else { return nil }
    return .object([
        "role": .string("tool"),
        "name": .string(result.toolName),
        "tool_call_id": .string(result.toolCallID),
        "content": .string(mistralToolResultContent(result))
    ])
}

func mistralToolResultContent(_ result: AIToolResult) -> String {
    let output = result.modelOutput ?? result.result
    // A plain string tool output becomes a `text` model output upstream.
    if let text = output.stringValue {
        return text
    }
    switch output["type"]?.stringValue {
    case "text", "error-text":
        return output["value"]?.stringValue ?? ""
    case "execution-denied":
        return output["reason"]?.stringValue ?? "Tool call execution denied."
    case "content", "json", "error-json":
        if let value = output["value"] {
            return mistralJSONString(value) ?? value.stringValue ?? ""
        }
        return mistralJSONString(output) ?? output.stringValue ?? ""
    default:
        return mistralJSONString(output) ?? output.stringValue ?? ""
    }
}

func mistralJSONString(_ value: JSONValue) -> String? {
    // JSON.stringify does not escape forward slashes.
    try? decisionJSONText(value)
}

func mistralContentPartJSON(_ part: AIContentPart) throws -> JSONValue {
    switch part {
    case let .text(text, _):
        return .object(["type": .string("text"), "text": .string(text)])
    case let .reasoning(text, _):
        return .object(["type": .string("text"), "text": .string(text)])
    case let .imageURL(url, _):
        return .object(["type": .string("image_url"), "image_url": .string(url)])
    case let .data(mimeType, data, _), let .file(mimeType, data, _, _):
        // Upstream resolves partial media types (`image`, `image/*`, `application`) from the bytes
        // and accepts images plus documents whose resolved type is application/pdf.
        if topLevelMediaType(mimeType) == "image" {
            let mediaType = try resolveFullMediaType(mediaType: mimeType, data: data)
            return .object(["type": .string("image_url"), "image_url": .string("data:\(mediaType);base64,\(data.base64EncodedString())")])
        }
        let mediaType = try resolveFullMediaType(mediaType: mimeType, data: data)
        guard mediaType == "application/pdf" else {
            throw AIError.invalidArgument(argument: "files", message: "Mistral chat API only supports image and PDF file parts; got \(mimeType).")
        }
        return .object(["type": .string("document_url"), "document_url": .string("data:\(mediaType);base64,\(data.base64EncodedString())")])
    case let .providerReference(mimeType, reference, _, _) where mimeType == "application/pdf":
        let url = try resolveProviderReference(reference: reference, provider: "mistral")
        guard URLComponents(string: url)?.scheme?.lowercased() == "https" else {
            throw AIError.invalidArgument(argument: "files", message: "Mistral PDF references must use an HTTPS URL.")
        }
        return .object(["type": "document_url", "document_url": .string(url)])
    case .providerReference:
        throw AIError.invalidArgument(argument: "files", message: "Mistral chat API only supports image URL, inline image file, and PDF file parts.")
    case .reasoningFile, .custom, .toolCall, .toolResult, .toolApprovalRequest, .toolApprovalResponse:
        throw AIError.invalidArgument(argument: "messages", message: "Mistral user messages only support text, image file, and PDF file parts.")
    }
}

func mistralText(from content: JSONValue?) -> String? {
    if let string = content?.stringValue { return string }
    let parts = content?.arrayValue?.compactMap { part -> String? in
        guard part["type"]?.stringValue == "text" else { return nil }
        return part["text"]?.stringValue
    } ?? []
    return parts.isEmpty ? nil : parts.joined()
}

func mistralReasoning(from content: JSONValue?) -> String? {
    content?.arrayValue?.compactMap { part -> String? in
        guard part["type"]?.stringValue == "thinking" else { return nil }
        return part["thinking"]?.arrayValue?.compactMap { $0["text"]?.stringValue }.joined()
    }.joined()
}

func mistralToolCalls(from value: JSONValue?) -> [AIToolCall] {
    value?.arrayValue?.enumerated().compactMap { index, item in
        guard let name = item["function"]?["name"]?.stringValue else { return nil }
        return AIToolCall(
            id: item["id"]?.stringValue ?? "tool-call-\(index)",
            name: name,
            arguments: item["function"]?["arguments"]?.stringValue ?? "",
            rawValue: item
        )
    } ?? []
}

func mapMistralFinishReason(_ reason: String?) -> String? {
    switch reason {
    case "stop":
        return "stop"
    case "length", "model_length":
        return "length"
    case "tool_calls":
        return "tool-calls"
    case "error":
        return "error"
    default:
        return "other"
    }
}

func mistralUsage(from raw: JSONValue) -> TokenUsage? {
    guard let usage = raw["usage"], usage != .null else { return nil }
    let inputTokens = usage["prompt_tokens"]?.intValue
    let outputTokens = usage["completion_tokens"]?.intValue
    let cacheReadTokens = usage["num_cached_tokens"]?.intValue
        ?? usage["prompt_tokens_details"]?["cached_tokens"]?.intValue
        ?? usage["prompt_token_details"]?["cached_tokens"]?.intValue
    return TokenUsage(
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        totalTokens: usage["total_tokens"]?.intValue,
        inputTokensNoCache: inputTokens.map { $0 - (cacheReadTokens ?? 0) },
        inputTokensCacheRead: cacheReadTokens.flatMap { $0 == 0 ? nil : $0 },
        outputTextTokens: outputTokens,
        rawValue: usage
    )
}

func mistralResponseMetadata(from raw: JSONValue? = nil, response: AIHTTPResponse, modelID: String) -> AIResponseMetadata {
    AIResponseMetadata(
        id: raw?["id"]?.stringValue,
        timestamp: raw?["created"]?.doubleValue.map { Date(timeIntervalSince1970: $0) } ?? Date(),
        modelID: raw?["model"]?.stringValue ?? modelID,
        headers: response.headers,
        body: raw
    )
}
/// Tool arguments are already serialized in Swift. Preserve valid JSON verbatim.
func mistralSerializeToolArguments(_ value: String) -> String {
    if (try? decodeJSONBody(Data(value.utf8))) != nil { return value }
    return mistralJSONString(.string(value))!
}
