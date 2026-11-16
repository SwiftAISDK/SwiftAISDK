import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities


public final class HuggingFaceResponsesLanguageModel: LanguageModel, @unchecked Sendable {
    public let providerID = "huggingface.responses"
    public let modelID: String
    private let config: HuggingFaceHTTPConfiguration

    public init(modelID: String, http: AIProviderHTTPClient) {
        self.modelID = modelID
        self.config = HuggingFaceHTTPConfiguration(http: http)
    }

    public func generate(_ request: LanguageModelRequest) async throws -> TextGenerationResult {
        let prepared = try huggingFacePreparedCall(for: request, modelID: modelID, stream: false)
        let body = JSONValue.object(prepared.body)
        let httpRequest = try config.request(
            path: "/responses",
            modelID: modelID,
            body: body,
            headers: request.headers,
            abortSignal: request.abortSignal
        )
        let response = try await config.transport.send(httpRequest)
        guard (200..<300).contains(response.statusCode) else { throw config.httpStatusError(response) }
        let raw = try response.jsonValue()
        // Upstream turns a 2xx body carrying `error` into a non-retryable 400 APICallError.
        if let error = raw["error"], error != .null {
            var apiError = AIAPICallError(
                provider: providerID,
                url: httpRequest.url.absoluteString,
                requestBody: body,
                statusCode: 400,
                responseHeaders: response.headers,
                responseBody: response.bodyText,
                isRetryable: false
            )
            apiError.message = error["message"]?.stringValue
            throw AIError.apiCall(apiError)
        }

        let parsed = huggingFaceResponseContent(from: raw)
        return TextGenerationResult(
            text: parsed.text,
            content: parsed.content,
            reasoning: parsed.reasoning,
            finishReason: huggingFaceFinishReason(raw["incomplete_details"]?["reason"]?.stringValue ?? "stop"),
            usage: huggingFaceUsage(from: raw["usage"]),
            providerMetadata: ["huggingface": .object(["responseId": raw["id"] ?? .null])],
            rawValue: raw,
            warnings: prepared.warnings,
            requestMetadata: aiRequestMetadata(body: body, headers: request.headers),
            responseMetadata: huggingFaceResponseMetadata(from: raw, response: response, modelID: modelID)
        )
    }

    public func stream(_ request: LanguageModelRequest) -> AsyncThrowingStream<LanguageStreamPart, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let prepared = try huggingFacePreparedCall(for: request, modelID: modelID, stream: true)
                    let httpRequest = try config.request(
                        path: "/responses",
                        modelID: modelID,
                        body: .object(prepared.body),
                        headers: request.headers,
                        abortSignal: request.abortSignal
                    )
                    let response = try await config.streamRequest(httpRequest)
                    guard (200..<300).contains(response.statusCode) else {
                        throw apiCallError(provider: providerID, response: try await bufferedHTTPResponse(from: response, request: httpRequest))
                    }
                    let responseHead = httpResponseHead(from: response, request: httpRequest)

                    // Upstream always opens with stream-start and reports response
                    // metadata only for `response.created`; raw chunks are not emitted.
                    continuation.yield(.streamStart(warnings: prepared.warnings))
                    continuation.yield(.requestMetadata(aiRequestMetadata(body: .object(prepared.body), headers: request.headers)))

                    var activeTextIDs: [String] = []
                    var activeReasoningIDs: [String] = []
                    // A clean end without the provider's completion signal is interrupted.
                    var finishReason: String? = "interrupted"
                    var finishUsage: TokenUsage?
                    var responseID: JSONValue = .null
                    for try await event in serverSentEvents(from: response.body) {
                        if event.data == "[DONE]" { break }
                        let raw: JSONValue
                        do { raw = try decodeJSONBody(Data(event.data.utf8)) }
                        catch {
                            finishReason = "error"
                            continuation.yield(.error(message: error.localizedDescription))
                            continue
                        }

                        if let providerError = huggingFaceStreamProviderError(from: raw) {
                            finishReason = "error"
                            continuation.yield(.providerError(providerError))
                            continue
                        }

                        switch raw["type"]?.stringValue {
                        case "response.created":
                            let created = raw["response"] ?? .null
                            responseID = created["id"] ?? .null
                            continuation.yield(.responseMetadata(huggingFaceResponseMetadata(from: created, response: responseHead, modelID: modelID)))
                        case "response.output_item.added":
                            let item = raw["item"]
                            switch item?["type"]?.stringValue {
                            case "message" where item?["role"]?.stringValue == "assistant":
                                let id = item?["id"]?.stringValue ?? "message"
                                if !activeTextIDs.contains(id) { activeTextIDs.append(id) }
                                continuation.yield(.textStart(id: id, providerMetadata: huggingFaceItemMetadata(id: id)))
                            case "function_call":
                                if let name = item?["name"]?.stringValue {
                                    continuation.yield(.toolInputStart(id: item?["call_id"]?.stringValue ?? item?["id"]?.stringValue ?? "function-call", name: name))
                                }
                            case "reasoning":
                                let id = item?["id"]?.stringValue ?? "reasoning"
                                if !activeReasoningIDs.contains(id) { activeReasoningIDs.append(id) }
                                continuation.yield(.reasoningStart(id: id, providerMetadata: huggingFaceItemMetadata(id: id)))
                            default:
                                break
                            }
                        case "response.output_item.done":
                            let item = raw["item"]
                            switch item?["type"]?.stringValue {
                            case "message" where item?["role"]?.stringValue == "assistant":
                                let id = item?["id"]?.stringValue ?? "message"
                                activeTextIDs.removeAll { $0 == id }
                                continuation.yield(.textEnd(id: id))
                            case "function_call":
                                let id = item?["call_id"]?.stringValue ?? item?["id"]?.stringValue ?? "function-call"
                                continuation.yield(.toolInputEnd(id: id))
                                if let toolCall = huggingFaceToolCall(from: item) {
                                    continuation.yield(.toolCall(toolCall))
                                }
                                if let toolResult = huggingFaceToolResult(from: item) {
                                    continuation.yield(.toolResult(toolResult))
                                }
                            default:
                                break
                            }
                        case "response.completed":
                            let completed = raw["response"] ?? .null
                            responseID = completed["id"] ?? .null
                            finishReason = huggingFaceFinishReason(completed["incomplete_details"]?["reason"]?.stringValue ?? "stop")
                            if let usage = huggingFaceUsage(from: completed["usage"]) {
                                finishUsage = usage
                            }
                        case "response.reasoning_text.delta":
                            let id = raw["item_id"]?.stringValue ?? "reasoning"
                            if !activeReasoningIDs.contains(id) {
                                // Swift stream consumers require a start before a delta.
                                activeReasoningIDs.append(id)
                                continuation.yield(.reasoningStart(id: id, providerMetadata: huggingFaceItemMetadata(id: id)))
                            }
                            continuation.yield(.reasoningDeltaPart(id: id, delta: raw["delta"]?.stringValue ?? ""))
                        case "response.reasoning_text.done":
                            let id = raw["item_id"]?.stringValue ?? "reasoning"
                            activeReasoningIDs.removeAll { $0 == id }
                            continuation.yield(.reasoningEnd(id: id))
                        case "response.output_text.delta":
                            let id = raw["item_id"]?.stringValue ?? "text"
                            if !activeTextIDs.contains(id) {
                                // Swift stream consumers require a start before a delta.
                                activeTextIDs.append(id)
                                continuation.yield(.textStart(id: id, providerMetadata: huggingFaceItemMetadata(id: id)))
                            }
                            continuation.yield(.textDeltaPart(id: id, delta: raw["delta"]?.stringValue ?? ""))
                        default:
                            break
                        }
                    }
                    for id in activeTextIDs {
                        continuation.yield(.textEnd(id: id))
                    }
                    for id in activeReasoningIDs {
                        continuation.yield(.reasoningEnd(id: id))
                    }
                    continuation.yield(.finishMetadata(
                        reason: finishReason,
                        usage: finishUsage,
                        providerMetadata: ["huggingface": .object(["responseId": responseID])]
                    ))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }
}

private struct HuggingFacePreparedCall {
    var body: [String: JSONValue]
    var warnings: [AIWarning]
}

private func huggingFacePreparedCall(for request: LanguageModelRequest, modelID: String, stream: Bool) throws -> HuggingFacePreparedCall {
    var options = try huggingFaceProviderOptions(from: request)
    let responseFormat = huggingFaceResolvedResponseFormat(request: request, options: &options)
    var body: [String: JSONValue] = [
        "model": .string(modelID),
        "input": .array(try request.messages.flatMap(huggingFaceInputMessages)),
        // Upstream sends an explicit `stream` flag for both generate and stream calls.
        "stream": .bool(stream)
    ]
    if let temperature = request.temperature { body["temperature"] = .number(temperature) }
    if let topP = request.topP { body["top_p"] = .number(topP) }
    if let maxOutputTokens = request.maxOutputTokens { body["max_output_tokens"] = .number(Double(maxOutputTokens)) }
    if let textFormat = huggingFaceTextFormat(from: responseFormat, strictJsonSchema: options["strictJsonSchema"]) {
        body["text"] = .object(["format": textFormat])
    }
    if let metadata = options["metadata"] { body["metadata"] = metadata }
    if let instructions = options["instructions"] { body["instructions"] = instructions }
    if let reasoningEffort = options["reasoningEffort"] ?? options["reasoning_effort"] {
        body["reasoning"] = .object(["effort": reasoningEffort])
    }
    let preparedTools = huggingFaceTools(from: request.tools)
    // Upstream keeps `tools` (even when every tool was provider-defined) and maps
    // tool choice whenever the call declared tools.
    if !request.tools.isEmpty {
        body["tools"] = .array(preparedTools.tools)
        if let toolChoice = huggingFaceToolChoice(from: request.toolChoice ?? options["toolChoice"] ?? options["tool_choice"]) {
            body["tool_choice"] = toolChoice
        }
    }
    for (key, value) in options where !["metadata", "instructions", "reasoningEffort", "reasoning_effort", "toolChoice", "tool_choice", "responseFormat", "strictJsonSchema"].contains(key) {
        body[key] = value
    }
    return HuggingFacePreparedCall(body: body, warnings: huggingFaceWarnings(for: request) + preparedTools.warnings)
}

private func huggingFaceProviderOptions(from request: LanguageModelRequest) throws -> [String: JSONValue] {
    var output = request.extraBody
    if let nested = output.removeValue(forKey: "huggingface")?.objectValue {
        output.merge(nested) { _, nested in nested }
    }
    if let value = request.providerOptions["huggingface"] {
        guard value != .null else { return output }
        guard let nested = value.objectValue else {
            throw AIError.invalidArgument(argument: "providerOptions.huggingface", message: "Hugging Face provider options must be an object.")
        }
        for key in huggingFaceResponsesProviderOptionKeys {
            output.removeValue(forKey: key)
        }
        output.merge(try huggingFaceValidateResponsesProviderOptions(nested)) { _, providerValue in providerValue }
    }
    return output
}

private let huggingFaceResponsesProviderOptionKeys: Set<String> = [
    "metadata",
    "instructions",
    "strictJsonSchema",
    "reasoningEffort"
]

private func huggingFaceValidateResponsesProviderOptions(_ options: [String: JSONValue]) throws -> [String: JSONValue] {
    var output: [String: JSONValue] = [:]
    for (key, value) in options where huggingFaceResponsesProviderOptionKeys.contains(key) {
        guard value != .null else {
            throw AIError.invalidArgument(argument: "providerOptions.huggingface.\(key)", message: "Hugging Face \(key) cannot be null.")
        }
        switch key {
        case "metadata":
            guard let metadata = value.objectValue else {
                throw AIError.invalidArgument(argument: "providerOptions.huggingface.metadata", message: "Hugging Face metadata must be a string record.")
            }
            for metadataKey in metadata.keys.sorted() where metadata[metadataKey]?.stringValue == nil {
                throw AIError.invalidArgument(argument: "providerOptions.huggingface.metadata.\(metadataKey)", message: "Hugging Face metadata values must be strings.")
            }
            output[key] = value
        case "instructions", "reasoningEffort":
            guard value.stringValue != nil else {
                throw AIError.invalidArgument(argument: "providerOptions.huggingface.\(key)", message: "Hugging Face \(key) must be a string.")
            }
            output[key] = value
        case "strictJsonSchema":
            guard value.boolValue != nil else {
                throw AIError.invalidArgument(argument: "providerOptions.huggingface.strictJsonSchema", message: "Hugging Face strictJsonSchema must be a boolean.")
            }
            output[key] = value
        default:
            break
        }
    }
    return output
}

private func huggingFaceResolvedResponseFormat(request: LanguageModelRequest, options: inout [String: JSONValue]) -> JSONValue? {
    if let responseFormat = request.responseFormat {
        options.removeValue(forKey: "responseFormat")
        return huggingFaceResponseFormatJSON(responseFormat)
    }
    return options.removeValue(forKey: "responseFormat")
}

private func huggingFaceResponseFormatJSON(_ responseFormat: AIResponseFormat) -> JSONValue? {
    switch responseFormat {
    case .text:
        return nil
    case let .json(schema, name, description):
        return .object([
            "type": .string("json"),
            "schema": schema,
            "name": name.map(JSONValue.string),
            "description": description.map(JSONValue.string)
        ])
    }
}

private func huggingFaceTextFormat(from responseFormat: JSONValue?, strictJsonSchema: JSONValue?) -> JSONValue? {
    guard responseFormat?["type"]?.stringValue == "json",
          let schema = responseFormat?["schema"] else {
        return nil
    }
    var format: [String: JSONValue] = [
        "type": .string("json_schema"),
        "strict": strictJsonSchema ?? .bool(false),
        "name": responseFormat?["name"] ?? .string("response"),
        "schema": schema
    ]
    if let description = responseFormat?["description"] {
        format["description"] = description
    }
    return .object(format)
}

private func huggingFaceWarnings(for request: LanguageModelRequest) -> [AIWarning] {
    var warnings: [AIWarning] = []
    if request.topK != nil {
        warnings.append(AIWarning(type: "unsupported", feature: "topK"))
    }
    if request.seed != nil {
        warnings.append(AIWarning(type: "unsupported", feature: "seed"))
    }
    if request.presencePenalty != nil {
        warnings.append(AIWarning(type: "unsupported", feature: "presencePenalty"))
    }
    if request.frequencyPenalty != nil {
        warnings.append(AIWarning(type: "unsupported", feature: "frequencyPenalty"))
    }
    if !request.stopSequences.isEmpty {
        warnings.append(AIWarning(type: "unsupported", feature: "stopSequences"))
    }
    // Upstream warns once per tool message.
    for message in request.messages where message.role == .tool {
        warnings.append(AIWarning(type: "unsupported", feature: "tool messages"))
    }
    return warnings
}

private func huggingFaceInputMessages(_ message: AIMessage) throws -> [JSONValue] {
    switch message.role {
    case .system:
        return [.object(["role": .string("system"), "content": .string(message.combinedText)])]
    case .user:
        return [.object([
            "role": .string("user"),
            "content": .array(try message.content.compactMap(huggingFaceInputContentPart))
        ])]
    case .assistant:
        // Upstream sends one assistant message per text or reasoning part and skips
        // tool calls, tool results and files.
        return message.content.compactMap { part -> JSONValue? in
            switch part {
            case let .text(text, _), let .reasoning(text, _):
                return .object([
                    "role": .string("assistant"),
                    "content": .array([.object(["type": .string("output_text"), "text": .string(text)])])
                ])
            default:
                return nil
            }
        }
    case .tool:
        return []
    }
}

private func huggingFaceInputContentPart(_ part: AIContentPart) throws -> JSONValue? {
    switch part {
    case let .text(text, _):
        return .object(["type": .string("input_text"), "text": .string(text)])
    case let .reasoning(text, _):
        return .object(["type": .string("input_text"), "text": .string(text)])
    case let .imageURL(url, _):
        return .object(["type": .string("input_image"), "image_url": .string(url)])
    case let .data(mimeType, data, _), let .file(mimeType, data, _, _):
        guard let mediaType = huggingFaceResolvedImageMediaType(mimeType, data: data) else {
            throw AIError.invalidArgument(argument: "files", message: "Hugging Face Responses API only supports image file parts; got \(mimeType).")
        }
        return .object([
            "type": .string("input_image"),
            "image_url": .string("data:\(mediaType);base64,\(data.base64EncodedString())")
        ])
    case .providerReference:
        throw AIError.invalidArgument(argument: "files", message: "Hugging Face Responses API does not support file parts with provider references.")
    case .reasoningFile, .custom, .toolCall, .toolResult, .toolApprovalRequest, .toolApprovalResponse:
        return nil
    }
}

private func huggingFaceResolvedImageMediaType(_ mimeType: String, data: Data) -> String? {
    let normalized = mimeType.lowercased()
    if normalized.hasPrefix("image/"), normalized != "image/*" {
        return normalized
    }
    guard normalized == "image" || normalized == "image/*" else {
        return nil
    }
    return huggingFaceDetectedImageMediaType(data)
}

private func huggingFaceDetectedImageMediaType(_ data: Data) -> String? {
    let bytes = Array(data.prefix(12))
    if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
        return "image/png"
    }
    if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
        return "image/jpeg"
    }
    if bytes.starts(with: [0x47, 0x49, 0x46, 0x38]) {
        return "image/gif"
    }
    if bytes.count >= 12,
       bytes[0..<4].elementsEqual([0x52, 0x49, 0x46, 0x46]),
       bytes[8..<12].elementsEqual([0x57, 0x45, 0x42, 0x50]) {
        return "image/webp"
    }
    return nil
}

private func huggingFaceTools(from tools: [String: JSONValue]) -> (tools: [JSONValue], warnings: [AIWarning]) {
    var output: [JSONValue] = []
    var warnings: [AIWarning] = []
    // Swift tool sets are unordered; sort by name so the wire order is deterministic.
    for (name, schema) in tools.sorted(by: { $0.key < $1.key }) {
        if schema["type"]?.stringValue == "provider" || schema["id"]?.stringValue != nil {
            warnings.append(AIWarning(type: "unsupported", feature: "provider-defined tool \(schema["id"]?.stringValue ?? name)"))
            continue
        }
        // Upstream `huggingface-responses-prepare-tools` sends `tool.inputSchema` as `parameters`.
        var tool: [String: JSONValue] = [
            "type": .string("function"),
            "name": .string(name),
            "parameters": aiFunctionToolInputSchema(schema)
        ]
        if let description = schema["description"]?.stringValue {
            tool["description"] = .string(description)
        }
        output.append(.object(tool))
    }
    return (output, warnings)
}

private func huggingFaceToolChoice(from value: JSONValue?) -> JSONValue? {
    guard let value else { return nil }
    if let string = value.stringValue { return .string(string) }
    guard let object = value.objectValue else { return nil }
    switch object["type"]?.stringValue {
    case "auto", "required", "none":
        return object["type"]
    case "tool":
        guard let toolName = object["toolName"]?.stringValue ?? object["tool_name"]?.stringValue else { return nil }
        return .object([
            "type": .string("function"),
            "function": .object(["name": .string(toolName)])
        ])
    default:
        return nil
    }
}

private func huggingFaceResponseContent(from raw: JSONValue) -> (content: [AIResultContentPart], text: String, reasoning: String) {
    var content: [AIResultContentPart] = []
    var text = ""
    var reasoning = ""
    var sourceCount = 0

    // Mirrors upstream doGenerate: output items in order; `output_text` is not used.
    for item in raw["output"]?.arrayValue ?? [] {
        switch item["type"]?.stringValue {
        case "message":
            let metadata = huggingFaceItemMetadata(id: item["id"]?.stringValue)
            for part in item["content"]?.arrayValue ?? [] {
                guard let partText = part["text"]?.stringValue else { continue }
                content.append(.text(partText, providerMetadata: metadata))
                text += partText
                for annotation in part["annotations"]?.arrayValue ?? [] {
                    content.append(.source(AISource(
                        id: "huggingface-source-\(sourceCount)",
                        sourceType: "url",
                        url: annotation["url"]?.stringValue,
                        title: annotation["title"]?.stringValue,
                        rawValue: annotation
                    )))
                    sourceCount += 1
                }
            }
        case "reasoning":
            let metadata = huggingFaceItemMetadata(id: item["id"]?.stringValue)
            for part in item["content"]?.arrayValue ?? [] {
                guard let partText = part["text"]?.stringValue else { continue }
                content.append(.reasoning(partText, providerMetadata: metadata))
                reasoning += partText
            }
        case "mcp_call", "mcp_list_tools", "function_call":
            if let toolCall = huggingFaceToolCall(from: item) {
                content.append(.toolCall(toolCall))
            }
            if let toolResult = huggingFaceToolResult(from: item) {
                content.append(.toolResult(toolResult))
            }
        default:
            break
        }
    }

    return (content, text, reasoning)
}

private func huggingFaceUsage(from usage: JSONValue?) -> TokenUsage? {
    guard let usage, usage.objectValue != nil else { return nil }
    let inputTokens = usage["input_tokens"]?.intValue ?? 0
    let outputTokens = usage["output_tokens"]?.intValue ?? 0
    let cachedTokens = usage["input_tokens_details"]?["cached_tokens"]?.intValue ?? 0
    let reasoningTokens = usage["output_tokens_details"]?["reasoning_tokens"]?.intValue ?? 0
    return TokenUsage(
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        totalTokens: usage["total_tokens"]?.intValue,
        inputTokensNoCache: inputTokens - cachedTokens,
        inputTokensCacheRead: cachedTokens,
        outputTextTokens: outputTokens - reasoningTokens,
        outputReasoningTokens: reasoningTokens,
        rawValue: usage
    )
}

private func huggingFaceToolCall(from item: JSONValue?) -> AIToolCall? {
    guard let item, let type = item["type"]?.stringValue else { return nil }
    switch type {
    case "function_call":
        guard let name = item["name"]?.stringValue else { return nil }
        return AIToolCall(
            id: item["call_id"]?.stringValue ?? item["id"]?.stringValue ?? "function-call",
            name: name,
            arguments: item["arguments"]?.stringValue ?? "{}",
            rawValue: item
        )
    case "mcp_call":
        guard let name = item["name"]?.stringValue else { return nil }
        return AIToolCall(
            id: item["id"]?.stringValue ?? "mcp-call",
            name: name,
            arguments: item["arguments"]?.stringValue ?? "{}",
            providerExecuted: true,
            rawValue: item
        )
    case "mcp_list_tools":
        let arguments = huggingFaceJSONString(.object(["server_label": item["server_label"] ?? .null])) ?? "{}"
        return AIToolCall(
            id: item["id"]?.stringValue ?? "mcp-list-tools",
            name: "list_tools",
            arguments: arguments,
            providerExecuted: true,
            rawValue: item
        )
    default:
        return nil
    }
}

private func huggingFaceToolResult(from item: JSONValue?) -> AIToolResult? {
    guard let item, let type = item["type"]?.stringValue else { return nil }
    switch type {
    case "function_call":
        guard let output = item["output"], huggingFaceIsTruthy(output), let name = item["name"]?.stringValue else { return nil }
        return AIToolResult(
            toolCallID: item["call_id"]?.stringValue ?? item["id"]?.stringValue ?? "function-call",
            toolName: name,
            result: output,
            modelOutput: output
        )
    case "mcp_call":
        guard let output = item["output"], huggingFaceIsTruthy(output), let name = item["name"]?.stringValue else { return nil }
        return AIToolResult(
            toolCallID: item["id"]?.stringValue ?? "mcp-call",
            toolName: name,
            result: output,
            modelOutput: output
        )
    case "mcp_list_tools":
        guard let tools = item["tools"], huggingFaceIsTruthy(tools) else { return nil }
        let result: JSONValue = .object(["tools": tools])
        return AIToolResult(
            toolCallID: item["id"]?.stringValue ?? "mcp-list-tools",
            toolName: "list_tools",
            result: result,
            modelOutput: result
        )
    default:
        return nil
    }
}

private func huggingFaceIsTruthy(_ value: JSONValue) -> Bool {
    switch value {
    case .null: return false
    case let .string(string): return !string.isEmpty
    case let .bool(bool): return bool
    case let .number(number): return number != 0
    default: return true
    }
}

private func huggingFaceItemMetadata(id: String?) -> [String: JSONValue] {
    guard let id else { return [:] }
    return ["huggingface": .object(["itemId": .string(id)])]
}

private func huggingFaceResponseMetadata(from raw: JSONValue? = nil, response: AIHTTPResponse, modelID: String) -> AIResponseMetadata {
    AIResponseMetadata(
        id: raw?["id"]?.stringValue,
        timestamp: raw?["created_at"]?.doubleValue.map { Date(timeIntervalSince1970: $0) } ?? Date(),
        modelID: raw?["model"]?.stringValue ?? modelID,
        headers: response.headers,
        body: raw
    )
}

private func huggingFaceFinishReason(_ reason: String?) -> String? {
    switch reason {
    case "stop":
        return "stop"
    case "length":
        return "length"
    case "content_filter":
        return "content-filter"
    case "tool_calls":
        return "tool-calls"
    case "error":
        return "error"
    default:
        return "other"
    }
}

private func huggingFaceStreamProviderError(from raw: JSONValue) -> AIStreamProviderError? {
    guard let type = raw["type"]?.stringValue,
          type == "error" || type == "response.failed" else {
        return nil
    }
    let details = type == "response.failed"
        ? raw["response"]?["error"]
        : (raw["error"] ?? raw)
    guard let message = details?["message"]?.stringValue else { return nil }
    let code: JSONValue?
    if details?["code"]?.stringValue != nil || details?["code"]?.doubleValue != nil {
        code = details?["code"]
    } else {
        code = nil
    }
    let statusCode: Int?
    if let numericCode = code?.intValue, (400...599).contains(numericCode) {
        statusCode = numericCode
    } else if let stringCode = code?.stringValue,
              stringCode.count == 3,
              stringCode.allSatisfy(\.isNumber),
              let numericCode = Int(stringCode),
              (400...599).contains(numericCode) {
        statusCode = numericCode
    } else {
        statusCode = nil
    }
    return AIStreamProviderError(
        message: message,
        type: type,
        code: code,
        statusCode: statusCode,
        data: raw
    )
}

private func huggingFaceJSONString(_ value: JSONValue) -> String? {
    guard let data = try? encodeJSONBody(value) else { return nil }
    return String(data: data, encoding: .utf8)
}
