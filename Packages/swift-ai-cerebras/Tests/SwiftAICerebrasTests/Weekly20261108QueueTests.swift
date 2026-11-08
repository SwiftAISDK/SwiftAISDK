import Foundation
import Testing
@testable import SwiftAICerebras
import SwiftAIProvider

@Suite("Weekly20261108 Cerebras queue and tier")
struct Weekly20261108QueueTests {
    @Test(arguments: [false, true])
    func requestMetadataUsesActualConfiguredURL(_ stream: Bool) async throws {
        let response = stream ? sseResponse("data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"ok\"},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n") : jsonResponse(#"{"choices":[{"message":{"content":"ok"},"finish_reason":"stop"}]}"#)
        let transport = RecordingTransport(response: response)
        let provider = try CerebrasProvider(configuration: .init(apiKey: "key", baseURL: "https://inference.example.com/prefix/v1", queryParams: ["tenant": "1"], transport: transport))
        let model = try provider.languageModel("model")
        let request = LanguageModelRequest(messages: [.user("Hi")], providerOptions: ["cerebras": ["queueThreshold": 200]])
        var metadata: AIRequestMetadata?
        if stream {
            for try await part in model.stream(request) {
                if case let .requestMetadata(value) = part { metadata = value }
            }
        } else { metadata = try await model.generate(request).requestMetadata }
        let sent = try #require(await transport.requests().first)
        #expect(metadata?.url == "https://inference.example.com/prefix/v1/chat/completions?tenant=1")
        #expect(metadata?.url == sent.url.absoluteString)
        #expect(metadata?.headers["queue_threshold"] == "200")
        #expect(metadata?.body?["model"] == "model")
    }

    @Test(arguments: [false, true])
    func inheritedRefusalTextAndFinishReasonAreRetained(_ stream: Bool) async throws {
        for (content, refusal, finish, format, expectedText, expectedFinish) in [
            (JSONValue.null, JSONValue.string("Declined"), "stop", Optional<AIResponseFormat>.none, "Declined", "content-filter"),
            (JSONValue.string("Prefix"), "Declined", "stop", nil, "PrefixDeclined", "content-filter"),
            (JSONValue.string("Prefix"), false, "stop", nil, "Prefix", "stop"),
            (JSONValue.null, "Declined", "length", nil, "Declined", "length"),
            (JSONValue.null, "Declined", "tool_calls", nil, "Declined", "tool-calls"),
            (JSONValue.null, "Declined", "tool_calls", AIResponseFormat.json(schema: ["type": "object"]), "Declined", "stop")
        ] {
            let payload: JSONValue = stream
                ? ["choices": [["index": 0, "delta": ["content": content, "refusal": refusal], "finish_reason": .string(finish)]]]
                : ["choices": [["message": ["content": content, "refusal": refusal], "finish_reason": .string(finish)]]]
            let data = try JSONEncoder().encode(payload)
            let response = stream ? sseResponse("data: \(String(decoding: data, as: UTF8.self))\n\ndata: [DONE]\n\n") : .init(statusCode: 200, body: data)
            let transport = RecordingTransport(response: response)
            let provider = try CerebrasProvider(configuration: .init(apiKey: "key", transport: transport))
            let model = try provider.languageModel("model")
            let request = LanguageModelRequest(messages: [.user("Hi")], responseFormat: format)
            if stream {
                var text = "", reason: String?
                for try await part in model.stream(request) {
                    if case let .textDeltaPart(_, delta, _) = part { text += delta }
                    if case let .finishMetadata(value, _, _) = part { reason = value }
                }
                #expect(text == expectedText)
                #expect(reason == expectedFinish)
            } else {
                let result = try await model.generate(request)
                #expect(result.text == expectedText)
                #expect(result.finishReason == expectedFinish)
            }
        }
    }

    @Test func lateRefusalAfterStopStillChangesFinishReason() async throws {
        let transport = RecordingTransport(response: sseResponse("""
        data: {"choices":[{"index":0,"delta":{"content":"Prefix"},"finish_reason":"stop"}]}

        data: {"choices":[{"index":0,"delta":{"refusal":"Declined"},"finish_reason":null}]}

        data: [DONE]

        """))
        let provider = try CerebrasProvider(configuration: .init(apiKey: "key", transport: transport))
        var text = "", reason: String?
        for try await part in try provider.languageModel("model").stream(.init(messages: [.user("Hi")])) {
            if case let .textDeltaPart(_, delta, _) = part { text += delta }
            if case let .finishMetadata(value, _, _) = part { reason = value }
        }
        #expect(text == "PrefixDeclined")
        #expect(reason == "content-filter")
    }

    @Test(arguments: [false, true])
    func queueValidationPreservesDynamicOptionPassThrough(_ stream: Bool) async throws {
        let request = LanguageModelRequest(messages: [.user("Hi")], providerOptions: ["cerebras": [
            "queueThreshold": 200, "serviceTier": "future-tier", "reasoningEffort": .null,
            "topLogprobs": 21, "promptCacheKey": .string(String(repeating: "x", count: 1025))
        ]])
        let call = try cerebrasPreparedCall(for: request, modelID: "gpt-oss-120b", stream: stream)
        #expect(call.headers["queue_threshold"] == "200")
        #expect(call.body["service_tier"] == "future-tier")
        #expect(call.body["reasoning_effort"] == .null)
        #expect(call.body["top_logprobs"] == 21)
        #expect(call.body["prompt_cache_key"]?.stringValue?.count == 1025)
        #expect(call.body["queueThreshold"] == nil)
    }

    @Test func networkRequestsAndStreamMetadataKeepQueueAndLastEffectiveTier() async throws {
        let transport = RecordingTransport(response: sseResponse("""
        data: {"choices":[{"index":0,"delta":{"content":"ok"}}],"service_tier":"flex"}

        data: {"choices":[],"service_tier":"priority"}

        data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}],"service_tier":null}

        data: [DONE]

        """))
        let provider = try CerebrasProvider(configuration: .init(apiKey: "key", headers: ["QUEUE_THRESHOLD": "provider"], transport: transport))
        let callerHeaders = ["queue_threshold": "call", "X-Request-ID": "request"]
        var metadata: [String: JSONValue] = [:]
        for try await part in try provider.languageModel("model").stream(.init(messages: [.user("Hi")], providerOptions: ["cerebras": ["queueThreshold": 200, "serviceTier": "flex"]], headers: callerHeaders)) {
            if case let .finishMetadata(_, _, values) = part { metadata = values }
        }
        #expect(metadata["cerebras"]?["serviceTier"] == "priority")
        let sent = try #require(await transport.requests().first)
        #expect(sent.headers["queue_threshold"] == "200")
        #expect(sent.headers.keys.filter { $0.lowercased() == "queue_threshold" }.count == 1)
        #expect(callerHeaders["queue_threshold"] == "call")
        #expect(sent.headers["x-request-id"] == "request")
        let body = try JSONDecoder().decode(JSONValue.self, from: #require(sent.body))
        #expect(body["service_tier"] == "flex")
        #expect(body["queueThreshold"] == nil)
    }

    @Test(arguments: [50, 1000, 20000])
    func queueThresholdIsAHeaderAndWinsCaseInsensitiveOverride(_ threshold: Int) throws {
        let request = LanguageModelRequest(messages: [.user("hello")], providerOptions: ["cerebras": ["queueThreshold": .number(Double(threshold))]], headers: ["QUEUE_THRESHOLD": "old"])
        for stream in [false, true] {
            let call = try cerebrasPreparedCall(for: request, modelID: "model", stream: stream)
            #expect(call.headers["queue_threshold"] == String(threshold))
            #expect(call.headers.count == 1)
            #expect(call.body["queueThreshold"] == nil)
        }
    }
    @Test(arguments: [49.0, 20001.0, 50.5])
    func invalidQueueThresholdStopsBeforeNetwork(_ threshold: Double) throws {
        #expect(throws: AIError.self) {
            try cerebrasPreparedCall(for: .init(messages: [.user("hi")], providerOptions: ["cerebras": ["queueThreshold": .number(threshold)]]), modelID: "model", stream: false)
        }
    }
    @Test func responseTierIsKeptAcrossNullStreamChunks() {
        var output = cerebrasProviderMetadata(from: ["service_tier": "flex"], choice: nil)
        cerebrasMergeProviderMetadata(cerebrasProviderMetadata(from: ["service_tier": .null], choice: nil), into: &output)
        #expect(output["cerebras"]?["serviceTier"] == "flex")
    }
}
