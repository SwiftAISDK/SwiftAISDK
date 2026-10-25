import Foundation

/// One piece of a continuous speech script. Voice and provider options apply at
/// the beginning of this part; individual deltas may split words.
public struct SpeechTextPart: Equatable, Sendable {
    public var text: String
    public var voice: String?
    public var providerOptions: [String: JSONValue]

    public init(text: String, voice: String? = nil, providerOptions: [String: JSONValue] = [:]) {
        self.text = text
        self.voice = voice
        self.providerOptions = providerOptions
    }
}

/// Incremental text input, pulled by the speech provider. The cancellation hook
/// must stop an external producer when synthesis stops before the script ends.
public struct AIStreamingTextInput: AsyncSequence, Sendable {
    public typealias Element = SpeechTextPart
    public typealias AsyncIterator = AsyncThrowingStream<SpeechTextPart, Error>.Iterator
    private let stream: AsyncThrowingStream<SpeechTextPart, Error>
    private let cancelOperation: @Sendable () -> Void

    public init(_ stream: AsyncThrowingStream<SpeechTextPart, Error>, onConsumerCancel: @escaping @Sendable () -> Void = {}) {
        self.stream = stream
        self.cancelOperation = onConsumerCancel
    }

    /// Adapts a language model's text-delta stream without an eager forwarding
    /// task. Each delta is requested only when synthesis needs more text.
    public init(_ deltas: AsyncThrowingStream<String, Error>, onConsumerCancel: @escaping @Sendable () -> Void = {}) {
        let iterator = SpeechTextDeltaIterator(deltas.makeAsyncIterator())
        self.init(AsyncThrowingStream<SpeechTextPart, Error>(unfolding: {
            try await iterator.next().map { SpeechTextPart(text: $0) }
        }), onConsumerCancel: onConsumerCancel)
    }

    public func makeAsyncIterator() -> AsyncIterator { stream.makeAsyncIterator() }
    public static func text(_ text: String) -> Self { parts([SpeechTextPart(text: text)]) }
    public static func chunks(_ chunks: [String]) -> Self { parts(chunks.map { SpeechTextPart(text: $0) }) }
    public static func parts(_ parts: [SpeechTextPart]) -> Self {
        Self(AsyncThrowingStream { continuation in
            for part in parts { continuation.yield(part) }
            continuation.finish()
        })
    }
    func cancelFromConsumer() { cancelOperation() }
}

private final class SpeechTextDeltaIterator: @unchecked Sendable {
    private let lock = NSLock()
    private var iterator: AsyncThrowingStream<String, Error>.Iterator?
    init(_ iterator: AsyncThrowingStream<String, Error>.Iterator) { self.iterator = iterator }
    func next() async throws -> String? {
        guard var current = lock.withLock({ let value = iterator; iterator = nil; return value }) else { return nil }
        defer { lock.withLock { iterator = current } }
        return try await current.next()
    }
}

public struct StreamingSpeechRequest: Sendable {
    public var text: AIStreamingTextInput
    public var voice: String?
    public var outputFormat: AIStreamingAudioFormat?
    public var instructions: String?
    public var speed: Double?
    public var language: String?
    public var providerOptions: [String: JSONValue]
    public var headers: [String: String]
    public var includeRawChunks: Bool
    public var abortSignal: AIAbortSignal?

    public init(text: AIStreamingTextInput, voice: String? = nil, outputFormat: AIStreamingAudioFormat? = nil,
                instructions: String? = nil, speed: Double? = nil, language: String? = nil,
                providerOptions: [String: JSONValue] = [:], headers: [String: String] = [:],
                includeRawChunks: Bool = false, abortSignal: AIAbortSignal? = nil) {
        self.text = text; self.voice = voice; self.outputFormat = outputFormat
        self.instructions = instructions; self.speed = speed; self.language = language
        self.providerOptions = providerOptions; self.headers = headers
        self.includeRawChunks = includeRawChunks; self.abortSignal = abortSignal
    }

    public init(text: String, voice: String? = nil, outputFormat: AIStreamingAudioFormat? = nil,
                instructions: String? = nil, speed: Double? = nil, language: String? = nil,
                providerOptions: [String: JSONValue] = [:], headers: [String: String] = [:],
                includeRawChunks: Bool = false, abortSignal: AIAbortSignal? = nil) {
        self.init(text: .text(text), voice: voice, outputFormat: outputFormat, instructions: instructions,
                  speed: speed, language: language, providerOptions: providerOptions, headers: headers,
                  includeRawChunks: includeRawChunks, abortSignal: abortSignal)
    }
}

/// Provider lifecycle. Audio bytes remain in generation order; an empty audio
/// part can carry a provider's end-of-turn marker.
public enum StreamingSpeechPart: Sendable {
    case streamStart(warnings: [AIWarning])
    case audio(id: String? = nil, audio: Data, audioFormat: AIStreamingAudioFormat, providerMetadata: [String: JSONValue] = [:])
    case responseMetadata(AIResponseMetadata)
    case finish(usage: [String: JSONValue] = [:], providerMetadata: [String: JSONValue] = [:])
    case raw(JSONValue)
    case error(any Error)
}

public struct StreamingSpeechModelResult: Sendable {
    public var stream: AsyncThrowingStream<StreamingSpeechPart, Error>
    public var requestMetadata: AIRequestMetadata
    public var responseMetadata: AIResponseMetadata
    private let cancelOperation: @Sendable () -> Void
    public init(stream: AsyncThrowingStream<StreamingSpeechPart, Error>, requestMetadata: AIRequestMetadata = .init(),
                responseMetadata: AIResponseMetadata = .init(), cancel: @escaping @Sendable () -> Void = {}) {
        self.stream = stream; self.requestMetadata = requestMetadata
        self.responseMetadata = responseMetadata; self.cancelOperation = cancel
    }
    public func cancel() { cancelOperation() }
}

public protocol StreamingSpeechModel: SpeechModel {
    func stream(_ request: StreamingSpeechRequest) async throws -> StreamingSpeechModelResult
}

public struct AINoSpeechGeneratedError: Error, Sendable, CustomStringConvertible {
    public var responses: [AIResponseMetadata]
    public var cause: (any Error)?
    public init(responses: [AIResponseMetadata] = [], cause: (any Error)? = nil) { self.responses = responses; self.cause = cause }
    public var description: String { "No speech was generated." }
}

public struct AIStreamingSpeechError: Error, Sendable, CustomStringConvertible {
    public var provider: String
    public var message: String
    public var rawValue: JSONValue?
    public init(provider: String, message: String, rawValue: JSONValue? = nil) { self.provider = provider; self.message = message; self.rawValue = rawValue }
    public var description: String { message }
}

public struct StreamingSpeechSummary: Sendable {
    public var usage: [String: JSONValue]
    public var warnings: [AIWarning]
    public var responses: [AIResponseMetadata]
    public var providerMetadata: [String: JSONValue]
}

/// One pull-based owner consumes the audio, full parts, or final metadata. This
/// result never retains a replay buffer of generated audio.
public struct StreamingSpeechResult: Sendable {
    let engine: SpeechResultEngine
    public var fullStream: StreamingSpeechPartStream { get throws { try engine.claimStream(); return StreamingSpeechPartStream(engine: engine) } }
    public var audioStream: StreamingSpeechAudioStream { get throws { try engine.claimStream(); return StreamingSpeechAudioStream(engine: engine) } }
    public var usage: [String: JSONValue] { get async throws { try await engine.summary().usage } }
    public var warnings: [AIWarning] { get async throws { try await engine.summary().warnings } }
    public var responses: [AIResponseMetadata] { get async throws { try await engine.summary().responses } }
    public var providerMetadata: [String: JSONValue] { get async throws { try await engine.summary().providerMetadata } }
    public func cancel() { engine.cancel() }
}

public struct StreamingSpeechPartStream: AsyncSequence, Sendable {
    public typealias Element = StreamingSpeechPart
    let engine: SpeechResultEngine
    public struct AsyncIterator: AsyncIteratorProtocol {
        let lease: SpeechIteratorLease
        public mutating func next() async throws -> StreamingSpeechPart? { try await lease.engine.next() }
    }
    public func makeAsyncIterator() -> AsyncIterator { .init(lease: SpeechIteratorLease(engine)) }
}

public struct StreamingSpeechAudioStream: AsyncSequence, Sendable {
    public typealias Element = Data
    let engine: SpeechResultEngine
    public struct AsyncIterator: AsyncIteratorProtocol {
        let lease: SpeechIteratorLease
        public mutating func next() async throws -> Data? {
            while let part = try await lease.engine.next() {
                if case let .audio(_, audio, _, _) = part, !audio.isEmpty { return audio }
            }
            return nil
        }
    }
    public func makeAsyncIterator() -> AsyncIterator { .init(lease: SpeechIteratorLease(engine)) }
}

final class SpeechIteratorLease {
    let engine: SpeechResultEngine
    init(_ engine: SpeechResultEngine) { self.engine = engine }
    deinit { engine.cancelIfIncomplete() }
}
