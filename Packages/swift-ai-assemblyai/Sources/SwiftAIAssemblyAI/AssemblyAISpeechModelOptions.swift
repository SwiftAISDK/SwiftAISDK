import SwiftAIProvider

public struct AssemblyAISpeechModelOptions: Sendable {
    public enum Encoding: String, Sendable {
        case mp3
        case pcmS16LE = "pcm_s16le"
        case pcmMuLaw = "pcm_mulaw"
        case pcmALaw = "pcm_alaw"
    }

    public enum Container: String, Sendable {
        case raw
        case wav
    }

    public var encoding: Encoding?
    public var container: Container?
    /// Output sample rate in Hz.
    public var sampleRate: Int?
    /// MP3 output bit rate in bits per second.
    public var bitRate: Int?

    public init(encoding: Encoding? = nil, container: Container? = nil, sampleRate: Int? = nil, bitRate: Int? = nil) {
        self.encoding = encoding
        self.container = container
        self.sampleRate = sampleRate
        self.bitRate = bitRate
    }

    public var providerOptions: [String: JSONValue] {
        var options: [String: JSONValue] = [:]
        options["encoding"] = encoding.map { .string($0.rawValue) }
        options["container"] = container.map { .string($0.rawValue) }
        options["sampleRate"] = sampleRate.map { .number(Double($0)) }
        options["bitRate"] = bitRate.map { .number(Double($0)) }
        return ["assemblyai": .object(options)]
    }

    init(providerOptions: [String: JSONValue]) throws {
        guard let namespace = providerOptions["assemblyai"], namespace != .null else {
            self.init()
            return
        }
        guard let options = namespace.objectValue else {
            throw AIError.invalidArgument(argument: "providerOptions.assemblyai", message: "AssemblyAI provider options must be an object.")
        }
        self.init(
            encoding: try Self.readOption(options["encoding"], key: "encoding", expected: "a supported encoding") {
                $0.stringValue.flatMap(Encoding.init(rawValue:))
            },
            container: try Self.readOption(options["container"], key: "container", expected: "raw or wav") {
                $0.stringValue.flatMap(Container.init(rawValue:))
            },
            sampleRate: try Self.readRate(options["sampleRate"], key: "sampleRate", allowed: [8000, 16000, 22050, 24000, 44100, 48000]),
            bitRate: try Self.readRate(options["bitRate"], key: "bitRate", allowed: [32000, 48000, 64000, 96000, 128000])
        )
    }

    private static func readRate(_ value: JSONValue?, key: String, allowed: [Int]) throws -> Int? {
        try readOption(value, key: key, expected: "one of \(allowed.map(String.init).joined(separator: ", "))") { value in
            allowed.first { Double($0) == value.doubleValue }
        }
    }

    private static func readOption<Value>(_ value: JSONValue?, key: String, expected: String, parse: (JSONValue) -> Value?) throws -> Value? {
        guard let value else { return nil }
        guard let parsed = parse(value) else {
            throw AIError.invalidArgument(argument: "providerOptions.assemblyai.\(key)", message: "AssemblyAI \(key) must be \(expected).")
        }
        return parsed
    }
}
