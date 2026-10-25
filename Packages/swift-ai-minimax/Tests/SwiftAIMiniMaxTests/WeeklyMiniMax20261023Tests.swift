@testable import SwiftAIMiniMax
@testable import SwiftAIAnthropic
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

@Suite("WeeklyMiniMax20261023")
struct WeeklyMiniMax20261023Tests {
    private let marker: JSONValue = ["type": "ephemeral"]

    @Test(arguments: ["minimax-m3.1", "MiniMax-M3.1-Flash-Preview", "minimax-m3.1.1", "minimax-m3.2", "minimax-m3.10-flash", "minimax-m3.123-flash", "minimax-m4", "MiniMax-M4.0-Highspeed", "minimax-m10"])
    func newerModelsExposePublishedCapabilities(_ modelID: String) async throws {
        let provider = try AIProviders.miniMax(configuration: MiniMaxProviderSettings(apiKey: "key"))
        let model = try provider.languageModel(modelID)
        #expect(isURLSupported(mediaType: "image/png", url: "https://example.com/image.png", supportedURLs: model.supportedURLs))
        #expect(isURLSupported(mediaType: "video/mp4", url: "http://example.com/video.mp4", supportedURLs: model.supportedURLs))
        #expect(!isURLSupported(mediaType: "video/mp4", url: "ftp://example.com/video.mp4", supportedURLs: model.supportedURLs))
        let (body, _) = try await call(LanguageModelRequest(messages: [AIMessage(role: .user, content: [
            .text("Cached", providerMetadata: ["minimax": ["cacheControl": marker]]),
            .providerReference(mimeType: "video/mp4", reference: ["minimax": "123"])
        ])], temperature: 1.5, maxOutputTokens: 100, reasoning: "high"), modelID: modelID)
        #expect(body["temperature"] == 1.5)
        #expect(body["output_config"]?["effort"] == "high")
        #expect(body["thinking"] == nil)
        #expect(body["messages"]?[0]?["content"]?[0]?["cache_control"] == marker)
        #expect(body["messages"]?[0]?["content"]?[1]?["source"]?["url"] == "mm_file://123")
    }

    @Test(arguments: ["minimax-m3", "minimax-m3.0-flash", "minimax-m2.99", "custom-model", "other-minimax-m4", "minimax-m3.1oops", "minimax-m4oops", "minimax-m٣.١"])
    func olderAndUnknownModelsKeepLegacyBehavior(_ modelID: String) async throws {
        let provider = try AIProviders.miniMax(configuration: MiniMaxProviderSettings(apiKey: "key"))
        #expect(try provider.languageModel(modelID).supportedURLs.isEmpty)
        let (body, warnings) = try await call(LanguageModelRequest(messages: [AIMessage(role: .user, content: [
            .text("MiniMax", providerMetadata: ["minimax": ["cacheControl": marker]]),
            .text("Anthropic", providerMetadata: ["anthropic": ["cacheControl": marker]])
        ])], temperature: 1.5, maxOutputTokens: 100), modelID: modelID)
        #expect(body["temperature"] == 1)
        #expect(warnings.contains { $0.feature == "temperature" && $0.message?.contains("anthropic") == true })
        #expect(body["messages"]?[0]?["content"]?[0]?["cache_control"] == nil)
        #expect(body["messages"]?[0]?["content"]?[1]?["cache_control"] == marker)
        #expect(throws: AIError.self) {
            try AnthropicLanguageModel.body(for: LanguageModelRequest(messages: [AIMessage(role: .user, content: [
                .data(mimeType: "video/mp4", data: Data([1, 2, 3]))
            ])]), modelID: modelID, providerID: "minimax.messages")
        }
    }

    @Test(arguments: ["none", "minimal", "low", "medium", "high", "xhigh", "max"])
    func reasoningMapsToEffortForGenerateAndStream(_ reasoning: String) async throws {
        for streaming in [false, true] {
            let (body, warnings) = try await call(LanguageModelRequest(messages: [.user("Think")], maxOutputTokens: 100, reasoning: reasoning), streaming: streaming)
            let expected = ["none", "minimal"].contains(reasoning) ? "low" : reasoning
            #expect(body["output_config"]?["effort"] == .string(expected))
            #expect(body["thinking"] == nil)
            #expect(body["max_tokens"] == 100)
            let reasoningWarnings = warnings.filter { $0.feature == "reasoning" }
            #expect(reasoningWarnings.count == (["none", "minimal"].contains(reasoning) ? 1 : 0))
            if reasoning == "none" { #expect(reasoningWarnings.first?.message?.contains("always reasons") == true) }
            if streaming { #expect(body["stream"] == true) }
        }
    }

    @Test(arguments: ["anthropic", "minimax"])
    func explicitEffortTakesPrecedence(_ namespace: String) async throws {
        for streaming in [false, true] {
            let (body, warnings) = try await call(LanguageModelRequest(messages: [.user("Think")], maxOutputTokens: 100, reasoning: "none", providerOptions: [namespace: ["effort": "max"]]), streaming: streaming)
            #expect(body["output_config"]?["effort"] == "max")
            #expect(body["thinking"] == nil)
            #expect(!warnings.contains { $0.feature == "reasoning" })
        }
    }

    @Test func serverDefaultsAndNullCanonicalOptionsRemainIndependent() async throws {
        for reasoning in [nil, "provider-default"] as [String?] {
            let (body, warnings) = try await call(LanguageModelRequest(messages: [.user("Hi")], maxOutputTokens: 100, reasoning: reasoning))
            #expect(body["output_config"] == nil && body["thinking"] == nil)
            #expect(warnings.isEmpty)
        }
        let (body, _) = try await call(LanguageModelRequest(messages: [.user("Hi")], maxOutputTokens: 100, reasoning: "high", providerOptions: ["anthropic": .null]))
        #expect(body["output_config"]?["effort"] == "high")
        let (unsupported, warnings) = try await call(LanguageModelRequest(messages: [.user("Hi")], maxOutputTokens: 100, reasoning: "custom-effort"))
        #expect(unsupported["thinking"] == nil && unsupported["output_config"] == nil)
        #expect(warnings.contains { $0.type == "unsupported" && $0.feature == "reasoning" })
    }

    @Test(arguments: [-1.0, 0, 1.5, 2, 3])
    func samplingWithAdaptiveThinking(_ temperature: Double) async throws {
        for streaming in [false, true] {
            let (body, warnings) = try await call(LanguageModelRequest(messages: [.user("Think")], temperature: temperature, topP: 0.9, topK: 10, maxOutputTokens: 100, reasoning: "high", providerOptions: MiniMaxLanguageModelOptions(thinking: .adaptive).providerOptions), streaming: streaming)
            #expect(body["temperature"] == .number(min(2, max(0, temperature))))
            #expect(body["top_p"] == 0.9 && body["top_k"] == nil)
            #expect(body["thinking"] == ["type": "adaptive"])
            #expect(body["output_config"]?["effort"] == "high")
            #expect(warnings.contains { $0.feature == "topK" })
            #expect(!warnings.contains { $0.feature == "topP" })
            if temperature < 0 || temperature > 2 {
                #expect(warnings.contains { $0.feature == "temperature" && $0.message?.contains("minimax") == true })
            } else { #expect(!warnings.contains { $0.feature == "temperature" }) }
        }
    }

    @Test func typedMediaOptionsPreserveAllSourcesAndOrdering() async throws {
        let request = LanguageModelRequest(messages: [
            .system("Analyze the media."),
            AIMessage(role: .user, content: [.text("Look"), .file(mimeType: "image/png", data: Data([1, 2, 3]), filename: "picture.png", providerMetadata: MiniMaxImagePartOptions(detail: .high).providerOptions)]),
            AIMessage(role: .user, content: [
                .data(mimeType: "video/mp4", data: Data([1, 2, 3]), providerMetadata: MiniMaxVideoPartOptions(fps: 0.2).providerOptions),
                .videoURL("https://example.com/video.mp4", providerMetadata: MiniMaxVideoPartOptions(fps: 5).providerOptions),
                .providerReference(mimeType: "video/mp4", reference: ["minimax": "123"], providerMetadata: MiniMaxVideoPartOptions(fps: 1).providerOptions),
                .providerReference(mimeType: "video/mp4", reference: ["minimax": "mm_file://456"])
            ])
        ], maxOutputTokens: 100, providerOptions: MiniMaxLanguageModelOptions(effort: .high).providerOptions)
        for streaming in [false, true] {
            let (body, _) = try await call(request, streaming: streaming)
            let content = try #require(body["messages"]?[0]?["content"]?.arrayValue)
            #expect(body["messages"]?.arrayValue?.count == 1)
            #expect(content.map { $0["type"]?.stringValue } == ["text", "image", "video", "video", "video", "video"])
            #expect(content[1]["source"] == ["type": "base64", "media_type": "image/png", "data": "AQID", "detail": "high"])
            #expect(content[2]["source"] == ["type": "base64", "media_type": "video/mp4", "data": "AQID", "fps": 0.2])
            #expect(content[3]["source"] == ["type": "url", "url": "https://example.com/video.mp4", "fps": 5])
            #expect(content[4]["source"] == ["type": "url", "url": "mm_file://123", "fps": 1])
            #expect(content[5]["source"] == ["type": "url", "url": "mm_file://456"])
            #expect(body["system"] == [["type": "text", "text": "Analyze the media."]])
            #expect(body["output_config"]?["effort"] == "high")
        }
        #expect(request.messages[2].content.count == 4)
    }

    @Test func mediaDefaultsAndWildcardMIMEDetection() async throws {
        let png = Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
        let (body, _) = try await call(LanguageModelRequest(messages: [AIMessage(role: .user, content: [
            .imageURL("https://example.com/image.png"),
            .data(mimeType: "image/*", data: png),
            .data(mimeType: "application/pdf", data: Data("%PDF".utf8)),
            .imageURL("https://example.com/document.pdf")
        ])], maxOutputTokens: 100))
        #expect(body["messages"]?[0]?["content"]?[0]?["source"] == ["type": "url", "url": "https://example.com/image.png"])
        #expect(body["messages"]?[0]?["content"]?[1]?["source"]?["media_type"] == "image/png")
        #expect(body["messages"]?[0]?["content"]?[1]?["source"]?["detail"] == nil)
        #expect(body["messages"]?[0]?["content"]?[2]?["type"] == "document")
        #expect(body["messages"]?[0]?["content"]?[3]?["type"] == "document")
    }

    @Test(arguments: [false, true])
    func convertedMediaPreservesPartOrMessageCache(_ messageCache: Bool) async throws {
        let options: [String: JSONValue] = ["anthropic": ["cacheControl": marker]]
        let (body, _) = try await call(LanguageModelRequest(messages: [AIMessage(role: .user, content: [
            .text("Describe"),
            .videoURL("https://example.com/video.mp4", providerMetadata: messageCache ? [:] : options)
        ], providerMetadata: messageCache ? options : [:])], maxOutputTokens: 100))
        #expect(body["messages"]?[0]?["content"]?[0]?["cache_control"] == nil)
        #expect(body["messages"]?[0]?["content"]?[1]?["cache_control"] == marker)
    }

    @Test(arguments: [JSONValue.number(0), .number(0.1), .number(5.1), .string("1"), .null])
    func invalidFPSFailsBeforeIO(_ fps: JSONValue) async throws {
        try await rejectsBeforeIO(.data(mimeType: "video/mp4", data: Data([1]), providerMetadata: ["minimax": ["fps": fps]]))
    }

    @Test(arguments: [JSONValue.string("auto"), .number(1), .null])
    func invalidDetailFailsBeforeIO(_ detail: JSONValue) async throws {
        try await rejectsBeforeIO(.imageURL("https://example.com/image.png", providerMetadata: ["minimax": ["detail": detail]]))
    }

    @Test func unsupportedReferencesFailBeforeIO() async throws {
        try await rejectsBeforeIO(.providerReference(mimeType: "image/png", reference: ["minimax": "123"]))
        for part in [
            AIContentPart.providerReference(mimeType: "video/mp4", reference: ["anthropic": "file_123"]),
            .providerReference(mimeType: "video/mp4", reference: [:]),
            .videoURL("file:///tmp/video.mp4")
        ] { try await rejectsBeforeIO(part, missingReference: true) }
    }

    @Test(arguments: [JSONValue.string("minimal"), .number(1), .null])
    func invalidExplicitEffortFailsBeforeIO(_ effort: JSONValue) async throws {
        let transport = RecordingTransport(response: jsonResponse("{}"))
        let model = try AIProviders.miniMax(configuration: MiniMaxProviderSettings(apiKey: "key", transport: transport)).languageModel("minimax-m3.1-flash")
        await #expect(throws: AIError.self) {
            try await model.generate(LanguageModelRequest(messages: [.user("Hi")], providerOptions: ["minimax": ["effort": effort]]))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func cacheMarkersApplyToSystemPartsAndFinalMessageBlock() async throws {
        let options = MiniMaxCacheControlOptions(cacheControl: .ephemeral).providerOptions
        for streaming in [false, true] {
            let (body, _) = try await call(LanguageModelRequest(messages: [
                AIMessage(role: .system, content: [.text("System")], providerMetadata: options),
                AIMessage(role: .user, content: [.text("First", providerMetadata: options), .text("Last")], providerMetadata: options)
            ], maxOutputTokens: 100), streaming: streaming)
            #expect(body["system"]?[0]?["cache_control"] == marker)
            #expect(body["messages"]?[0]?["content"]?[0]?["cache_control"] == marker)
            #expect(body["messages"]?[0]?["content"]?[1]?["cache_control"] == marker)
        }
    }

    @Test(arguments: ["cacheControl", "cache_control"])
    func customCacheNamespacePrecedesCanonicalAndFallsBack(_ key: String) async throws {
        for customValue in [marker, .null] {
            let (body, _) = try await call(LanguageModelRequest(messages: [AIMessage(role: .user, content: [.text("Cached", providerMetadata: [
                "minimax": .object([key: customValue]),
                "anthropic": ["cache_control": ["type": "ephemeral", "ttl": "1h"]]
            ])])], maxOutputTokens: 100))
            #expect(body["messages"]?[0]?["content"]?[0]?["cache_control"] == (customValue == .null ? ["type": "ephemeral", "ttl": "1h"] : marker))
        }
    }

    @Test func cacheCountIsSharedAcrossPromptAndToolsAndNamespaces() async throws {
        let metadata: [String: JSONValue] = ["minimax": ["cacheControl": marker], "anthropic": ["cacheControl": marker]]
        let (body, warnings) = try await call(LanguageModelRequest(messages: [AIMessage(role: .user, content: (1...4).map { .text("Part \($0)", providerMetadata: metadata) })], maxOutputTokens: 100, tools: ["lookup": ["type": "object", "properties": [:], "providerOptions": .object(metadata)]]))
        #expect(body["messages"]?[0]?["content"]?.arrayValue?.filter { $0["cache_control"] != nil }.count == 4)
        #expect(body["tools"]?[0]?["cache_control"] == nil)
        #expect(warnings.filter { $0.feature == "cacheControl breakpoint limit" }.count == 1)
        let (toolOnly, _) = try await call(LanguageModelRequest(messages: [.user("Hi")], maxOutputTokens: 100, tools: ["lookup": ["type": "object", "properties": [:], "providerOptions": ["minimax": ["cache_control": marker]]]]))
        #expect(toolOnly["tools"]?[0]?["cache_control"] == marker)
    }

    @Test func partCacheWinsOverMessageCacheWithoutDoubleCounting() async throws {
        let partOptions: [String: JSONValue] = ["minimax": ["cacheControl": ["type": "ephemeral", "ttl": "1h"]]]
        let (body, warnings) = try await call(LanguageModelRequest(messages: [
            AIMessage(role: .user, content: (1...3).map { .text("Part \($0)", providerMetadata: partOptions) }, providerMetadata: ["minimax": ["cacheControl": marker]])
        ], maxOutputTokens: 100, tools: ["lookup": ["type": "object", "properties": [:], "providerOptions": ["minimax": ["cacheControl": marker]]]]))
        #expect(body["messages"]?[0]?["content"]?[2]?["cache_control"] == ["type": "ephemeral", "ttl": "1h"])
        #expect(body["tools"]?[0]?["cache_control"] == marker)
        #expect(!warnings.contains { $0.feature == "cacheControl breakpoint limit" })
    }

    @Test func sharedModelHasNoCrossCallMediaState() async throws {
        let transport = RecordingTransport(responses: [Self.success, Self.success])
        let model = try AIProviders.miniMax(configuration: MiniMaxProviderSettings(apiKey: "key", transport: transport)).languageModel("minimax-m3.1-flash")
        async let video = model.generate(LanguageModelRequest(messages: [AIMessage(role: .user, content: [.providerReference(mimeType: "video/mp4", reference: ["minimax": "123"])])]))
        async let text = model.generate(LanguageModelRequest(messages: [.user("Plain")]))
        _ = try await (video, text)
        let bodies = try await transport.requests().map { try decodeJSONBody(try #require($0.body)) }
        #expect(bodies.count == 2)
        #expect(bodies.filter { $0["messages"]?[0]?["content"]?[0]?["type"] == "video" }.count == 1)
        #expect(bodies.filter { $0["messages"]?[0]?["content"]?[0]?["text"] == "Plain" }.count == 1)
    }

    @Test func mappedReasoningCarriesMiniMaxUsageMetadataInGenerateAndStream() async throws {
        for reasoning in [nil, "high"] as [String?] {
            let transport = RecordingTransport(responses: [Self.success, sseResponse("""
            data: {"type":"message_start","message":{"id":"msg","model":"minimax-m3.1-flash","usage":{"input_tokens":1,"output_tokens":0}}}

            data: {"type":"message_stop"}

            """)])
            let model = try AIProviders.miniMax(configuration: MiniMaxProviderSettings(apiKey: "key", transport: transport)).languageModel("minimax-m3.1-flash")
            let request = LanguageModelRequest(messages: [.user("Think")], maxOutputTokens: 100, reasoning: reasoning, providerOptions: ["minimax": .null])
            let result = try await model.generate(request)
            #expect(result.providerMetadata["anthropic"]?["usage"]?["input_tokens"] == 1)
            #expect((result.providerMetadata["minimax"] != nil) == (reasoning != nil))
            var finishMetadata: [String: JSONValue]?
            for try await part in model.stream(request) {
                if case let .finishMetadata(_, _, metadata) = part { finishMetadata = metadata }
            }
            #expect(finishMetadata?["anthropic"]?["usage"]?["input_tokens"] == 1)
            #expect((finishMetadata?["minimax"] != nil) == (reasoning != nil))
        }
    }

    @Test(arguments: [".", "..", "task/a?x#y"])
    func videoPollingIDsRemainOnePathSegment(_ taskID: String) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"task":{"id":"task","status":"processing"}}"#))
        let provider = try AIProviders.miniMax(configuration: MiniMaxProviderSettings(apiKey: "key", transport: transport))
        let model = try #require(try provider.videoModel("MiniMax-Hailuo-2.3") as? any AsyncVideoModel)
        _ = try await model.videoGenerationStatus(VideoGenerationOperationStatusRequest(operation: ["taskId": .string(taskID), "resolvedInputs": ["imageCount": 0, "referenceVideoIndices": []]]))
        let url = try #require(await transport.requests().first?.url.absoluteString)
        let encoded = taskID == "." ? "%252E" : taskID == ".." ? "%252E%252E" : "task%2Fa%3Fx%23y"
        #expect(url == "https://api.minimax.io/v2/query/video_generation/\(encoded)")
    }

    @Test func generatedVideoPollAlsoEncodesTaskID() async throws {
        let transport = RecordingTransport(responses: [
            jsonResponse(#"{"task_id":"abc/../../internal"}"#),
            jsonResponse(#"{"task":{"status":"succeeded","content":{"url":"https://example.com/result.mp4"}}}"#)
        ])
        let provider = try AIProviders.miniMax(configuration: MiniMaxProviderSettings(apiKey: "key", transport: transport))
        let result = try await provider.videoModel("MiniMax-H3").generateVideo(VideoGenerationRequest(prompt: "A sunrise", providerOptions: ["minimax": ["pollIntervalMs": 1, "pollTimeoutMs": 1_000]]))
        #expect(result.urls == ["https://example.com/result.mp4"])
        #expect(await transport.requests().last?.url.absoluteString == "https://api.minimax.io/v2/query/video_generation/abc%2F..%2F..%2Finternal")
    }

    private static let success = jsonResponse(#"{"content":[{"type":"text","text":"ok"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}"#)

    private func call(_ request: LanguageModelRequest, modelID: String = "minimax-m3.1-flash", streaming: Bool = false) async throws -> (JSONValue, [AIWarning]) {
        let response = streaming ? sseResponse("""
        data: {"type":"message_start","message":{"id":"msg","model":"minimax-m3.1-flash","usage":{"input_tokens":1,"output_tokens":0}}}

        data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":1}}

        data: {"type":"message_stop"}

        """) : Self.success
        let transport = RecordingTransport(response: response)
        let model = try AIProviders.miniMax(configuration: MiniMaxProviderSettings(apiKey: "key", transport: transport)).languageModel(modelID)
        var warnings: [AIWarning] = []
        if streaming {
            for try await part in model.stream(request) {
                if case let .streamStart(values) = part { warnings = values }
            }
        } else { warnings = try await model.generate(request).warnings }
        let httpRequest = try #require(await transport.requests().first)
        #expect(httpRequest.headers["anthropic-beta"]?.contains("files-api") != true)
        return (try decodeJSONBody(try #require(httpRequest.body)), warnings)
    }

    private func rejectsBeforeIO(_ part: AIContentPart, missingReference: Bool = false) async throws {
        for streaming in [false, true] {
            let transport = RecordingTransport(response: Self.success)
            let model = try AIProviders.miniMax(configuration: MiniMaxProviderSettings(apiKey: "key", transport: transport)).languageModel("minimax-m3.1-flash")
            let request = LanguageModelRequest(messages: [AIMessage(role: .user, content: [part])])
            if missingReference {
                await #expect(throws: AINoSuchProviderReferenceError.self) {
                    if streaming { for try await _ in model.stream(request) {} }
                    else { _ = try await model.generate(request) }
                }
            } else {
                await #expect(throws: AIError.self) {
                    if streaming { for try await _ in model.stream(request) {} }
                    else { _ = try await model.generate(request) }
                }
            }
            #expect(await transport.requests().isEmpty)
        }
    }
}
