import Foundation
import Testing
@testable import SwiftAIGoogleVertex
import SwiftAIProvider
import SwiftAIProviderUtilities
import SwiftAITransport

@Suite struct Weekly20261108VertexTests {
    @Test func originalFactoryFunctionReferencesRemainAvailable() throws {
        let providerFactory: (GoogleVertexProviderSettings) throws -> GoogleVertexProvider = GoogleVertexProvider.init(settings:)
        let settingsFactory = GoogleVertexHostedProviderSettings.init(apiKey:baseURL:headers:queryParams:transport:includeUsage:supportsStructuredOutputs:supportsMultiPartToolContent:maxEmbeddingsPerCall:transformRequestBody:transformRequestBodyWithWarnings:apiKeyProvider:)
        let settings = settingsFactory("key", nil, [:], [:], URLSessionTransport.shared, false, false, false, nil, nil, nil, nil)
        #expect(!settings.supportsNativeStructuredOutput)
        #expect(try providerFactory(.init(apiKey: "key")).providerID == "google.vertex")
    }

    @Test func geminiFactoryUsesGenerateContentAndSharedWordTimings() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"candidates":[{"content":{"parts":[{"text":"Hello world"},{"audioTranscription":{"text":"fallback","languageCode":"en-US","words":[{"word":"Hello","startOffset":"0s","endOffset":"0.45s"},{"word":"world","startOffset":"0.5s","endOffset":"1.2s"},{"word":"invalid","startOffset":"oops","endOffset":"2s"}]}}]}}],"usageMetadata":{"promptTokenCount":4}}"#))
        let provider = try GoogleVertexProvider(settings: .init(project: "project", location: "global", accessToken: "token", transport: transport, date: { Date(timeIntervalSince1970: 123) }))
        let model = try provider.transcriptionModel("gemini-3.5-transcribe")
        #expect(model is GoogleVertexGeminiTranscriptionModel)
        let result = try await model.transcribe(.init(audio: Data([1, 2]), mimeType: "audio/ogg", providerOptions: ["googleVertex": ["mode": "SMART", "customVocabulary": ["Swift"]], "vertex": ["wordTimestamp": false]], timestampGranularities: [.word, .segment]))
        #expect(result.text == "Hello world" && result.language == "en-US")
        #expect(result.words == [.init(text: "Hello", startSecond: 0, endSecond: 0.45), .init(text: "world", startSecond: 0.5, endSecond: 1.2)])
        #expect(result.segments == result.words)
        #expect(result.usage == ["promptTokenCount": 4])
        #expect(result.providerMetadata["google"]?["usageMetadata"] == ["promptTokenCount": 4])
        #expect(result.responseMetadata.timestamp == Date(timeIntervalSince1970: 123))
        #expect(result.warnings.count == 1 && result.warnings.first?.feature == "timestampGranularities")
        let request = try #require(await transport.requests().first)
        #expect(request.url.absoluteString.hasSuffix("/models/gemini-3.5-transcribe:generateContent"))
        #expect(request.headers["Authorization"] == "Bearer token")
        let body = try decodeJSONBody(#require(request.body))
        #expect(body["contents"]?[0]?["parts"]?[0]?["inlineData"] == ["mimeType": "audio/ogg", "data": "AQI="])
        #expect(body["generationConfig"]?["audioTranscriptionConfig"] == ["mode": "SMART", "customVocabulary": ["Swift"], "wordTimestamp": true])
    }

    @Test func wordOverrideMissingTimingsAndEmptyNamespaceRemainDistinct() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"candidates":[{"content":{"parts":[{"audioTranscription":{"text":"spoken"}}]}}]}"#))
        let provider = try GoogleVertexProvider(settings: .init(apiKey: "key", transport: transport))
        let model = try provider.transcriptionModel("gemini-3.5-transcribe")
        let overridden = try await model.transcribe(.init(audio: Data(), providerOptions: ["googleVertex": ["wordTimestamp": false]], timestampGranularities: [.word]))
        #expect(overridden.words == nil && overridden.segments.isEmpty)
        #expect(overridden.warnings.count == 1 && overridden.warnings.first?.type == "unsupported")
        let missing = try await model.transcribe(.init(audio: Data(), timestampGranularities: [.word]))
        #expect(missing.warnings.count == 1 && missing.warnings.first?.type == "other")
        _ = try await model.transcribe(.init(audio: Data(), providerOptions: ["googleVertex": [:], "vertex": ["wordTimestamp": true]]))
        let body = try decodeJSONBody(#require(await transport.requests().last?.body))
        #expect(body["generationConfig"] == nil)
        await #expect(throws: AIError.self) { _ = try await model.transcribe(.init(audio: Data(), providerOptions: ["googleVertex": ["mode": "BAD"]])) }
    }

    @Test func transcriptionModesRejectWrongTransportBeforeNetwork() async throws {
        let transport = RecordingTransport(response: jsonResponse("{}"))
        let provider = try GoogleVertexProvider(settings: .init(project: "p", location: "global", accessToken: "token", transport: transport))
        let live = try provider.transcriptionModel("gemini-3.5-transcribe-live")
        await #expect(throws: AIError.self) { _ = try await live.transcribe(.init(audio: Data())) }
        let unary = try #require(try provider.transcriptionModel("gemini-3.5-transcribe") as? GoogleVertexGeminiTranscriptionModel)
        await #expect(throws: AIError.self) { _ = try await unary.stream(.init(audio: .chunks([]), inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 16_000))) }
        #expect(await transport.requests().isEmpty)
    }

    @Test func vertexVideoPreservesSeedZero() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"name":"operations/zero","done":true,"response":{"videos":[{"bytesBase64Encoded":"AQI=","mimeType":"video/mp4"}]}}"#))
        let provider = try GoogleVertexProvider(settings: .init(apiKey: "key", baseURL: "https://example.com", transport: transport))
        _ = try await provider.videoModel("veo-3.1").generateVideo(.init(prompt: "paint", seed: 0))
        #expect(try decodeJSONBody(#require(await transport.requests().first?.body))["parameters"]?["seed"] == 0)
    }

    @Test func nativeStructuredOutputFollowsVersionedClaudeModels() async throws {
        let models = [("claude-sonnet-4-5@20250929", true), ("claude-opus-4-6", true), ("claude-sonnet-5", true), ("claude-sonnet-4@20250514", false), ("claude-sonnet-4-1", false), ("claude-custom", false)]
        for (id, supported) in models {
            let transport = RecordingTransport(response: jsonResponse(#"{"id":"m","type":"message","role":"assistant","model":"claude","content":[{"type":"text","text":"{}"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}"#))
            let provider = try GoogleVertexHostedProvider(endpoint: .anthropic, configuration: .init(apiKey: "token", baseURL: "https://example.com", transport: transport, supportsNativeStructuredOutput: true))
            let result = try await provider.languageModel(id).generate(.init(messages: [.user("json")], responseFormat: .json(schema: ["type": "object", "properties": ["value": ["type": "string"]]])))
            let body = try decodeJSONBody(#require(await transport.requests().first?.body))
            #expect((body["output_config"]?["format"] != nil) == supported)
            if !supported { #expect(!result.warnings.isEmpty || body["tools"] != nil) }
        }
        let provider = try GoogleVertexProvider(settings: .init(apiKey: "key"))
        #expect(try await provider.imageModel("gemini-nano-banana-2.1").supportsFileInputs == true)
    }

    @Test func nativeOutputRequiresOptInAndMaaSDownloadsExcludeCredentials() async throws {
        let message = #"{"id":"m","type":"message","role":"assistant","model":"claude","content":[{"type":"text","text":"{}"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}"#
        let outputTransport = RecordingTransport(response: jsonResponse(message))
        let anthropic = try GoogleVertexHostedProvider(endpoint: .anthropic, configuration: .init(apiKey: "token", baseURL: "https://example.com", transport: outputTransport))
        _ = try await anthropic.languageModel("claude-sonnet-4-5").generate(.init(messages: [.user("json")], responseFormat: .json(schema: ["type": "object"])))
        #expect(try decodeJSONBody(#require(await outputTransport.requests().first?.body))["output_config"]?["format"] == nil)

        let keys = VertexWeeklyKeys()
        let transport = RecordingTransport(responses: [jsonResponse(#"{"data":[{"url":"https://images.example/generated.png"}]}"#), .init(statusCode: 200, headers: ["content-type": "image/png"], body: Data([1, 2]))])
        let maas = try GoogleVertexHostedProvider(endpoint: .maaS, configuration: .init(baseURL: "https://vertex.example/openapi", transport: transport, apiKeyProvider: { await keys.next() }))
        let image = try await maas.imageModel("image").generateImage(.init(prompt: "paint"))
        #expect(image.base64Images == ["AQI="])
        let requests = await transport.requests()
        #expect(requests.count == 2)
        #expect(normalizeHeaders(requests[0].headers)["authorization"] == "Bearer token-1")
        #expect(requests[1].headers["authorization"] == nil && requests[1].headers["Authorization"] == nil)
        #expect(await keys.count == 1)
    }
}

private actor VertexWeeklyKeys {
    var count = 0
    func next() -> String { count += 1; return "token-\(count)" }
}

@Suite struct Weekly20261108VertexLiveTests {
    private func provider(_ socket: VertexWeeklySocketTransport) throws -> GoogleVertexProvider {
        try GoogleVertexProvider(settings: .init(project: "project", location: "eu", accessToken: "token", headers: ["x-client": "native"]), webSocketTransport: socket)
    }

    @Test func setupAcknowledgementGatesAudioAndFinalizesRevisedTranscripts() async throws {
        let socket = VertexWeeklySocketTransport()
        let model = try provider(socket).streamingTranscriptionModel("gemini-3.5-transcribe-live")
        let result = try await model.stream(.init(audio: .chunks([Data([1, 2])]), inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 16_000), providerOptions: ["vertex": ["mode": "SMART"]], includeRawChunks: true))
        let consumer = Task { () throws -> [StreamingTranscriptionPart] in var parts: [StreamingTranscriptionPart] = []; for try await part in result.stream { parts.append(part) }; return parts }
        socket.connection.emit(.opened(protocol: nil))
        try await socket.connection.waitForCount(1)
        #expect(socket.connection.messages().count == 1)
        let setup = socket.connection.messages()[0]
        #expect(setup["setup"]?["model"] == "projects/project/locations/eu/publishers/google/models/gemini-3.5-transcribe-live")
        #expect(setup["setup"]?["generationConfig"] == nil)
        #expect(setup["setup"]?["inputAudioTranscription"] == ["mode": "SMART"])
        socket.connection.json(["setupComplete": [:]])
        try await socket.connection.waitForCount(3)
        #expect(socket.connection.messages()[1] == ["realtimeInput": ["audio": ["data": "AQI=", "mimeType": "audio/pcm;rate=16000"]]])
        #expect(socket.connection.messages()[2] == ["realtimeInput": ["audioStreamEnd": true]])
        socket.connection.json(["serverContent": ["interimInputTranscription": ["text": "draft"]]])
        socket.connection.json(["serverContent": ["inputTranscription": ["text": "Hello", "languageCode": "en", "finished": false]]])
        socket.connection.json(["serverContent": ["inputTranscription": ["text": " world", "finished": true]]])
        socket.connection.json(["usageMetadata": ["promptTokenCount": 7]])
        socket.connection.json(["serverContent": ["turnComplete": true]])
        let parts = try await consumer.value
        #expect(parts.contains(.transcriptPartial(id: "google-segment-0", text: "draft")))
        #expect(parts.contains(.transcriptFinal(id: "google-segment-0", text: "Hello world")))
        let finish = try #require(parts.compactMap { if case let .finish(value) = $0 { value } else { nil } }.first)
        #expect(finish.text == "Hello world" && finish.language == "en")
        #expect(finish.usage == ["promptTokenCount": 7])
        #expect(parts.contains { if case .raw = $0 { true } else { false } })
        let request = try #require(socket.requests().first)
        #expect(request.url.absoluteString == "wss://aiplatform.eu.rep.googleapis.com/ws/google.cloud.aiplatform.v1.LlmBidiService/BidiGenerateContent")
        #expect(request.headers["Authorization"] == "Bearer token" && request.headers["x-client"] == "native")
    }

    @Test func cancellationStopsUnacknowledgedAudioAndClosesSocket() async throws {
        let socket = VertexWeeklySocketTransport()
        let pipe = AIStreamingAudioInput.makeStream()
        let result = try await provider(socket).streamingTranscriptionModel("gemini-3.5-transcribe-live").stream(.init(audio: pipe.input, inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 16_000)))
        let consumer = Task { for try await _ in result.stream { } }
        socket.connection.emit(.opened(protocol: nil))
        try await socket.connection.waitForCount(1)
        result.cancel()
        try await consumer.value
        #expect(pipe.writer.send(Data([1])) == .terminated)
        #expect(socket.connection.messages().count == 1)
    }

    @Test func preSetupProviderErrorFailsInsteadOfSendingAudio() async throws {
        let socket = VertexWeeklySocketTransport()
        let result = try await provider(socket).streamingTranscriptionModel("gemini-3.5-transcribe-live").stream(.init(audio: .chunks([Data([1])]), inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 16_000)))
        socket.connection.emit(.opened(protocol: nil))
        socket.connection.json(["error": ["message": "denied"]])
        await #expect(throws: AIStreamingTranscriptionError.self) { for try await _ in result.stream { } }
        #expect(socket.connection.messages().count == 1)
    }

    @Test func invalidAudioFormatAndAPIKeyFailBeforeConnect() async throws {
        let socket = VertexWeeklySocketTransport()
        let model = try provider(socket).streamingTranscriptionModel("gemini-3.5-transcribe-live")
        for format in [AIStreamingAudioFormat(mediaType: "audio/wav", sampleRate: 16_000), .init(mediaType: "audio/pcm", sampleRate: 24_000)] {
            await #expect(throws: AIError.self) { _ = try await model.stream(.init(audio: .chunks([]), inputAudioFormat: format)) }
        }
        let express = try GoogleVertexProvider(settings: .init(apiKey: "key"), webSocketTransport: socket)
        await #expect(throws: AIError.self) { _ = try await express.streamingTranscriptionModel("gemini-3.5-transcribe-live").stream(.init(audio: .chunks([]), inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 16_000))) }
        #expect(socket.requests().isEmpty)
    }

    @Test func quietGraceUsesTheLatestRevisableInterimAndUsage() async throws {
        let socket = VertexWeeklySocketTransport()
        let config = GoogleVertexConfig(providerID: "google.vertex.transcription", baseURL: "https://example.com", project: "project", location: "global", headers: [:], auth: .accessToken("token"), transport: RecordingTransport(response: jsonResponse("{}")), date: Date.init, toolResultDownloadsMaxBytes: 1_024)
        let model = GoogleVertexGeminiTranscriptionModel(modelID: "gemini-3.5-transcribe-live", config: config, webSocketTransport: socket, finishGraceMilliseconds: 50)
        let result = try await model.stream(.init(audio: .chunks([]), inputAudioFormat: .init(mediaType: "audio/pcm")))
        let consumer = Task { () throws -> [StreamingTranscriptionPart] in var parts: [StreamingTranscriptionPart] = []; for try await part in result.stream { parts.append(part) }; return parts }
        socket.connection.emit(.opened(protocol: nil)); socket.connection.json(["setupComplete": [:]])
        try await socket.connection.waitForCount(2)
        socket.connection.json(["serverContent": ["interimInputTranscription": ["text": "draft"]]])
        socket.connection.json(["serverContent": ["interimInputTranscription": ["text": "corrected"]]])
        socket.connection.json(["usageMetadata": ["promptTokenCount": 0]])
        let parts = try await consumer.value
        let finish = try #require(parts.compactMap { if case let .finish(value) = $0 { value } else { nil } }.first)
        #expect(finish.text == "corrected" && finish.usage == ["promptTokenCount": 0])
        #expect(parts.contains(.transcriptFinal(id: "google-segment-0", text: "corrected")))
    }

    @Test func abortBeforeSetupCancelsInputAndThrowsAbortError() async throws {
        let socket = VertexWeeklySocketTransport()
        let abort = AIAbortController()
        let pipe = AIStreamingAudioInput.makeStream()
        let result = try await provider(socket).streamingTranscriptionModel("gemini-3.5-transcribe-live").stream(.init(audio: pipe.input, inputAudioFormat: .init(mediaType: "audio/pcm"), abortSignal: abort.signal))
        let consumer = Task { for try await _ in result.stream { } }
        socket.connection.emit(.opened(protocol: nil))
        try await socket.connection.waitForCount(1)
        abort.abort(reason: "stop")
        await #expect(throws: AIAbortError.self) { try await consumer.value }
        #expect(pipe.writer.send(Data([1])) == .terminated)
    }
}

private final class VertexWeeklySocketTransport: AIDuplexWebSocketTransport, @unchecked Sendable {
    let connection = VertexWeeklySocket()
    private let lock = NSLock()
    private var recorded: [AIDuplexWebSocketRequest] = []
    func connect(_ request: AIDuplexWebSocketRequest) async throws -> any AIDuplexWebSocketConnection { lock.withLock { recorded.append(request) }; return connection }
    func requests() -> [AIDuplexWebSocketRequest] { lock.withLock { recorded } }
}

private final class VertexWeeklySocket: AIDuplexWebSocketConnection, @unchecked Sendable {
    let events: AsyncThrowingStream<AIDuplexWebSocketEvent, Error>
    private let continuation: AsyncThrowingStream<AIDuplexWebSocketEvent, Error>.Continuation
    private let lock = NSLock()
    private var sent: [JSONValue] = []
    init() { let pair = AsyncThrowingStream<AIDuplexWebSocketEvent, Error>.makeStream(); events = pair.stream; continuation = pair.continuation }
    func emit(_ event: AIDuplexWebSocketEvent) { continuation.yield(event) }
    func json(_ value: JSONValue) { continuation.yield(.message(.text(String(decoding: (try? encodeJSONBody(value)) ?? Data(), as: UTF8.self)))) }
    func send(_ message: AIDuplexWebSocketMessage) async throws { if case let .text(text) = message { let value = try secureJSONParse(text); lock.withLock { sent.append(value) } } }
    func close(code: Int, reason: Data?) async { continuation.finish() }
    func messages() -> [JSONValue] { lock.withLock { sent } }
    func waitForCount(_ count: Int) async throws {
        for _ in 0..<1_000 { if messages().count >= count { return }; try await Task.sleep(nanoseconds: 1_000_000) }
        Issue.record("Expected \(count) socket sends, observed \(messages().count)")
        throw AIError.invalidResponse(provider: "test", message: "Socket send timeout")
    }
}
