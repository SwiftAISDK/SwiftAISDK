import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible


public final class CerebrasLanguageModel: LanguageModel, @unchecked Sendable {
    public let providerID = "cerebras.chat"
    public let modelID: String
    private let config: AIProviderHTTPClient

    public init(modelID: String, http: AIProviderHTTPClient) {
        self.modelID = modelID
        self.config = http
    }

    public func generate(_ request: LanguageModelRequest) async throws -> TextGenerationResult {
        let prepared = try cerebrasPreparedCall(for: request, modelID: modelID, stream: false)
        let httpRequest = try config.request(
            path: "/chat/completions",
            modelID: modelID,
            body: .object(prepared.body),
            headers: prepared.headers,
            abortSignal: request.abortSignal
        )
        let httpResponse = try await config.transport.send(httpRequest)
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw cerebrasHTTPStatusError(response: httpResponse)
        }
        let response = (json: try httpResponse.jsonValue(), response: httpResponse)
        let raw = response.json
        let choice = raw["choices"]?[0]
        let toolCalls = cerebrasToolCalls(from: choice?["message"]?["tool_calls"])
        let content = choice?["message"]?["content"]?.stringValue
        let refusal = choice?["message"]?["refusal"]?.stringValue ?? ""
        guard content != nil || !refusal.isEmpty || !toolCalls.isEmpty else {
            throw AIError.invalidResponse(provider: providerID, message: "No text content found in Cerebras response.")
        }
        let text = (content ?? "") + refusal
        let rawFinishReason = choice?["finish_reason"]?.stringValue
        let finishReason = cerebrasFinishReason(
            rawFinishReason,
            hasText: !text.isEmpty,
            normalizeStructuredToolCalls: prepared.normalizesStructuredToolCalls,
            hasRefusal: !refusal.isEmpty
        )
        return TextGenerationResult(
            text: text,
            reasoning: choice?["message"]?["reasoning"]?.stringValue ?? "",
            finishReason: finishReason,
            usage: cerebrasUsage(from: raw) ?? TokenUsage(),
            toolCalls: cerebrasShouldDropStructuredToolCalls(
                hasText: !text.isEmpty,
                normalizeStructuredToolCalls: prepared.normalizesStructuredToolCalls
            ) ? [] : toolCalls,
            providerMetadata: cerebrasProviderMetadata(from: raw, choice: choice),
            rawValue: raw,
            warnings: prepared.warnings,
            requestMetadata: AIRequestMetadata(body: .object(prepared.body), headers: prepared.headers, url: httpRequest.url.absoluteString),
            responseMetadata: cerebrasResponseMetadata(from: raw, response: response.response, modelID: modelID)
        )
    }

    public func stream(_ request: LanguageModelRequest) -> AsyncThrowingStream<LanguageStreamPart, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let prepared = try cerebrasPreparedCall(for: request, modelID: modelID, stream: true)
                    let httpRequest = try config.request(
                        path: "/chat/completions",
                        modelID: modelID,
                        body: .object(prepared.body),
                        headers: prepared.headers,
                        abortSignal: request.abortSignal
                    )
                    let response = try await config.streamRequest(httpRequest)
                    guard (200..<300).contains(response.statusCode) else {
                        throw cerebrasHTTPStatusError(
                            response: try await bufferedHTTPResponse(from: response, request: httpRequest)
                        )
                    }
                    let responseHead = httpResponseHead(from: response, request: httpRequest)

                    continuation.yield(.streamStart(warnings: prepared.warnings))
                    continuation.yield(.requestMetadata(AIRequestMetadata(body: .object(prepared.body), headers: prepared.headers, url: httpRequest.url.absoluteString)))
                    var latestUsage: TokenUsage? = TokenUsage()
                    var hasText = false
                    var hasRefusal = false
                    var rawFinishReason: String?
                    var finishReason: String? = "other"
                    var toolCalls = CerebrasStreamingToolCalls()
                    var emittedResponseMetadata = false
                    var providerMetadata: [String: JSONValue] = [:]
                    var activeText = false
                    var activeReasoningID: String?
                    for try await event in serverSentEvents(from: response.body) {
                        if event.data == "[DONE]" { break }
                        let raw: JSONValue
                        do {
                            raw = try decodeJSONBody(Data(event.data.utf8))
                        } catch {
                            finishReason = "error"
                            continuation.yield(.error(message: error.localizedDescription))
                            continue
                        }
                        if request.includeRawChunks {
                            continuation.yield(.raw(raw))
                        }
                        if let streamError = cerebrasStreamError(from: raw) {
                            finishReason = "error"
                            continuation.yield(.error(message: streamError.message, rawValue: streamError.rawValue))
                            continue
                        }
                        if !emittedResponseMetadata {
                            emittedResponseMetadata = true
                            continuation.yield(.responseMetadata(cerebrasResponseMetadata(from: raw, response: responseHead, modelID: modelID)))
                        }
                        cerebrasMergeProviderMetadata(cerebrasProviderMetadata(from: raw, choice: raw["choices"]?[0]), into: &providerMetadata)
                        latestUsage = cerebrasUsage(from: raw) ?? latestUsage
                        if let reasoning = raw["choices"]?[0]?["delta"]?["reasoning"]?.stringValue, !reasoning.isEmpty {
                            if activeText {
                                continuation.yield(.textEnd(id: "0"))
                                activeText = false
                            }
                            let id = activeReasoningID ?? "reasoning-0"
                            if activeReasoningID == nil {
                                activeReasoningID = id
                                continuation.yield(.reasoningStart(id: id))
                            }
                            continuation.yield(.reasoningDeltaPart(id: id, delta: reasoning))
                        }
                        let content = raw["choices"]?[0]?["delta"]?["content"]?.stringValue
                        let refusal = raw["choices"]?[0]?["delta"]?["refusal"]?.stringValue
                        if refusal?.isEmpty == false { hasRefusal = true }
                        for delta in [content, refusal].compactMap({ $0 }) where !delta.isEmpty {
                            hasText = true
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
                        if let toolCallDeltas = raw["choices"]?[0]?["delta"]?["tool_calls"]?.arrayValue,
                           !cerebrasShouldDropStructuredToolCalls(
                               hasText: hasText,
                               normalizeStructuredToolCalls: prepared.normalizesStructuredToolCalls
                            ) {
                            for toolCallDelta in toolCallDeltas {
                                if !toolCalls.hasMatchingBuffer(for: toolCallDelta) {
                                    guard toolCallDelta["id"]?.stringValue != nil else {
                                        throw AIError.invalidResponse(provider: providerID, message: "Expected 'id' to be a string.")
                                    }
                                    guard toolCallDelta["function"]?["name"]?.stringValue != nil else {
                                        throw AIError.invalidResponse(provider: providerID, message: "Expected 'function.name' to be a string.")
                                    }
                                }
                                for part in toolCalls.apply(delta: toolCallDelta) {
                                    continuation.yield(part)
                                }
                            }
                        }
                        if let reason = raw["choices"]?[0]?["finish_reason"]?.stringValue {
                            rawFinishReason = reason
                            finishReason = cerebrasFinishReason(
                                reason,
                                hasText: hasText,
                                normalizeStructuredToolCalls: prepared.normalizesStructuredToolCalls,
                                hasRefusal: hasRefusal
                            )
                        }
                    }
                    if let reasoningID = activeReasoningID {
                        continuation.yield(.reasoningEnd(id: reasoningID))
                    }
                    if activeText {
                        continuation.yield(.textEnd(id: "0"))
                    }
                    for part in toolCalls.finishedParts() {
                        continuation.yield(part)
                    }
                    if hasRefusal, rawFinishReason == "stop", finishReason != "error" {
                        finishReason = "content-filter"
                    }
                    continuation.yield(.finishMetadata(
                        reason: finishReason,
                        usage: latestUsage,
                        providerMetadata: providerMetadata
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

typealias CerebrasStreamingToolCalls = OpenAIStyleStreamingToolCalls

struct CerebrasPreparedCall {
    var body: [String: JSONValue]
    var headers: [String: String]
    var warnings: [AIWarning]
    var normalizesStructuredToolCalls: Bool
}

struct CerebrasPreparedTools {
    var tools: [JSONValue]
    var warnings: [AIWarning]
}
