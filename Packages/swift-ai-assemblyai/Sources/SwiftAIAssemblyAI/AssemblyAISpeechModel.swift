import Foundation
import SwiftAIProvider
import SwiftAIProviderUtilities
import SwiftAITransport

public final class AssemblyAISpeechModel: SpeechModel, Sendable {
    public let providerID = "assemblyai.speech"
    public let modelID: String
    private let http: AIProviderHTTPClient
    private let currentDate: @Sendable () -> Date

    public convenience init(modelID: String, http: AIProviderHTTPClient) {
        self.init(modelID: modelID, http: http, currentDate: Date.init)
    }

    init(modelID: String, http: AIProviderHTTPClient, currentDate: @escaping @Sendable () -> Date) {
        self.modelID = modelID
        self.http = http
        self.currentDate = currentDate
    }

    public func speak(_ request: SpeechRequest) async throws -> SpeechResult {
        let timestamp = currentDate()
        let options = try AssemblyAISpeechModelOptions(providerOptions: request.providerOptions)
        var warnings: [AIWarning] = []
        let body = makeBody(request, options: options, warnings: &warnings)
        let httpRequest = try http.request(path: "/v1/speech", modelID: modelID, body: body, headers: request.headers, abortSignal: request.abortSignal)
        let response = try await http.transport.send(httpRequest)
        guard (200..<300).contains(response.statusCode) else {
            throw assemblyAISpeechHTTPError(response: response, request: httpRequest, requestBody: body)
        }
        if response.statusCode == 204 || response.statusCode == 205 {
            throw assemblyAISpeechHTTPError(response: response, request: httpRequest, requestBody: body, message: "Response body is empty")
        }

        let metadata = speechMetadata(from: response)
        return SpeechResult(
            audio: response.body,
            contentType: response.headers.contentType,
            warnings: warnings,
            providerMetadata: ["assemblyai": .object(metadata)],
            requestMetadata: AIRequestMetadata(body: body, headers: request.headers),
            responseMetadata: AIResponseMetadata(timestamp: timestamp, modelID: modelID, headers: response.headers),
            usage: metadata["billedCharacters"].map { ["characters": $0] }
        )
    }

    private func makeBody(_ request: SpeechRequest, options: AssemblyAISpeechModelOptions, warnings: inout [AIWarning]) -> JSONValue {
        let outputFormat = request.format ?? "mp3"
        let format: OutputFormat
        if let supportedFormat = Self.outputFormats[outputFormat.lowercased()] {
            format = supportedFormat
        } else {
            format = OutputFormat(encoding: .mp3)
            warnings.append(.init(type: "unsupported", feature: "outputFormat", message: "Unknown output format \"\(outputFormat)\". Falling back to mp3. Use providerOptions.assemblyai to configure encoding, container, and sampleRate directly."))
        }

        let encoding = options.encoding ?? format.encoding
        let formatApplies = encoding == format.encoding
        let container = options.container ?? (formatApplies ? format.container : nil)
        let sampleRate = options.sampleRate ?? (formatApplies ? format.sampleRate : nil)

        var body = request.extraBody
        body["text"] = .string(request.text)
        body["model_id"] = .string(modelID)
        body["stream"] = .bool(false)
        body["encoding"] = .string(encoding.rawValue)
        body["voice_id"] = request.voice.flatMap { $0.isEmpty ? nil : .string($0) }
        body["sample_rate"] = sampleRate.map { .number(Double($0)) }
        body["container"] = encoding == .mp3 ? nil : container.map { .string($0.rawValue) }
        body["bit_rate"] = encoding == .mp3 ? options.bitRate.map { .number(Double($0)) } : nil

        if container != nil, encoding == .mp3 {
            warnings.append(.init(type: "unsupported", feature: "providerOptions.assemblyai.container", message: "AssemblyAI MP3 output has no container. The container option was ignored."))
        }
        if options.bitRate != nil, encoding != .mp3 {
            warnings.append(.init(type: "unsupported", feature: "providerOptions.assemblyai.bitRate", message: "AssemblyAI only accepts a bit rate for MP3 output. The bitRate option was ignored."))
        }
        body["language"] = speechLanguage(request.language, warnings: &warnings).map(JSONValue.string)
        if let speed = request.speed, speed != 1 {
            warnings.append(.init(type: "unsupported", feature: "speed", message: "AssemblyAI text-to-speech only supports the default speed. The speed option was ignored."))
        }
        if request.instructions?.isEmpty == false {
            warnings.append(.init(type: "unsupported", feature: "instructions", message: "AssemblyAI text-to-speech does not support instructions. Instructions parameter was ignored."))
        }
        body.removeValue(forKey: "speed")
        body.removeValue(forKey: "instructions")
        return .object(body)
    }

    private struct OutputFormat {
        let encoding: AssemblyAISpeechModelOptions.Encoding
        var container: AssemblyAISpeechModelOptions.Container?
        var sampleRate: Int?
    }

    private static let outputFormats: [String: OutputFormat] = [
        "alaw": .init(encoding: .pcmALaw, container: .raw, sampleRate: 8000),
        "mp3": .init(encoding: .mp3),
        "mulaw": .init(encoding: .pcmMuLaw, container: .raw, sampleRate: 8000),
        "pcm": .init(encoding: .pcmS16LE, container: .raw),
        "wav": .init(encoding: .pcmS16LE, container: .wav)
    ]
}

private let assemblyAISpeechLanguages = [
    "de": "german", "en": "english", "es": "spanish", "fr": "french", "it": "italian", "pt": "portuguese"
]

private func speechLanguage(_ language: String?, warnings: inout [AIWarning]) -> String? {
    guard let language, !language.isEmpty else { return nil }
    let normalized = language.lowercased()
    if let name = assemblyAISpeechLanguages[normalized] { return name }
    if assemblyAISpeechLanguages.values.contains(normalized) { return normalized }

    let message: String
    if normalized == "auto" {
        message = "AssemblyAI text-to-speech does not detect the language. The voice speaks its own language."
    } else {
        let supported = assemblyAISpeechLanguages.keys.sorted().joined(separator: ", ")
        message = "AssemblyAI text-to-speech does not support language \"\(language)\" (supported: \(supported)). The language option was ignored."
    }
    warnings.append(.init(type: "unsupported", feature: "language", message: message))
    return nil
}

private func speechMetadata(from response: AIHTTPResponse) -> [String: JSONValue] {
    var metadata: [String: JSONValue] = [:]
    for (key, header) in [
        "requestId": "x-request-id", "model": "x-tts-model", "voiceId": "x-tts-voice-id",
        "language": "x-tts-language", "encoding": "x-tts-encoding"
    ] {
        if let value = response.headerValue(header), !value.isEmpty {
            metadata[key] = .string(value)
        }
    }
    for (key, header) in [
        "sampleRate": "x-tts-sample-rate", "audioDurationMs": "x-tts-audio-duration-ms", "billedCharacters": "x-tts-billed-characters"
    ] {
        if let value = response.headerValue(header),
           let number = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)), number.isFinite {
            metadata[key] = .number(number)
        }
    }
    return metadata
}
