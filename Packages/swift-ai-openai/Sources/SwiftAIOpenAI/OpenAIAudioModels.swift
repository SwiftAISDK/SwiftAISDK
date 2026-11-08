import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible
public final class OpenAICompatibleSpeechModel: SpeechModel, @unchecked Sendable {
    public let providerID: String
    public let modelID: String
    private let config: OpenAIModelConfiguration

    public init(modelID: String, config: OpenAIModelConfiguration) {
        self.providerID = config.providerID
        self.modelID = modelID
        self.config = config
    }

    public func speak(_ request: SpeechRequest) async throws -> SpeechResult {
        var warnings: [AIWarning] = []
        var body: [String: JSONValue] = [
            "model": .string(modelID),
            "input": .string(request.text)
        ]
        if isOpenAIBackedProvider(providerID, config: config) {
            body["voice"] = .string(request.voice ?? "alloy")
            let outputFormat = request.format ?? "mp3"
            if openAISpeechSupportedOutputFormats.contains(outputFormat) {
                body["response_format"] = .string(outputFormat)
            } else {
                body["response_format"] = .string("mp3")
                warnings.append(AIWarning(type: "unsupported", feature: "outputFormat", message: "Unsupported output format: \(outputFormat). Using mp3 instead."))
            }
            if let language = request.language {
                warnings.append(AIWarning(type: "unsupported", feature: "language", message: "OpenAI speech models do not support language selection. Language parameter \"\(language)\" was ignored."))
            }
        } else {
            if let voice = request.voice { body["voice"] = .string(voice) }
            if let format = request.format { body["response_format"] = .string(format) }
            if let language = request.language { body["language"] = .string(language) }
        }
        if let speed = request.speed { body["speed"] = .number(speed) }
        if let instructions = request.instructions { body["instructions"] = .string(instructions) }
        let extraBody = isOpenAIBackedProvider(providerID, config: config) ? openAIProviderOptions(providerOptions: request.providerOptions, extraBody: request.extraBody, providerID: providerID, providerRoot: config.openAIBackedProviderRoot) : request.extraBody
        body.merge(extraBody) { _, new in new }

        let response = try await config.transport.send(config.request(path: "/audio/speech", modelID: modelID, body: .object(body), headers: request.headers, abortSignal: request.abortSignal))
        guard (200..<300).contains(response.statusCode) else {
            throw apiCallError(provider: providerID, response: response)
        }
        return SpeechResult(
            audio: response.body,
            contentType: response.headers["content-type"] ?? response.headers["Content-Type"],
            warnings: warnings,
            requestMetadata: AIRequestMetadata(body: .object(body), headers: request.headers),
            responseMetadata: openAICompatibleResponseMetadata(response: response, modelID: modelID)
        )
    }
}

public final class OpenAICompatibleTranscriptionModel: TranscriptionModel, StreamingTranscriptionModel, @unchecked Sendable {
    public let providerID: String
    public let modelID: String
    let config: OpenAIModelConfiguration

    public init(modelID: String, config: OpenAIModelConfiguration) {
        self.providerID = config.providerID
        self.modelID = modelID
        self.config = config
    }

    public func transcribe(_ request: AudioTranscriptionRequest) async throws -> TranscriptionResult {
        if openAITranscriptionIsStreamingOnly(modelID) {
            throw AIError.invalidArgument(argument: "modelID", message: "Non-streaming transcription is not supported with \(modelID).")
        }
        var form = MultipartFormData()
        form.appendField(name: "model", value: modelID)
        form.appendFile(name: "file", fileName: request.fileName, mimeType: request.mimeType, data: request.audio)
        var metadataBody: [String: JSONValue] = [
            "model": .string(modelID),
            "filename": .string(request.fileName),
            "mime_type": .string(request.mimeType)
        ]
        if let language = request.language {
            form.appendField(name: "language", value: language)
            metadataBody["language"] = .string(language)
        }
        if let prompt = request.prompt {
            form.appendField(name: "prompt", value: prompt)
            metadataBody["prompt"] = .string(prompt)
        }
        var extraBody = try isOpenAIBackedProvider(providerID, config: config) ? openAITranscriptionOptions(providerOptions: request.providerOptions, extraBody: request.extraBody, providerID: providerID, providerRoot: config.openAIBackedProviderRoot, modelID: modelID) : request.extraBody
        var warnings: [AIWarning] = []
        if isOpenAIBackedProvider(providerID, config: config) {
            let rawOptions = openAIProviderOptions(providerOptions: request.providerOptions, extraBody: request.extraBody, providerID: providerID, providerRoot: config.openAIBackedProviderRoot)
            let explicit = rawOptions["timestampGranularities"] ?? rawOptions["timestamp_granularities"]
            let requested = request.timestampGranularities?.map(\.rawValue)
            let effective = explicit?.arrayValue?.compactMap(\.stringValue) ?? requested ?? (extraBody["response_format"]?.stringValue == "verbose_json" ? ["segment"] : nil)
            if explicit != nil {
                for granularity in requested ?? [] where explicit?.arrayValue?.contains(.string(granularity)) != true {
                    warnings.append(AIWarning(type: "unsupported", feature: "timestampGranularities", message: "The \"\(granularity)\" timestamp granularity is excluded by providerOptions.openai.timestampGranularities."))
                }
            }
            let format = extraBody["response_format"]?.stringValue
            for granularity in effective ?? [] where format != "verbose_json" && !(format == "diarized_json" && granularity == "segment") {
                warnings.append(AIWarning(type: "unsupported", feature: explicit == nil ? "timestampGranularities" : "providerOptions.openai.timestampGranularities", message: "OpenAI transcription with the \(format ?? "default JSON") response format does not support \(granularity) timestamps."))
            }
            extraBody["timestamp_granularities"] = format == "verbose_json" ? effective.map { .array($0.map(JSONValue.string)) } : nil
        }
        for (key, value) in extraBody {
            if case let .array(items) = value {
                metadataBody[key] = value
                for item in items {
                    if let scalar = jsonScalarString(item) {
                        form.appendField(name: "\(key)[]", value: scalar)
                    }
                }
            } else if let scalar = jsonScalarString(value) {
                form.appendField(name: key, value: scalar)
                metadataBody[key] = value
            }
        }
        let body = form.finalize()
        let response = try await config.transport.send(
            config.rawRequest(
                path: "/audio/transcriptions",
                modelID: modelID,
                body: body,
                contentType: "multipart/form-data; boundary=\(form.boundary)",
                headers: request.headers, abortSignal: request.abortSignal
            )
        )
        guard (200..<300).contains(response.statusCode) else {
            throw apiCallError(provider: providerID, response: response)
        }
        let raw = try response.jsonValue()
        guard let text = raw["text"]?.stringValue else {
            throw AIError.invalidResponse(provider: providerID, message: "No transcription text found.")
        }
        let segments = standardTranscriptionSegments(from: raw)
        let diarizedSegments: [JSONValue] = raw["segments"]?.arrayValue?.compactMap { segment in
            guard let speaker = segment["speaker"]?.stringValue,
                  let text = segment["text"]?.stringValue,
                  let start = segment["start"]?.doubleValue,
                  let end = segment["end"]?.doubleValue else {
                return nil
            }
            return .object([
                "text": .string(text),
                "startSecond": .number(start),
                "endSecond": .number(end),
                "speaker": .string(speaker)
            ])
        } ?? []
        var metadata: [String: JSONValue] = [:]
        if !diarizedSegments.isEmpty { metadata["segments"] = .array(diarizedSegments) }
        if let languages = raw["languages"]?.arrayValue { metadata["languages"] = .array(languages) }
        return TranscriptionResult(
            text: text,
            rawValue: raw,
            segments: segments,
            language: openAITranscriptionLanguageCode(raw["language"]?.stringValue, languages: raw["languages"]),
            durationInSeconds: raw["duration"]?.doubleValue ?? (raw["usage"]?["type"]?.stringValue == "duration" ? raw["usage"]?["seconds"]?.doubleValue : nil),
            warnings: warnings,
            providerMetadata: metadata.isEmpty ? [:] : ["openai": .object(metadata)],
            requestMetadata: AIRequestMetadata(body: .object(metadataBody), headers: request.headers),
            responseMetadata: openAICompatibleResponseMetadata(from: raw, response: response, modelID: modelID),
            usage: raw["usage"]?.objectValue,
            words: openAITranscriptionWords(raw)
        )
    }
}

let openAISpeechSupportedOutputFormats: Set<String> = ["mp3", "opus", "aac", "flac", "wav", "pcm"]

func openAITranscriptionLanguageCode(_ language: String?, languages: JSONValue? = nil) -> String? {
    if let language {
        if openAIIsTranscriptionLanguageCode(language) { return language }
        if let code = openAITranscriptionLanguageMap[language] { return code }
    }
    guard let entries = languages?.arrayValue, entries.count == 1,
          let code = entries[0]["code"]?.stringValue,
          openAIIsTranscriptionLanguageCode(code) else { return nil }
    return code
}

private func openAIIsTranscriptionLanguageCode(_ value: String) -> Bool {
    value.utf8.count == 2 && value.utf8.allSatisfy { (97...122).contains($0) }
}

let openAITranscriptionLanguageMap: [String: String] = [
    "afrikaans": "af",
    "arabic": "ar",
    "armenian": "hy",
    "azerbaijani": "az",
    "belarusian": "be",
    "bosnian": "bs",
    "bulgarian": "bg",
    "catalan": "ca",
    "chinese": "zh",
    "croatian": "hr",
    "czech": "cs",
    "danish": "da",
    "dutch": "nl",
    "english": "en",
    "estonian": "et",
    "finnish": "fi",
    "french": "fr",
    "galician": "gl",
    "german": "de",
    "greek": "el",
    "hebrew": "he",
    "hindi": "hi",
    "hungarian": "hu",
    "icelandic": "is",
    "indonesian": "id",
    "italian": "it",
    "japanese": "ja",
    "kannada": "kn",
    "kazakh": "kk",
    "korean": "ko",
    "latvian": "lv",
    "lithuanian": "lt",
    "macedonian": "mk",
    "malay": "ms",
    "marathi": "mr",
    "maori": "mi",
    "nepali": "ne",
    "norwegian": "no",
    "persian": "fa",
    "polish": "pl",
    "portuguese": "pt",
    "romanian": "ro",
    "russian": "ru",
    "serbian": "sr",
    "slovak": "sk",
    "slovenian": "sl",
    "spanish": "es",
    "swahili": "sw",
    "swedish": "sv",
    "tagalog": "tl",
    "tamil": "ta",
    "thai": "th",
    "turkish": "tr",
    "ukrainian": "uk",
    "urdu": "ur",
    "vietnamese": "vi",
    "welsh": "cy"
]
private func openAITranscriptionWords(_ raw: JSONValue) -> [TranscriptionSegment]? {
    let words = raw["words"]?.arrayValue?.compactMap { word -> TranscriptionSegment? in
        guard let text = word["word"]?.stringValue, let start = word["start"]?.doubleValue, let end = word["end"]?.doubleValue else { return nil }
        return TranscriptionSegment(text: text, startSecond: start, endSecond: end)
    } ?? []
    return words.isEmpty ? nil : words
}
