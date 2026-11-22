import Foundation
import SwiftAIProvider
import SwiftAITransport
import Testing
@testable import SwiftAIGoogleVertex

// @ai-sdk/google-vertex 5.0.144 gemini-transcription tests at 9b8c25e582bb2ca97e459ba3f8f6b325cb9dfb22.
@Suite struct Weekly20261122VertexTests {
    @Test func finalizesEachSegmentOnGenerationCompleteAndFinishesAtTheAudioEnd() async throws {
        let run = try await makeRun()
        defer { run.result.cancel() }
        run.audio.send(Data(count: 5 * 32_000))
        try await run.socket.waitForCount(2)
        run.activity("ACTIVITY_START", offset: "0.280s")
        run.transcribe("It was delivered into Earth orbit")
        run.generationComplete()
        run.activity("ACTIVITY_END", offset: "2s")
        try await run.received.waitFor(.transcriptFinal(id: "google-segment-0", text: "It was delivered into Earth orbit"))

        run.activity("ACTIVITY_START", offset: "3s")
        run.audio.finish()
        try await run.socket.waitForCount(3)
        #expect(run.socket.messages().last == ["realtimeInput": ["audioStreamEnd": true]])
        #expect(await !run.received.isFinished)

        run.transcribe("on October 18th, 1989.")
        run.generationComplete()
        run.activity("ACTIVITY_END", offset: "5s")

        let parts = try await run.received.waitForFinish()
        #expect(parts == [
            .streamStart(warnings: []),
            .transcriptDelta(id: "google-segment-0", delta: "It was delivered into Earth orbit"),
            .transcriptFinal(id: "google-segment-0", text: "It was delivered into Earth orbit"),
            .transcriptDelta(id: "google-segment-1", delta: "on October 18th, 1989."),
            .transcriptFinal(id: "google-segment-1", text: "on October 18th, 1989."),
            .finish(.init(text: "It was delivered into Earth orbit on October 18th, 1989.", segments: [], language: nil, durationInSeconds: nil))
        ])
        try await vertexWaitUntil { !run.socket.recordedCloseCodes().isEmpty }
        #expect(run.socket.recordedCloseCodes() == [1_000])
    }

    @Test func trailingSilenceFallsBackToTheQuietGracePeriod() async throws {
        let run = try await makeRun(finishGraceMilliseconds: 50)
        defer { run.result.cancel() }
        run.audio.send(Data(count: 4 * 32_000))
        try await run.socket.waitForCount(2)
        run.activity("ACTIVITY_START", offset: "0.280s")
        run.transcribe("hello.")
        run.generationComplete()
        run.activity("ACTIVITY_END", offset: "2s")
        try await run.received.waitFor(.transcriptFinal(id: "google-segment-0", text: "hello."))

        run.audio.finish()
        try await run.socket.waitForCount(3)
        #expect(await !run.received.isFinished)
        let parts = try await run.received.waitForFinish()
        #expect(parts.last == .finish(.init(text: "hello.")))
    }

    @Test func waitsForBufferedAudioWhenSentFasterThanRealTime() async throws {
        let run = try await makeRun()
        defer { run.result.cancel() }
        run.audio.send(Data(count: 2 * 32_000))
        try await run.socket.waitForCount(2)
        run.activity("ACTIVITY_START", offset: "0.280s")
        run.transcribe("hello.")
        run.generationComplete()
        run.activity("ACTIVITY_END", offset: "1s")
        try await run.received.waitFor(.transcriptFinal(id: "google-segment-0", text: "hello."))
        run.audio.finish()
        try await run.socket.waitForCount(3)
        #expect(await !run.received.isFinished)

        run.activity("ACTIVITY_START", offset: "1.200s")
        run.transcribe("world.")
        run.generationComplete()
        try await run.received.waitFor(.transcriptFinal(id: "google-segment-1", text: "world."))
        #expect(await !run.received.isFinished)

        run.activity("ACTIVITY_END", offset: "2s")
        let parts = try await run.received.waitForFinish()
        #expect(parts.last == .finish(.init(text: "hello. world.")))
    }

    @Test func manualVoiceActivityTranscribesTheAudioAsOneTurn() async throws {
        let run = try await makeRun(manual: true)
        defer { run.result.cancel() }
        let config: JSONValue = ["automaticActivityDetection": ["disabled": true]]
        #expect(run.socket.messages().first?["setup"]?["realtimeInputConfig"] == config)
        #expect(run.result.requestMetadata.body?["realtimeInputConfig"] == config)

        run.audio.send(Data(count: 3 * 32_000))
        run.audio.finish()
        try await run.socket.waitForCount(4)
        let sent = run.socket.messages()
        #expect(sent[1] == ["realtimeInput": ["activityStart": [:]]])
        #expect(sent[2]["realtimeInput"]?["audio"] != nil)
        #expect(sent.last == ["realtimeInput": ["activityEnd": [:]]])
        #expect(!sent.contains(["realtimeInput": ["audioStreamEnd": true]]))

        run.activity("ACTIVITY_START", offset: "0s")
        run.transcribe("Book a venue. Then ask Sam.")
        run.generationComplete()
        run.activity("ACTIVITY_END", offset: "3s")
        let parts = try await run.received.waitForFinish()
        #expect(parts.filter { if case .transcriptFinal = $0 { true } else { false } } == [
            .transcriptFinal(id: "google-segment-0", text: "Book a venue. Then ask Sam.")
        ])
        #expect(parts.last == .finish(.init(text: "Book a venue. Then ask Sam.")))
    }

    @Test func manualVoiceActivityEndsEvenWhenThereIsNoSpeech() async throws {
        let run = try await makeRun(manual: true)
        defer { run.result.cancel() }
        run.audio.send(Data(count: 3 * 32_000))
        run.audio.finish()
        try await run.socket.waitForCount(4)

        run.activity("ACTIVITY_START", offset: "0s")
        run.activity("ACTIVITY_END", offset: "3s")
        let parts = try await run.received.waitForFinish()
        #expect(parts.last == .finish(.init(text: "")))
    }

    @Test func vertexInteractionsSendsMCPHeadersWithOAuthAndRedactsTelemetry() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"id":"mcp","status":"completed","steps":[{"type":"model_output","content":[{"type":"text","text":"ok"}]}]}"#))
        let provider = try GoogleVertexProvider(settings: .init(project: "p", location: "us-central1", accessToken: "token", transport: transport))
        let model = try provider.interactionsModel("gemini-4-neon")
        let result = try await model.generate(.init(messages: [.user("Hello")], reasoning: "xhigh", tools: [
            "connector": GoogleVertexTools.mcpServer(name: "local-mcp", url: "https://example.com/mcp", headers: ["X-Connector": "test-secret"], allowedTools: ["getWeather"])
        ]))
        let request = try #require(await transport.requests().first)
        #expect(request.headers["Authorization"] == "Bearer token")
        let body = try decodeJSONBody(#require(request.body))
        #expect(body["generation_config"]?["thinking_level"] == "xhigh")
        #expect(body["tools"]?[0] == [
            "type": "mcp_server", "name": "local-mcp", "url": "https://example.com/mcp", "headers": ["X-Connector": "test-secret"], "allowed_tools": ["getWeather"]
        ])
        #expect(result.requestMetadata.body == body)
        let redact = try #require(model.telemetryRedactor)
        #expect(try redact(body)["tools"]?[0]?["headers"]?["X-Connector"] == "[redacted]")
    }

    private func makeRun(manual: Bool = false, finishGraceMilliseconds: Int = 3_000) async throws -> VertexLiveTestRun {
        let transport = VertexWeeklySocketTransport()
        let config = GoogleVertexConfig(providerID: "google.vertex.transcription", baseURL: "https://example.com", project: "project", location: "global", headers: [:], auth: .accessToken("token"), transport: RecordingTransport(response: jsonResponse("{}")), date: Date.init, toolResultDownloadsMaxBytes: 1_024)
        let model = GoogleVertexGeminiTranscriptionModel(modelID: "gemini-3.5-transcribe-live", config: config, webSocketTransport: transport, finishGraceMilliseconds: finishGraceMilliseconds)
        let pipe = AIStreamingAudioInput.makeStream()
        let providerOptions: [String: JSONValue] = manual ? ["googleVertex": ["streaming": ["automaticActivityDetection": ["disabled": true]]]] : [:]
        let result = try await model.stream(.init(audio: pipe.input, inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 16_000), providerOptions: providerOptions))
        let received = VertexLiveTestParts()
        Task { await received.consume(result.stream) }
        let socket = transport.connection
        socket.emit(.opened(protocol: nil))
        socket.json(["setupComplete": [:]])
        try await socket.waitForCount(manual ? 2 : 1)
        return VertexLiveTestRun(result: result, audio: pipe.writer, socket: socket, received: received)
    }
}

private struct VertexLiveTestRun {
    let result: StreamingTranscriptionResult
    let audio: AIStreamingAudioWriter
    let socket: VertexWeeklySocket
    let received: VertexLiveTestParts

    func activity(_ type: String, offset: String) {
        socket.json(["voiceActivity": ["type": .string(type), "audioOffset": .string(offset)]])
    }

    func transcribe(_ text: String) {
        socket.json(["serverContent": ["inputTranscription": ["text": .string(text)]]])
    }

    func generationComplete() {
        socket.json(["serverContent": ["generationComplete": true]])
    }
}

private actor VertexLiveTestParts {
    private var parts: [StreamingTranscriptionPart] = []
    private var error: (any Error)?
    private(set) var isFinished = false

    func consume(_ stream: AsyncThrowingStream<StreamingTranscriptionPart, Error>) async {
        do { for try await part in stream { parts.append(part) } }
        catch { self.error = error }
        isFinished = true
    }

    func waitFor(_ part: StreamingTranscriptionPart) async throws {
        try await vertexWaitUntil { await self.receivedOrFinished(part) }
        if let error { throw error }
        #expect(parts.contains(part))
    }

    func waitForFinish() async throws -> [StreamingTranscriptionPart] {
        try await vertexWaitUntil { await self.isFinished }
        if let error { throw error }
        return parts
    }

    private func receivedOrFinished(_ part: StreamingTranscriptionPart) -> Bool { parts.contains(part) || isFinished }
}

private func vertexWaitUntil(_ condition: @Sendable () async -> Bool) async throws {
    for _ in 0..<500 {
        if await condition() { return }
        try await Task.sleep(nanoseconds: 1_000_000)
    }
    Issue.record("Timed out waiting for a mocked Vertex Live event")
    throw AIError.invalidResponse(provider: "test", message: "Timed out waiting for a mocked Vertex Live event")
}
