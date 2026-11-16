import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities


public final class AlibabaLanguageModel: LanguageModel, @unchecked Sendable {
    public let providerID = "alibaba.chat"
    public let modelID: String
    private let config: AlibabaModelConfiguration

    public init(modelID: String, config: AlibabaModelConfiguration) {
        self.modelID = modelID
        self.config = config
    }

    public func generate(_ request: LanguageModelRequest) async throws -> TextGenerationResult {
        let prepared = try alibabaPreparedCall(
            for: request,
            modelID: modelID,
            stream: false,
            includeUsage: config.includeUsage,
            transformRequestBody: config.transformRequestBody
        )
        let httpResponse = try await config.transport.send(config.request(
            path: "/chat/completions",
            modelID: modelID,
            body: .object(prepared.body),
            headers: request.headers,
            abortSignal: request.abortSignal
        ))
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw alibabaHTTPStatusError(provider: providerID, response: httpResponse)
        }
        let response = (json: try httpResponse.jsonValue(), response: httpResponse)
        let raw = response.json
        let choice = raw["choices"]?[0]
        let toolCalls = alibabaToolCalls(from: choice?["message"]?["tool_calls"])
        // Upstream returns whatever content is present (possibly none) instead of failing.
        let text = choice?["message"]?["content"]?.stringValue ?? ""
        return TextGenerationResult(
            text: text,
            reasoning: choice?["message"]?["reasoning_content"]?.stringValue ?? "",
            finishReason: alibabaFinishReason(choice?["finish_reason"]?.stringValue),
            usage: alibabaUsage(from: raw) ?? TokenUsage(),
            toolCalls: toolCalls,
            rawValue: raw,
            warnings: prepared.warnings,
            responseMetadata: alibabaResponseMetadata(from: raw, response: response.response, modelID: modelID)
        )
    }

    public func stream(_ request: LanguageModelRequest) -> AsyncThrowingStream<LanguageStreamPart, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let prepared = try alibabaPreparedCall(
                        for: request,
                        modelID: modelID,
                        stream: true,
                        includeUsage: config.includeUsage,
                        transformRequestBody: config.transformRequestBody
                    )
                    let httpRequest = try config.request(
                        path: "/chat/completions",
                        modelID: modelID,
                        body: .object(prepared.body),
                        headers: request.headers,
                        abortSignal: request.abortSignal
                    )
                    let response = try await config.streamRequest(httpRequest)
                    guard (200..<300).contains(response.statusCode) else {
                        throw alibabaHTTPStatusError(
                            provider: providerID,
                            response: try await bufferedHTTPResponse(from: response, request: httpRequest)
                        )
                    }
                    let responseHead = httpResponseHead(from: response, request: httpRequest)

                    continuation.yield(.streamStart(warnings: prepared.warnings))
                    var latestUsage: TokenUsage? = TokenUsage()
                    var finishReason: String? = "interrupted"
                    var toolCalls = AIStreamingToolCallTracker(generateID: { generateId() })
                    var emittedResponseMetadata = false
                    var activeText = false
                    var activeReasoningID: String?
                    for try await event in serverSentEvents(from: response.body) {
                        // Upstream parseJsonEventStream ignores [DONE] and keeps reading.
                        if event.data == "[DONE]" { continue }
                        let raw: JSONValue
                        do {
                            raw = try decodeJSONBody(Data(event.data.utf8))
                        } catch {
                            if request.includeRawChunks {
                                // Upstream emits a raw part with an undefined rawValue for unparsable chunks.
                                continuation.yield(.raw(.null))
                            }
                            finishReason = "error"
                            continuation.yield(.error(message: error.localizedDescription))
                            continue
                        }
                        if request.includeRawChunks {
                            continuation.yield(.raw(raw))
                        }
                        if let streamError = alibabaStreamError(from: raw) {
                            finishReason = "error"
                            continuation.yield(.error(message: streamError.message, rawValue: streamError.rawValue))
                            continue
                        }
                        if !emittedResponseMetadata {
                            emittedResponseMetadata = true
                            continuation.yield(.responseMetadata(alibabaResponseMetadata(from: raw, response: responseHead, modelID: modelID)))
                        }
                        latestUsage = alibabaUsage(from: raw) ?? latestUsage
                        guard let choice = raw["choices"]?[0] else { continue }

                        if let reasoning = choice["delta"]?["reasoning_content"]?.stringValue, !reasoning.isEmpty {
                            if activeText {
                                continuation.yield(.textEnd(id: "0"))
                                activeText = false
                            }
                            let id = activeReasoningID ?? generateId()
                            if activeReasoningID == nil {
                                activeReasoningID = id
                                continuation.yield(.reasoningStart(id: id))
                            }
                            continuation.yield(.reasoningDeltaPart(id: id, delta: reasoning))
                        }
                        if let delta = choice["delta"]?["content"]?.stringValue, !delta.isEmpty {
                            if let reasoningID = activeReasoningID {
                                continuation.yield(.reasoningEnd(id: reasoningID))
                                activeReasoningID = nil
                            }
                            if !activeText {
                                continuation.yield(.textStart(id: "0"))
                                activeText = true
                            }
                            continuation.yield(.textDeltaPart(id: "0", delta: delta))
                        }
                        if let toolCallDeltas = choice["delta"]?["tool_calls"]?.arrayValue,
                           !toolCallDeltas.isEmpty {
                            if let reasoningID = activeReasoningID {
                                continuation.yield(.reasoningEnd(id: reasoningID))
                                activeReasoningID = nil
                            }
                            if activeText {
                                continuation.yield(.textEnd(id: "0"))
                                activeText = false
                            }
                            for toolCallDelta in toolCallDeltas {
                                let parts = try toolCalls.processDelta(AIStreamingToolCallDelta(
                                    index: toolCallDelta["index"]?.intValue,
                                    id: toolCallDelta["id"]?.stringValue,
                                    type: toolCallDelta["type"]?.stringValue,
                                    functionName: toolCallDelta["function"]?["name"]?.stringValue,
                                    arguments: toolCallDelta["function"]?["arguments"]?.stringValue,
                                    rawValue: toolCallDelta
                                ))
                                for part in parts {
                                    continuation.yield(part)
                                }
                            }
                        }
                        if let reason = choice["finish_reason"]?.stringValue {
                            finishReason = alibabaFinishReason(reason)
                        }
                    }
                    if let reasoningID = activeReasoningID {
                        continuation.yield(.reasoningEnd(id: reasoningID))
                    }
                    if activeText {
                        continuation.yield(.textEnd(id: "0"))
                    }
                    for part in toolCalls.flush() {
                        continuation.yield(part)
                    }
                    continuation.yield(.finishMetadata(
                        reason: finishReason,
                        usage: latestUsage,
                        providerMetadata: [:]
                    ))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}