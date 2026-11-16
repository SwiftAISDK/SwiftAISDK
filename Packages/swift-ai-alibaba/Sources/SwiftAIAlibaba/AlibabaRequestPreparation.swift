import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities


struct AlibabaPreparedCall {
    var body: [String: JSONValue]
    var warnings: [AIWarning]
}

struct AlibabaPreparedMessages {
    var messages: [JSONValue]
    var warnings: [AIWarning]
}

struct AlibabaPreparedTools {
    var tools: [JSONValue]
    var warnings: [AIWarning]
}

func alibabaPreparedCall(
    for request: LanguageModelRequest,
    modelID: String,
    stream: Bool,
    includeUsage: Bool = true,
    transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
) throws -> AlibabaPreparedCall {
    // Warning order mirrors upstream getArgs: frequencyPenalty, response format,
    // reasoning, cache breakpoints (and Swift-only prompt part warnings), tools.
    var warnings = alibabaWarnings(for: request)
    var options = try alibabaOptions(from: request)
    let resolvedResponseFormat = alibabaResolvedResponseFormat(
        request: request,
        modelID: modelID,
        options: &options
    )
    if let warning = resolvedResponseFormat.warning {
        warnings.append(warning)
    }
    let toolChoiceInput = request.toolChoice ?? options.removeValue(forKey: "toolChoice")
    let explicitPreserveThinking = options.removeValue(forKey: "preserve_thinking")?.boolValue
    let preserveThinking = explicitPreserveThinking ?? alibabaSupportsPreservedThinking(modelID)
    let messages = resolvedResponseFormat.injectJSONInstruction
        ? injectJSONInstruction(
            into: request.messages,
            schema: resolvedResponseFormat.schema,
            instruction: AIJSONInstruction()
        )
        : request.messages
    var body: [String: JSONValue] = [
        "model": .string(modelID)
    ]
    if let temperature = request.temperature { body["temperature"] = .number(temperature) }
    if let topP = request.topP { body["top_p"] = .number(topP) }
    if let topK = request.topK { body["top_k"] = .number(Double(topK)) }
    if let presencePenalty = request.presencePenalty { body["presence_penalty"] = .number(presencePenalty) }
    if let seed = request.seed { body["seed"] = .number(Double(seed)) }
    if let maxOutputTokens = request.maxOutputTokens { body["max_tokens"] = .number(Double(maxOutputTokens)) }
    if !request.stopSequences.isEmpty { body["stop"] = .array(request.stopSequences) }
    if let responseFormat = resolvedResponseFormat.value {
        body["response_format"] = responseFormat
    }
    alibabaApplyThinking(request: request, options: &options, body: &body, warnings: &warnings)
    if explicitPreserveThinking != nil || alibabaSupportsPreservedThinking(modelID) {
        body["preserve_thinking"] = .bool(preserveThinking)
    }
    let preparedMessages = try alibabaMessages(messages, preserveThinking: preserveThinking)
    body["messages"] = .array(preparedMessages.messages)
    let preparedTools = alibabaTools(from: request.tools)
    // Upstream keeps `tools: []` (plus tool choice) when every tool is provider-defined.
    if !request.tools.isEmpty {
        body["tools"] = .array(preparedTools.tools)
        if let toolChoice = try alibabaToolChoice(from: toolChoiceInput) {
            body["tool_choice"] = toolChoice
        }
        if let parallelToolCalls = options.removeValue(forKey: "parallel_tool_calls") {
            body["parallel_tool_calls"] = parallelToolCalls
        }
    } else {
        options.removeValue(forKey: "parallel_tool_calls")
    }
    warnings += preparedMessages.warnings
    warnings += preparedTools.warnings
    body.merge(options) { _, new in new }
    if stream {
        body["stream"] = true
        if body["stream_options"] == nil, includeUsage {
            body["stream_options"] = .object(["include_usage": true])
        }
    }
    return AlibabaPreparedCall(body: transformRequestBody?(body) ?? body, warnings: warnings)
}

/// Mirrors upstream `CacheControlValidator`: reads `cacheControl` (or
/// `cache_control`) from Alibaba provider options and warns once per marker
/// beyond Alibaba's four-breakpoint limit.
struct AlibabaCacheControlValidator {
    static let maxCacheBreakpoints = 4
    private var breakpointCount = 0
    private(set) var warnings: [AIWarning] = []

    mutating func cacheControl(from providerMetadata: [String: JSONValue]) -> JSONValue? {
        let alibaba = providerMetadata["alibaba"]
        guard let value = alibaba?["cacheControl"] ?? alibaba?["cache_control"], value != .null else {
            return nil
        }
        breakpointCount += 1
        if breakpointCount > Self.maxCacheBreakpoints {
            warnings.append(AIWarning(
                type: "other",
                message: "Max breakpoint limit exceeded. Only the last \(Self.maxCacheBreakpoints) cache markers will take effect."
            ))
        }
        return value
    }
}

func alibabaMessages(_ messages: [AIMessage], preserveThinking: Bool = false) throws -> AlibabaPreparedMessages {
    var validator = AlibabaCacheControlValidator()
    var output: [JSONValue] = []
    var warnings: [AIWarning] = []
    let lastUserMessageIndex = messages.lastIndex { $0.role == .user } ?? -1
    for (index, message) in messages.enumerated() {
        let prepared = try alibabaMessageJSONs(
            message,
            includeReasoning: preserveThinking || index > lastUserMessageIndex,
            cacheControlValidator: &validator
        )
        output += prepared.messages
        warnings += prepared.warnings
    }
    return AlibabaPreparedMessages(messages: output, warnings: validator.warnings + warnings)
}

private func alibabaSupportsPreservedThinking(_ modelID: String) -> Bool {
    let models: Set<String> = [
        "kimi-k2.7-code",
        "qwen3.6-max-preview",
        "qwen3.6-plus",
        "qwen3.6-plus-2026-04-02",
        "qwen3.7-flash",
        "qwen3.7-flash-2026-07-15",
        "qwen3.7-max",
        "qwen3.7-max-2026-05-17",
        "qwen3.7-max-2026-05-20",
        "qwen3.7-max-2026-06-08",
        "qwen3.7-max-preview",
        "qwen3.7-plus",
        "qwen3.7-plus-2026-05-26",
        "qwen3.8-flash",
        "qwen3.8-max",
        "qwen3.8-max-0902"
    ]
    return models.contains(modelID)
}

struct AlibabaPreparedMessageParts {
    var parts: [JSONValue]
    var warnings: [AIWarning]
}

func alibabaUnsupportedFunctionality(_ functionality: String) -> AIError {
    AIError.invalidArgument(argument: "messages", message: "'\(functionality)' functionality not supported.")
}

private func alibabaTextBlock(_ text: String, cacheControl: JSONValue) -> JSONValue {
    .object(["type": .string("text"), "text": .string(text), "cache_control": cacheControl])
}

func alibabaMessageJSONs(
    _ message: AIMessage,
    includeReasoning: Bool = false,
    cacheControlValidator: inout AlibabaCacheControlValidator
) throws -> AlibabaPreparedMessages {
    let messageCacheControl = cacheControlValidator.cacheControl(from: message.providerMetadata)
    switch message.role {
    case .system:
        let text = message.combinedText
        if let messageCacheControl {
            return AlibabaPreparedMessages(messages: [.object([
                "role": .string("system"),
                "content": .array([alibabaTextBlock(text, cacheControl: messageCacheControl)])
            ])], warnings: [])
        }
        return AlibabaPreparedMessages(messages: [.object([
            "role": .string("system"),
            "content": .string(text)
        ])], warnings: [])
    case .user:
        let content = try alibabaUserContentParts(
            message.content,
            messageCacheControl: messageCacheControl,
            cacheControlValidator: &cacheControlValidator
        )
        return AlibabaPreparedMessages(messages: [.object([
            "role": .string("user"),
            "content": .array(content.parts)
        ])], warnings: content.warnings)
    case .assistant:
        let toolCalls = message.content.compactMap(alibabaAssistantToolCallJSON)
        let text = message.content.compactMap(\.text).joined()
        // `AIMessage.reasoning` is the Swift-native carrier for reasoning text; it
        // precedes reasoning content parts.
        let reasoning = includeReasoning
            ? (message.reasoning ?? "") + message.content.compactMap { part -> String? in
                if case let .reasoning(value, _) = part { return value }
                return nil
            }.joined()
            : ""
        guard !text.isEmpty || !toolCalls.isEmpty || !reasoning.isEmpty else {
            return AlibabaPreparedMessages(messages: [], warnings: [])
        }
        let content: JSONValue
        if text.isEmpty, toolCalls.isEmpty {
            content = .null
        } else if let messageCacheControl {
            content = .array([alibabaTextBlock(text, cacheControl: messageCacheControl)])
        } else {
            content = text.isEmpty ? .null : .string(text)
        }
        var output: [String: JSONValue] = [
            "role": .string("assistant"),
            "content": content
        ]
        if !reasoning.isEmpty {
            output["reasoning_content"] = .string(reasoning)
        }
        if !toolCalls.isEmpty {
            output["tool_calls"] = .array(toolCalls)
        }
        return AlibabaPreparedMessages(messages: [.object(output)], warnings: [])
    case .tool:
        let results = message.content.compactMap { part -> AIToolResult? in
            if case let .toolResult(result) = part { return result }
            return nil
        }
        var output: [JSONValue] = []
        for (index, result) in results.enumerated() {
            let isLastPart = index == results.count - 1
            let partCacheControl = cacheControlValidator.cacheControl(from: result.providerMetadata)
                ?? (isLastPart ? messageCacheControl : nil)
            let contentValue = alibabaToolResultContent(result)
            output.append(.object([
                "role": .string("tool"),
                "tool_call_id": .string(result.toolCallID),
                "content": partCacheControl.map { .array([alibabaTextBlock(contentValue, cacheControl: $0)]) }
                    ?? .string(contentValue)
            ]))
        }
        return AlibabaPreparedMessages(messages: output, warnings: [])
    }
}

func alibabaUserContentParts(
    _ content: [AIContentPart],
    messageCacheControl: JSONValue? = nil,
    cacheControlValidator: inout AlibabaCacheControlValidator
) throws -> AlibabaPreparedMessageParts {
    var warnings: [AIWarning] = []
    var parts: [JSONValue] = []
    for (index, part) in content.enumerated() {
        let isLastPart = index == content.count - 1
        let partCacheControl = cacheControlValidator.cacheControl(from: part.providerMetadata)
            ?? (isLastPart ? messageCacheControl : nil)
        var object: [String: JSONValue]
        switch part {
        case let .text(text, _):
            object = ["type": .string("text"), "text": .string(text)]
        case let .imageURL(url, _):
            object = ["type": .string("image_url"), "image_url": .object(["url": .string(url)])]
        case let .data(mimeType, data, _), let .file(mimeType, data, _, _):
            guard topLevelMediaType(mimeType) == "image" else {
                throw alibabaUnsupportedFunctionality("Only image file parts are supported")
            }
            let mediaType = try resolveFullMediaType(mediaType: mimeType, data: data)
            object = [
                "type": .string("image_url"),
                "image_url": .object(["url": .string("data:\(mediaType);base64,\(data.base64EncodedString())")])
            ]
        case .providerReference:
            throw alibabaUnsupportedFunctionality("file parts with provider references")
        case .reasoning, .reasoningFile, .custom, .toolCall, .toolResult, .toolApprovalRequest, .toolApprovalResponse:
            // Not representable in upstream user messages; Swift-only parts are skipped with a warning.
            warnings.append(AIWarning(type: "unsupported", feature: alibabaUserPartFeature(part)))
            continue
        }
        if let partCacheControl {
            object["cache_control"] = partCacheControl
        }
        parts.append(.object(object))
    }
    return AlibabaPreparedMessageParts(parts: parts, warnings: warnings)
}

func alibabaUserPartFeature(_ part: AIContentPart) -> String {
    switch part {
    case .data, .file, .providerReference:
        return "user message part type: file"
    case .toolCall:
        return "user message part type: tool-call"
    case .toolResult:
        return "user message part type: tool-result"
    case .toolApprovalRequest:
        return "user message part type: tool-approval-request"
    case .toolApprovalResponse:
        return "user message part type: tool-approval-response"
    case .reasoning:
        return "user message part type: reasoning"
    case .reasoningFile:
        return "user message part type: reasoning-file"
    case .custom:
        return "user message part type: custom"
    case .imageURL:
        return "user message part type: image"
    case .text:
        return "user message part type: text"
    }
}
