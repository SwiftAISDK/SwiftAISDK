import Foundation
import Testing
@testable import SwiftAISDK

@Suite struct WeeklySpeech20261025 {
    @Test func acceptsLanguageTextDeltasAndPreservesTextPartOrder() async throws {
        let deltas = AsyncThrowingStream<String, Error> { $0.yield("one "); $0.yield("two"); $0.finish() }
        let input = AIStreamingTextInput(deltas)
        var received: [String] = []
        for try await part in input { received.append(part.text) }
        #expect(received == ["one ", "two"])
    }
    @Test func fullStreamPreservesMetadataOnlyAudioAndSettlesSummary() async throws {
        let error = AIStreamingSpeechError(provider: "test", message: "recoverable")
        let model = WeeklySpeechModel(parts: [
            .streamStart(warnings: [.init(type: "other", message: "warning")]),
            .responseMetadata(.init(modelID: "resolved", body: ["id": "body"])),
            .audio(audio: Data(), audioFormat: .init(mediaType: "audio/pcm")),
            .audio(audio: Data(), audioFormat: .init(mediaType: "audio/pcm"), providerMetadata: ["test": ["turn": true]]),
            .error(error), .audio(audio: Data([1, 2]), audioFormat: .init(mediaType: "audio/pcm")),
            .raw(["raw": true]), .finish(usage: ["inputCharacters": 2], providerMetadata: ["test": ["id": "r1"]])
        ])
        let seen = WeeklySpeechCounter()
        let result = try AI.experimentalStreamSpeech(model: model, request: .init(text: "Hi"), onError: { _ in seen.add() })
        var parts = 0; var bytes = 0
        for try await part in try result.fullStream {
            parts += 1
            if case let .audio(_, data, _, _) = part { bytes += data.count }
        }
        #expect(parts == 4); #expect(bytes == 2); #expect(await weeklySpeechWait { seen.value == 1 })
        #expect(try await result.usage["inputCharacters"] == 2)
        let responses = try await result.responses
        #expect(responses.first?.modelID == "resolved")
        #expect(responses.first?.body == ["id": "body"])
        #expect(try await result.warnings.count == 1)
        #expect(try await result.providerMetadata["test"]?["id"] == "r1")
    }

    @Test func audioProjectionSkipsRecoverableErrorsAndEmptyMetadata() async throws {
        let result = try AI.experimentalStreamSpeech(model: WeeklySpeechModel(parts: [
            .error(AIStreamingSpeechError(provider: "test", message: "temporary")),
            .audio(audio: Data(), audioFormat: .init(mediaType: "audio/pcm"), providerMetadata: ["test": [:]]),
            .audio(audio: Data([7]), audioFormat: .init(mediaType: "audio/pcm")), .finish()
        ]), request: .init(text: "one"))
        var chunks: [Data] = []
        for try await audio in try result.audioStream { chunks.append(audio) }
        #expect(chunks == [Data([7])])
    }

    @Test(arguments: [false, true]) func noAudioIsTypedAndPreservesCause(withFinish: Bool) async throws {
        var parts: [StreamingSpeechPart] = [.error(AIStreamingSpeechError(provider: "test", message: "cause"))]
        if withFinish { parts.append(.finish()) }
        let result = try AI.experimentalStreamSpeech(model: WeeklySpeechModel(parts: parts), request: .init(text: "x"))
        do { _ = try await result.usage; Issue.record("Expected no-speech error") }
        catch let error as AINoSpeechGeneratedError { #expect(String(describing: error.cause).contains("cause")); #expect(error.responses.count == 1) }
    }

    @Test func audioWithoutFinishFailsWithProviderCause() async throws {
        let result = try AI.experimentalStreamSpeech(model: WeeklySpeechModel(parts: [
            .audio(audio: Data([7]), audioFormat: .init(mediaType: "audio/pcm")),
            .error(AIStreamingSpeechError(provider: "test", message: "provider failure"))
        ]), request: .init(text: "x"))
        do { _ = try await result.usage; Issue.record("Expected incomplete stream") }
        catch let error as AIStreamingSpeechError { #expect(error.message == "provider failure") }
    }

    @Test func onlyOneOwnerAndMetadataDrainClaim() async throws {
        let model = WeeklySpeechModel(parts: [.audio(audio: Data([1]), audioFormat: .init(mediaType: "audio/pcm")), .finish()])
        let result = try AI.experimentalStreamSpeech(model: model, request: .init(text: "x"))
        _ = try await result.usage
        #expect(throws: AIError.self) { _ = try result.audioStream }
        let second = try AI.experimentalStreamSpeech(model: model, request: .init(text: "x"))
        let stream = try second.fullStream
        #expect(throws: AIError.self) { _ = try second.audioStream }
        for try await _ in stream {}
    }

    @Test func earlyBreakAndExplicitCancelReleaseInputAndModel() async throws {
        let cancelled = WeeklySpeechCounter()
        let pair = AsyncThrowingStream<StreamingSpeechPart, Error>.makeStream()
        let model = WeeklySpeechModel { _ in
            .init(stream: pair.stream, cancel: { cancelled.add(); pair.continuation.finish() })
        }
        let input = AIStreamingTextInput(.init { $0.yield(.init(text: "x")); $0.finish() }, onConsumerCancel: { cancelled.add() })
        let result = try AI.experimentalStreamSpeech(model: model, request: .init(text: input))
        pair.continuation.yield(.audio(audio: Data([1]), audioFormat: .init(mediaType: "audio/pcm")))
        for try await _ in try result.fullStream { break }
        #expect(await weeklySpeechWait { cancelled.value >= 2 })
        do { _ = try await result.usage; Issue.record("Expected cancellation") } catch is AIAbortError {}
    }

    @Test func userAbortSettlesPendingModelSetup() async throws {
        let delayed = AIDelayedPromise<StreamingSpeechModelResult>()
        let model = WeeklySpeechModel { _ in try await delayed.value() }
        let controller = AIAbortController()
        let result = try AI.experimentalStreamSpeech(model: model, request: .init(text: "x", abortSignal: controller.signal))
        controller.abort(reason: "stop", reasonName: "user")
        do { _ = try await result.usage; Issue.record("Expected abort") }
        catch let error as AIAbortError { #expect(error.reason == "stop"); #expect(error.reasonName == "user") }
        delayed.reject(AIAbortError())
    }

    @Test func userAbortUnblocksAWaitingReadEvenWhenProviderCancelDoesNothing() async throws {
        let pair = AsyncThrowingStream<StreamingSpeechPart, Error>.makeStream()
        let model = WeeklySpeechModel { _ in .init(stream: pair.stream) }
        let controller = AIAbortController()
        let result = try AI.experimentalStreamSpeech(model: model, request: .init(text: "x", abortSignal: controller.signal))
        let started = WeeklySpeechCounter()
        let reader = Task {
            var iterator = try result.audioStream.makeAsyncIterator()
            started.add()
            return try await iterator.next()
        }
        #expect(await weeklySpeechWait { started.value == 1 })
        controller.abort(reason: "mid-read")
        do { _ = try await reader.value; Issue.record("Expected mid-read abort") }
        catch let error as AIAbortError { #expect(error.reason == "mid-read") }
        pair.continuation.finish()
    }

    @Test func rejectedModelSetupCancelsUnconsumedInput() async throws {
        let cancelled = WeeklySpeechCounter()
        let input = AIStreamingTextInput(.init { $0.yield(.init(text: "x")); $0.finish() }, onConsumerCancel: { cancelled.add() })
        let model = WeeklySpeechModel { _ in throw AIStreamingSpeechError(provider: "test", message: "setup") }
        let result = try AI.experimentalStreamSpeech(model: model, request: .init(text: input))
        do { _ = try await result.usage; Issue.record("Expected setup failure") } catch let error as AIStreamingSpeechError { #expect(error.message == "setup") }
        #expect(cancelled.value == 1)
    }

    @Test func unsupportedModelFailsBeforeConsumingText() throws {
        let model = WeeklyNonStreamingSpeechModel()
        #expect(throws: AIError.self) { _ = try AI.experimentalStreamSpeech(model: model, request: .init(text: "x")) }
    }

    @Test func envelopeRoundTripRejectsMalformedKnownParts() throws {
        let part = StreamingSpeechPart.audio(id: "a", audio: Data([1, 2]), audioFormat: .init(mediaType: "audio/pcm", sampleRate: 24000), providerMetadata: ["test": ["turn": true]])
        let encoded = try #require(SpeechStreamEnvelope.serializePart(part))
        guard case let .audio(id, bytes, format, metadata)? = SpeechStreamEnvelope.parsePart(encoded) else { Issue.record("Expected audio"); return }
        #expect(id == "a"); #expect(bytes == Data([1, 2])); #expect(format.sampleRate == 24000); #expect(metadata["test"]?["turn"] == true)
        #expect(SpeechStreamEnvelope.parsePart(#"{"type":"audio","audio":"AA==","audioFormat":{"type":""}}"#) == nil)
        #expect(SpeechStreamEnvelope.parsePart(#"{"type":"finish","usage":{"inputTokens":"1"}}"#) == nil)
        #expect(SpeechStreamEnvelope.parsePart(#"{"type":"finish","usage":null}"#) == nil)
        #expect(SpeechStreamEnvelope.parsePart(#"{"type":"future"}"#) == nil)
    }

    @Test func clientEnvelopeFiltersExtrasAndRejectsPrototypePayloads() {
        let parsed = SpeechStreamEnvelope.parseClientFrame(#"{"type":"speech-stream.start","voice":"a","headers":{"authorization":"secret"},"outputFormat":{"type":"audio/pcm","rate":24000,"extra":1}}"#)
        guard case let .start(frame) = parsed else { Issue.record("Expected start"); return }
        #expect(frame["headers"] == nil); #expect(frame["outputFormat"]?["extra"] == nil)
        guard case .invalid = SpeechStreamEnvelope.parseClientFrame(#"{"type":"speech-stream.start","providerOptions":{"a":null}}"#) else { Issue.record("Expected invalid options"); return }
        guard case .invalid = SpeechStreamEnvelope.parseClientFrame(#"{"type":"speech-stream.start","__proto__":{}}"#) else { Issue.record("Expected invalid unsafe JSON"); return }
        #expect(SpeechStreamEnvelope.parseClientFrame(#"{"type":"future"}"#) == .unknown)
    }
}

struct WeeklySpeechModel: StreamingSpeechModel {
    let providerID = "test.speech"; let modelID = "model"
    let call: @Sendable (StreamingSpeechRequest) async throws -> StreamingSpeechModelResult
    init(_ call: @escaping @Sendable (StreamingSpeechRequest) async throws -> StreamingSpeechModelResult) { self.call = call }
    init(parts: [StreamingSpeechPart]) { call = { _ in .init(stream: .init { continuation in for part in parts { continuation.yield(part) }; continuation.finish() }) } }
    func speak(_ request: SpeechRequest) async throws -> SpeechResult { .init(audio: Data()) }
    func stream(_ request: StreamingSpeechRequest) async throws -> StreamingSpeechModelResult { try await call(request) }
}
private struct WeeklyNonStreamingSpeechModel: SpeechModel {
    let providerID = "test"; let modelID = "model"
    func speak(_ request: SpeechRequest) async throws -> SpeechResult { .init(audio: Data()) }
}
final class WeeklySpeechCounter: @unchecked Sendable {
    private let lock = NSLock(); private var count = 0
    func add() { lock.withLock { count += 1 } }
    var value: Int { lock.withLock { count } }
}
func weeklySpeechWait(_ predicate: @escaping @Sendable () -> Bool) async -> Bool {
    for _ in 0..<500 { if predicate() { return true }; try? await Task.sleep(nanoseconds: 2_000_000) }; return predicate()
}
final class WeeklySpeechSocket: AIDuplexWebSocketConnection, @unchecked Sendable {
    let events: AsyncThrowingStream<AIDuplexWebSocketEvent, Error>
    let continuation: AsyncThrowingStream<AIDuplexWebSocketEvent, Error>.Continuation
    private let lock = NSLock(); private var messages: [JSONValue] = []; private var closes = 0
    init() { let pair = AsyncThrowingStream<AIDuplexWebSocketEvent, Error>.makeStream(); events = pair.stream; continuation = pair.continuation }
    func send(_ message: AIDuplexWebSocketMessage) async throws {
        if case let .text(text) = message { let raw = try secureJSONParse(text); lock.withLock { messages.append(raw) } }
    }
    func close(code: Int, reason: Data?) async { lock.withLock { closes += 1 }; continuation.finish() }
    func open() { continuation.yield(.opened(protocol: nil)) }
    func receive(_ value: JSONValue) throws { continuation.yield(.message(.text(String(decoding: try encodeJSONBody(value), as: UTF8.self)))) }
    func closed(_ code: Int = 1000) { continuation.yield(.closed(.init(code: code))); continuation.finish() }
    var sent: [JSONValue] { lock.withLock { messages } }
    var closeCount: Int { lock.withLock { closes } }
}
final class WeeklySpeechSocketTransport: AIDuplexWebSocketTransport, @unchecked Sendable {
    let socket = WeeklySpeechSocket(); private let lock = NSLock(); private var stored: [AIDuplexWebSocketRequest] = []
    func connect(_ request: AIDuplexWebSocketRequest) async throws -> any AIDuplexWebSocketConnection { lock.withLock { stored.append(request) }; return socket }
    var requests: [AIDuplexWebSocketRequest] { lock.withLock { stored } }
}
