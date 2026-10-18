import Foundation
import Testing
@testable import SwiftAISDK

@Suite("WeeklyGoogle20261018")
struct WeeklyGoogle20261018Tests {
    private let first = #"{"candidates":[{"content":{"parts":[{"text":"Hello"}]},"finishReason":"CONTINUATION","continuationToken":"token-1"}],"usageMetadata":{"promptTokenCount":10,"candidatesTokenCount":5,"thoughtsTokenCount":20,"totalTokenCount":35,"promptTokensDetails":[{"modality":"TEXT","tokenCount":10}]}}"#
    private let last = #"{"responseId":"last","candidates":[{"content":{"parts":[{"text":", world"}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":35,"candidatesTokenCount":7,"totalTokenCount":42,"serviceTier":"priority","promptTokensDetails":[{"modality":"TEXT","tokenCount":30},{"modality":"IMAGE","tokenCount":5}]}}"#

    private func model(_ vertex: Bool, transport: any AITransport) throws -> any LanguageModel {
        if vertex { return try AIProviders.googleVertex(settings: GoogleVertexProviderSettings(apiKey: "key", transport: transport)).languageModel("gemini-4-argon") }
        return try AIProviders.google(settings: ProviderSettings(apiKey: "key", transport: transport)).languageModel("gemini-4-argon")
    }

    @Test(arguments: [false, true])
    func automaticallyContinuesGenerationAndSumsBillingUsage(_ vertex: Bool) async throws {
        let transport = RecordingTransport(responses: [jsonResponse(first), jsonResponse(last, headers: ["x-final": "yes"])])
        let result = try await model(vertex, transport: transport).generate(LanguageModelRequest(messages: [.user("Hello")], maxOutputTokens: 100_000))
        #expect(result.text == "Hello, world")
        #expect(result.content.compactMap { if case let .text(text, _) = $0 { text } else { nil } } == ["Hello", ", world"])
        #expect(result.finishReason == "stop")
        #expect(result.usage?.inputTokens == 45 && result.usage?.outputTokens == 32)
        #expect(result.usage?.outputTextTokens == 12 && result.usage?.outputReasoningTokens == 20)
        #expect(result.usage?.totalTokens == 77)
        #expect(result.providerMetadata["google"]?["initialPromptTokenCount"] == 10)
        #expect(result.providerMetadata["google"]?["continuationToken"] == nil)
        #expect(result.providerMetadata["google"]?["usageMetadata"]?["promptTokensDetails"] == [["modality": "TEXT", "tokenCount": 40], ["modality": "IMAGE", "tokenCount": 5]])
        #expect(result.responseMetadata.id == "last" && result.responseMetadata.headers["x-final"] == "yes")
        let requests = await transport.requests()
        #expect(requests.count == 2)
        let initial = try decodeJSONBody(try #require(requests[0].body))
        var expected = initial.objectValue ?? [:]
        expected["continuationToken"] = "token-1"
        #expect(try decodeJSONBody(try #require(requests[1].body)) == .object(expected))
        #expect(initial["generationConfig"]?["maxOutputTokens"] == 100_000)
        #expect(initial["continuationToken"] == nil)
    }

    @Test(arguments: [false, true])
    func automaticallyContinuesStreamingWithOneLifecycle(_ vertex: Bool) async throws {
        let transport = RecordingTransport(responses: [sseResponse("data: " + first), sseResponse("data: " + last)])
        var parts: [LanguageStreamPart] = []
        for try await part in try model(vertex, transport: transport).stream(LanguageModelRequest(messages: [.user("Hello")], maxOutputTokens: 100_000, includeRawChunks: true)) { parts.append(part) }
        #expect(parts.filter { if case .textStart = $0 { true } else { false } }.count == 1)
        #expect(parts.filter { if case .textEnd = $0 { true } else { false } }.count == 1)
        #expect(parts.filter { if case .streamStart = $0 { true } else { false } }.count == 1)
        #expect(parts.compactMap { if case let .textDeltaPart(_, text, _) = $0 { text } else { nil } } == ["Hello", ", world"])
        #expect(parts.filter { if case .raw = $0 { true } else { false } }.count == 2)
        guard case let .finishMetadata(reason, usage, metadata) = try #require(parts.last) else { Issue.record("Missing finish"); return }
        #expect(reason == "stop")
        #expect(usage?.inputTokens == 45 && usage?.outputTokens == 32)
        #expect(metadata["google"]?["initialPromptTokenCount"] == 10)
        #expect(metadata["google"]?["continuationToken"] == nil)
        #expect(await transport.requests().count == 2)
        let resumed = try decodeJSONBody(try #require(await transport.requests().last?.body))
        #expect(resumed["continuationToken"] == "token-1")
    }

    @Test(arguments: [false, true])
    func continuationKeepsGeneratedToolAndSourceIdentitiesDistinct(_ stream: Bool) async throws {
        func response(_ reason: String, token: String?, url: String) throws -> String {
            let candidate: JSONValue = ["content": ["parts": [["executableCode": ["language": "PYTHON", "code": "print(1)"]], ["codeExecutionResult": ["outcome": "OUTCOME_OK", "output": "1"]]]], "finishReason": .string(reason), "continuationToken": token.map(JSONValue.string) ?? .null, "groundingMetadata": ["groundingChunks": [["web": ["uri": .string(url)]]]]]
            return String(decoding: try encodeJSONBody(["candidates": [candidate]]), as: UTF8.self)
        }
        let first = try response("CONTINUATION", token: "next", url: "https://one.example")
        let last = try response("STOP", token: nil, url: "https://two.example")
        let transport = RecordingTransport(responses: stream ? [sseResponse("data: " + first), sseResponse("data: " + last)] : [jsonResponse(first), jsonResponse(last)])
        let target = try model(false, transport: transport)
        var calls: [String] = [], results: [String] = [], sources: [String] = []
        if stream {
            for try await part in target.stream(LanguageModelRequest(messages: [.user("Hi")])) {
                if case let .toolCall(call) = part { calls.append(call.id) }
                if case let .toolResult(result) = part { results.append(result.toolCallID) }
                if case let .source(source) = part { sources.append(source.id) }
            }
        } else {
            let result = try await target.generate(LanguageModelRequest(messages: [.user("Hi")]))
            calls = result.toolCalls.map(\.id); results = result.toolResults.map(\.toolCallID); sources = result.sources.map(\.id)
        }
        #expect(calls.count == 2 && Set(calls).count == 2 && calls == results)
        #expect(sources.count == 2 && Set(sources).count == 2)
    }

    @Test(arguments: [false, true])
    func maxTokensAllowsManualResumeWithoutAutomaticRequest(_ stream: Bool) async throws {
        let partial = #"{"candidates":[{"content":{"parts":[{"text":"Partial"}]},"finishReason":"MAX_TOKENS","continuationToken":"next"}]}"#
        let transport = RecordingTransport(response: stream ? sseResponse("data: " + partial) : jsonResponse(partial))
        let request = LanguageModelRequest(messages: [.user("Hello")], maxOutputTokens: 200_000, providerOptions: ["google": ["continuationToken": "previous", "responseModalities": ["TEXT", "AUDIO"]]])
        let target = try model(false, transport: transport)
        var metadata: [String: JSONValue] = [:]
        if stream {
            for try await part in target.stream(request) { if case let .finishMetadata(reason, _, value) = part { #expect(reason == "length"); metadata = value } }
        } else {
            let result = try await target.generate(request)
            #expect(result.finishReason == "length")
            metadata = result.providerMetadata
        }
        #expect(metadata["google"]?["continuationToken"] == "next")
        #expect(metadata["google"]?["initialPromptTokenCount"] == nil)
        #expect(await transport.requests().count == 1)
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["continuationToken"] == "previous")
        #expect(body["generationConfig"]?["responseModalities"] == ["TEXT", "AUDIO"])
    }

    @Test(arguments: [JSONValue.null, true, 1, [:]])
    func invalidContinuationTokensFailBeforeIO(_ token: JSONValue) async throws {
        let transport = RecordingTransport(response: jsonResponse(last))
        for vertex in [false, true] {
            await #expect(throws: AIError.self) { _ = try await model(vertex, transport: transport).generate(LanguageModelRequest(messages: [.user("Hi")], providerOptions: ["google": ["continuationToken": token]])) }
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test(arguments: [false, true])
    func failedContinuationRetainsResumableTokenAndUsage(_ vertex: Bool) async throws {
        let failed = AIHTTPResponse(statusCode: 400, headers: ["x-error": "yes"], body: Data(#"{"error":{"code":400,"message":"Invalid continuation token","status":"INVALID_ARGUMENT"}}"#.utf8))
        let transport = RecordingTransport(responses: [sseResponse("data: " + first), failed])
        var errors = 0
        var finished = false
        for try await part in try model(vertex, transport: transport).stream(LanguageModelRequest(messages: [.user("Hello")])) {
            if case .error = part { errors += 1 }
            if case let .finishMetadata(reason, usage, metadata) = part {
                finished = true
                #expect(reason == "length" && usage?.inputTokens == 10)
                #expect(metadata["google"]?["continuationToken"] == "token-1")
            }
        }
        #expect(errors == 1 && finished)
        let unary = RecordingTransport(responses: [jsonResponse(first), failed])
        await #expect(throws: AIError.self) { _ = try await model(vertex, transport: unary).generate(LanguageModelRequest(messages: [.user("Hello")])) }
    }

    @Test func successfulStreamOmitsCheckpointTokensAndSingleRequestPromptCounts() async throws {
        let transport = RecordingTransport(response: sseResponse("""
        data: {"candidates":[{"content":{"parts":[{"text":"Hello"}]},"continuationToken":"checkpoint"}]}

        data: {"candidates":[{"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":10}}
        """))
        for try await part in try model(false, transport: transport).stream(LanguageModelRequest(messages: [.user("Hi")])) {
            if case let .finishMetadata(reason, _, metadata) = part {
                #expect(reason == "stop")
                #expect(metadata["google"]?["continuationToken"] == nil)
                #expect(metadata["google"]?["initialPromptTokenCount"] == nil)
            }
        }
        #expect(await transport.requests().count == 1)
    }

    @Test func audioResponseModalitiesRetainGeneratedFileContent() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"candidates":[{"content":{"parts":[{"inlineData":{"mimeType":"audio/wav","data":"AQID"}}]},"finishReason":"STOP"}]}"#))
        let result = try await model(false, transport: transport).generate(LanguageModelRequest(messages: [.user("Speak")], providerOptions: ["google": ["responseModalities": ["AUDIO"]]]))
        #expect(result.files.count == 1)
        #expect(result.files.first?.mediaType == "audio/wav" && result.files.first?.data == Data([1, 2, 3]))
    }

    @Test(arguments: [400, 408, 409, 429, 503])
    func normalizesInBandStreamErrors(_ code: Int) async throws {
        let transport = RecordingTransport(response: sseResponse("""
        data: {"candidates":[{"content":{"parts":[{"text":"Partial"}]}}],"usageMetadata":{"promptTokenCount":10,"candidatesTokenCount":2}}

        data: {"error":{"code":\(code),"message":"Provider failed","status":"ERROR_STATUS","details":[{"reason":"quota"}]}}
        """))
        var error: AIStreamProviderError?
        var finish: String?
        for try await part in try model(false, transport: transport).stream(LanguageModelRequest(messages: [.user("Hello")])) {
            if let value = part.streamProviderError { error = value }
            if case let .finishMetadata(reason, usage, _) = part { finish = reason; #expect(usage?.inputTokens == 10) }
        }
        #expect(error?.message == "Provider failed" && error?.type == "ERROR_STATUS")
        #expect(error?.statusCode == code && error?.code?.intValue == code)
        #expect(error?.isRetryable == (code != 400))
        #expect(error?.data?["details"]?[0]?["reason"] == "quota")
        #expect(finish == "error")
    }

    @Test(arguments: [false, true])
    func abortedRequestsDoNotStartOrContinue(_ stream: Bool) async throws {
        let controller = AIAbortController()
        controller.abort()
        let transport = RecordingTransport(response: jsonResponse(first))
        let target = try model(false, transport: transport)
        let request = LanguageModelRequest(messages: [.user("Hi")], abortSignal: controller.signal)
        await #expect(throws: AIAbortError.self) {
            if stream { for try await _ in target.stream(request) {} }
            else { _ = try await target.generate(request) }
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func cancellationBetweenGenerationHopsStopsResubmission() async throws {
        let controller = AIAbortController()
        let response = try decodeJSONBody(Data(first.utf8))
        await #expect(throws: AIAbortError.self) {
            _ = try await googleGenerateContentWithContinuation(body: [:], abortSignal: controller.signal) { _ in
                controller.abort()
                return (response, jsonResponse(first))
            }
        }
    }

    @Test func usageMergesEveryModalityDetailAndKeepsLaterMetadata() {
        var first: [String: JSONValue] = ["toolUsePromptTokenCount": 3, "cachedContentTokenCount": 2, "serviceTier": "standard"]
        var last: [String: JSONValue] = ["toolUsePromptTokenCount": 7, "cachedContentTokenCount": 4, "serviceTier": "priority"]
        for key in ["promptTokensDetails", "cacheTokensDetails", "candidatesTokensDetails", "toolUsePromptTokensDetails"] {
            first[key] = [["modality": "TEXT", "tokenCount": 2]]
            last[key] = [["modality": "TEXT", "tokenCount": 3], ["modality": "IMAGE", "tokenCount": 4]]
        }
        let combined = googleAddUsageMetadata(.object(first), .object(last))
        #expect(combined?["toolUsePromptTokenCount"] == 10 && combined?["cachedContentTokenCount"] == 6)
        #expect(combined?["serviceTier"] == "priority")
        for key in ["promptTokensDetails", "cacheTokensDetails", "candidatesTokensDetails", "toolUsePromptTokensDetails"] {
            #expect(combined?[key] == [["modality": "TEXT", "tokenCount": 5], ["modality": "IMAGE", "tokenCount": 4]])
        }
        #expect(googleAddUsageMetadata(nil, .object(last)) == .object(last))
    }

    @Test func thinkingOptionsTakePrecedenceAndDottedGeminiRoutesKeepCapabilities() throws {
        for id in ["eu.gemini-2.5-flash", "au.gemini-4-argon", "publishers/google/models/eu.gemini-3.8-flash"] {
            let capabilities = googleModelCapabilities(for: id)
            #expect(capabilities.supportsGemini2Tools && capabilities.supportsFileSearch)
            #expect(capabilities.usesGemini3Features == !id.contains("gemini-2.5"))
            let prepared = try GoogleGenerativeLanguageModel.generateContentBody(for: LanguageModelRequest(messages: [.user("Hi")], reasoning: "invalid-effort", providerOptions: ["google": ["thinkingConfig": ["thinkingBudget": 999]]]), modelID: id)
            #expect(prepared.body["generationConfig"]?["thinkingConfig"] == ["thinkingBudget": 999])
            #expect(!prepared.warnings.contains { $0.feature == "reasoning" })
        }
    }

    @Test(arguments: ["us.gemini-3.1-pro", "gemini-3.5-pro", "models/eu.gemini-3.8-flash"])
    func currentProAndRoutedFlashModelsHaveLowThinkingFloor(_ id: String) throws {
        for reasoning in ["none", "minimal"] {
            let prepared = try GoogleGenerativeLanguageModel.generateContentBody(for: LanguageModelRequest(messages: [.user("Hi")], reasoning: reasoning), modelID: id)
            #expect(prepared.body["generationConfig"]?["thinkingConfig"]?["thinkingLevel"] == "low")
        }
    }

    @Test(arguments: [false, true])
    func backgroundModelInteractionsPollUntilCompleted(_ vertex: Bool) async throws {
        let transport = RecordingTransport(responses: [jsonResponse(#"{"id":"interaction","status":"in_progress"}"#), jsonResponse(#"{"id":"interaction","status":"completed","steps":[{"type":"model_output","content":[{"type":"text","text":"long answer"}]}],"usage":{"total_input_tokens":5,"total_output_tokens":100000,"total_tokens":100005}}"#)])
        let target: any LanguageModel = vertex
            ? try AIProviders.googleVertex(settings: GoogleVertexProviderSettings(project: "project", location: "global", accessToken: "key", transport: transport)).interactionsModel("gemini-4-argon")
            : try AIProviders.google(settings: ProviderSettings(apiKey: "key", transport: transport)).interactionsModel("gemini-4-argon")
        let result = try await target.generate(LanguageModelRequest(messages: [.user("Research")], maxOutputTokens: 200_000, providerOptions: ["google": ["background": true]]))
        #expect(result.text == "long answer" && result.finishReason == "stop")
        #expect(result.usage?.outputTokens == 100_000)
        let requests = await transport.requests()
        #expect(requests.map(\.method) == ["POST", "GET"])
        #expect(requests[1].url.path.hasSuffix("/interactions/interaction"))
    }

    @Test(arguments: [false, true])
    func vertexAnthropicLabelsArePerCallUTF8Headers(_ stream: Bool) async throws {
        let transport = RecordingTransport(response: stream ? sseResponse("data: {\"type\":\"message_stop\"}") : jsonResponse(#"{"content":[{"type":"text","text":"ok"}],"stop_reason":"end_turn"}"#))
        let target = try AIProviders.googleVertexAnthropic(project: "project", settings: ProviderSettings(apiKey: "key", headers: ["x-custom": "kept"], transport: transport)).languageModel("claude-sonnet-4-6@default")
        for (options, headers) in [(["vertex": JSONValue.object(["labels": ["team": "équipe"]])], [String: String]()), ([:], [:]), (["vertex": .object(["labels": [:]])], ["X-Vertex-AI-Labels": "explicit"])] {
            let request = LanguageModelRequest(messages: [.user("Hi")], providerOptions: options, headers: headers)
            if stream { for try await _ in target.stream(request) {} } else { _ = try await target.generate(request) }
        }
        let requests = await transport.requests()
        let encoded = try #require(requests[0].headers.first { $0.key.lowercased() == "x-vertex-ai-labels" }?.value)
        #expect(try decodeJSONBody(try #require(Data(base64Encoded: encoded))) == ["team": "équipe"])
        #expect(requests[0].headers["x-custom"] == "kept")
        #expect(requests[0].headers.values.contains("Bearer key"))
        #expect(!requests[1].headers.keys.contains { $0.lowercased() == "x-vertex-ai-labels" })
        #expect(requests[2].headers.first { $0.key.lowercased() == "x-vertex-ai-labels" }?.value == "explicit")
        #expect(try decodeJSONBody(try #require(requests[0].body))["labels"] == nil)
    }

    @Test(arguments: [JSONValue.null, "invalid", ["team": 123], ["team"]])
    func vertexAnthropicRejectsInvalidLabelsBeforeIO(_ labels: JSONValue) async throws {
        let transport = RecordingTransport(response: jsonResponse("{}"))
        let target = try AIProviders.googleVertexAnthropic(project: "project", settings: ProviderSettings(apiKey: "key", transport: transport)).languageModel("claude-sonnet-4-6@default")
        await #expect(throws: AIError.self) { _ = try await target.generate(LanguageModelRequest(messages: [.user("Hi")], providerOptions: ["vertex": ["labels": labels]])) }
        #expect(await transport.requests().isEmpty)
    }

    private func bflTransport() -> RecordingTransport {
        RecordingTransport(responses: [jsonResponse(#"{"id":"image","polling_url":"https://api.bfl.ai/v1/result"}"#), jsonResponse(#"{"status":"Ready","result":{"sample":"https://images.example/image.png"}}"#), AIHTTPResponse(statusCode: 200, body: Data([1, 2, 3]))])
    }

    @Test(arguments: ["flux-3-image-klein", "flux-99-image", "future-image"])
    func latestBFLImagesUseDimensionsAndModernControls(_ id: String) async throws {
        let transport = bflTransport()
        let target = try AIProviders.blackForestLabs(settings: ProviderSettings(apiKey: "key", transport: transport)).imageModel(id)
        let result = try await target.generateImage(ImageGenerationRequest(prompt: "cat", size: "1024x1024", aspectRatio: "3:1", seed: 42, files: [ImageInputFile(data: Data([1, 2, 3]), mediaType: "image/png")], providerOptions: ["blackForestLabs": ["width": 6256, "height": 2688, "resolution": "4k", "steps": 16, "outputFormat": "png", "safetyTolerance": 7]]))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body == ["prompt": "cat", "width": 6256, "height": 2688, "seed": 42, "steps": 16, "output_format": "png", "safety_tolerance": 7, "images": ["AQID"]])
        #expect(result.warnings.isEmpty)
        #expect(await target.supportsFileInputs == true)
        #expect(await target.supportsMaskInputs == false)
    }

    @Test(arguments: ["768x768", "1024x64", "4096x4096"])
    func latestBFLFillsDimensionsFromSize(_ size: String) async throws {
        let transport = bflTransport()
        let target = try AIProviders.blackForestLabs(settings: ProviderSettings(apiKey: "key", transport: transport)).imageModel("flux-3-image-klein")
        let result = try await target.generateImage(ImageGenerationRequest(prompt: "cat", size: size, providerOptions: ["blackForestLabs": size == "1024x64" ? ["width": 64] : [:]]))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["width"]?.intValue == (size == "1024x64" ? 64 : Int(size.split(separator: "x")[0])))
        #expect(body["height"]?.intValue == Int(size.split(separator: "x")[1]))
        #expect(body["aspect_ratio"] == nil && result.warnings.isEmpty)
    }

    @Test(arguments: [JSONValue.object(["width": 63, "height": 64]), ["width": 64, "height": 6257], ["width": 6256, "height": 6256], ["width": 1024], ["height": 1024], ["steps": 0], ["steps": 17], ["safetyTolerance": 8], ["resolution": "8k"]])
    func latestBFLValidatesDimensionsAndControlsBeforeSubmission(_ options: JSONValue) async throws {
        let transport = bflTransport()
        let target = try AIProviders.blackForestLabs(settings: ProviderSettings(apiKey: "key", transport: transport)).imageModel("flux-3-image-klein")
        await #expect(throws: AIError.self) { _ = try await target.generateImage(ImageGenerationRequest(prompt: "cat", providerOptions: ["blackForestLabs": options])) }
        #expect(await transport.requests().isEmpty)
    }

    @Test func latestBFLOmitsUnsupportedFieldsAndNormalizesRatios() async throws {
        let transport = bflTransport()
        let target = try AIProviders.blackForestLabs(settings: ProviderSettings(apiKey: "key", transport: transport)).imageModel("flux-3-image-klein")
        let result = try await target.generateImage(ImageGenerationRequest(prompt: "cat", aspectRatio: "7:3", providerOptions: ["blackForestLabs": ["grounding": false, "version": "latest", "guidance": 4, "inputImage": "AQID"]]))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body == ["prompt": "cat", "aspect_ratio": "21:9"])
        #expect(Set(result.warnings.compactMap(\.feature)) == ["blackForestLabs.grounding", "blackForestLabs.version", "blackForestLabs.guidance", "blackForestLabs.inputImage"])
    }

    @Test(arguments: ["63x64", "6257x64", "4096x4108"])
    func latestBFLRejectsInvalidStandardSizesBeforeIO(_ size: String) async throws {
        let transport = bflTransport()
        let target = try AIProviders.blackForestLabs(settings: ProviderSettings(apiKey: "key", transport: transport)).imageModel("flux-3-image-klein")
        await #expect(throws: AIError.self) { _ = try await target.generateImage(ImageGenerationRequest(prompt: "cat", size: size)) }
        #expect(await transport.requests().isEmpty)
    }

    @Test func latestBFLRejectsMasksAndTooManyReferencesBeforeIO() async throws {
        let transport = bflTransport()
        let target = try AIProviders.blackForestLabs(settings: ProviderSettings(apiKey: "key", transport: transport)).imageModel("flux-3-image-klein")
        let image = ImageInputFile(url: "https://images.example/ref.png")
        await #expect(throws: AIError.self) { _ = try await target.generateImage(ImageGenerationRequest(prompt: "cat", mask: image)) }
        await #expect(throws: AIError.self) { _ = try await target.generateImage(ImageGenerationRequest(prompt: "cat", files: Array(repeating: image, count: 11))) }
        #expect(await transport.requests().isEmpty)
    }

    @Test func baseFLUX3AcceptsSafetySevenAndKeepsLegacyOptionsSeparate() async throws {
        let transport = bflTransport()
        let target = try AIProviders.blackForestLabs(settings: ProviderSettings(apiKey: "key", transport: transport)).imageModel("flux-3-image")
        _ = try await target.generateImage(ImageGenerationRequest(prompt: "cat", providerOptions: ["blackForestLabs": ["safetyTolerance": 7, "grounding": true]]))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body == ["prompt": "cat", "grounding": true, "safety_tolerance": 7])
    }

    @Test(arguments: ["wan2.7-r2v", "wan2.8-r2v", "wan2.10-r2v", "wan2.6-t2v", "wanx2.1-t2v-turbo", "wan4.0-video", "wan10.0-video", "wan-next-video"])
    func alibabaRoutesKnownAndFutureVideoVersions(_ id: String) async throws {
        let transport = RecordingTransport(responses: [jsonResponse(#"{"output":{"task_id":"video"}}"#), jsonResponse(#"{"output":{"task_status":"SUCCEEDED","video_url":"https://images.example/video.mp4"}}"#)])
        let target = try AIProviders.alibaba(settings: ProviderSettings(apiKey: "key", transport: transport)).videoModel(id)
        _ = try await target.generateVideo(VideoGenerationRequest(prompt: "cat", aspectRatio: "16:9", resolution: "1280x720"))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        let legacy = id == "wan2.6-t2v" || id.hasPrefix("wanx")
        #expect(body["parameters"]?[legacy ? "size" : "resolution"] == (legacy ? "1280*720" : "720P"))
        if !legacy { #expect(body["parameters"]?["ratio"] == "16:9") }
    }
}
