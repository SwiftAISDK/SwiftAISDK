import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities


public final class GladiaTranscriptionModel: TranscriptionModel, @unchecked Sendable {
    public let providerID: String
    public let modelID: String
    private let config: GladiaModelConfiguration

    public init(modelID: String, config: GladiaModelConfiguration) {
        self.providerID = "gladia.transcription"
        self.modelID = modelID
        self.config = config
    }

    public func transcribe(_ request: AudioTranscriptionRequest) async throws -> TranscriptionResult {
        try request.abortSignal?.throwIfAborted()
        let options = try gladiaProviderOptions(from: request)
        try validatePollingConfiguration(options)
        let resolved = gladiaResolvedOptions(options, modelID: modelID)
        var form = MultipartFormData()
        form.appendFile(name: "audio", fileName: "audio.\(mediaTypeToExtension(request.mimeType))", mimeType: request.mimeType, data: request.audio)
        let uploadResponse = try await config.transport.send(config.rawRequest(
            path: "/v2/upload",
            modelID: modelID,
            body: form.finalize(),
            contentType: "multipart/form-data; boundary=\(form.boundary)",
            headers: request.headers,
            abortSignal: request.abortSignal
        ))
        guard (200..<300).contains(uploadResponse.statusCode) else {
            throw audioProviderHTTPStatusError(provider: providerID, response: uploadResponse)
        }
        let uploadRaw = try uploadResponse.jsonValue()
        guard let audioURL = uploadRaw["audio_url"]?.stringValue else {
            throw AIError.invalidResponse(provider: providerID, message: "Gladia upload response did not contain audio_url.")
        }

        return try await transcribeAudioURL(audioURL, options: options, resolved: resolved, headers: request.headers, abortSignal: request.abortSignal)
    }

    public func transcribeFromURL(_ request: AudioURLTranscriptionRequest) async throws -> TranscriptionResult? {
        try request.abortSignal?.throwIfAborted()
        guard ["http", "https"].contains(request.audio.scheme?.lowercased() ?? ""), request.audio.host != nil else {
            throw AIError.invalidArgument(argument: "audio", message: "Gladia audio URL must use HTTP or HTTPS.")
        }
        let native = AudioTranscriptionRequest(audio: Data(), providerOptions: request.providerOptions, extraBody: request.extraBody, headers: request.headers, abortSignal: request.abortSignal)
        let options = try gladiaProviderOptions(from: native)
        try validatePollingConfiguration(options)
        return try await transcribeAudioURL(request.audio.absoluteString, options: options, resolved: gladiaResolvedOptions(options, modelID: modelID), headers: request.headers, abortSignal: request.abortSignal)
    }

    private func validatePollingConfiguration(_ options: [String: JSONValue]) throws {
        for (name, value) in [("pollIntervalMs", options["pollIntervalMs"]?.doubleValue ?? Double(config.pollIntervalMs ?? 1_000)), ("pollTimeoutMs", options["pollTimeoutMs"]?.doubleValue ?? Double(config.pollTimeoutMs ?? 600_000))] {
            guard value.isFinite, value > 0, value.rounded() == value else { throw AIError.invalidArgument(argument: name, message: "Gladia \(name) must be a positive integer.") }
        }
    }

    private func transcribeAudioURL(_ audioURL: String, options: [String: JSONValue], resolved: (body: [String: JSONValue], warnings: [AIWarning]), headers: [String: String], abortSignal: AIAbortSignal?) async throws -> TranscriptionResult {
        var body = resolved.body
        body["audio_url"] = .string(audioURL)
        let initResponse = try await config.transport.send(config.request(
            path: "/v2/pre-recorded",
            modelID: modelID,
            body: .object(body),
            headers: headers,
            abortSignal: abortSignal
        ))
        guard (200..<300).contains(initResponse.statusCode) else {
            throw audioProviderHTTPStatusError(provider: providerID, response: initResponse)
        }
        let initRaw = try initResponse.jsonValue()
        guard let resultURL = initRaw["result_url"]?.stringValue else {
            throw AIError.invalidResponse(provider: providerID, message: "Gladia initiation response did not contain result_url.")
        }

        let finalResponse = try await pollGladiaResultResponse(url: resultURL, headers: headers, abortSignal: abortSignal, options: options)
        let raw = finalResponse.json
        guard raw["status"]?.stringValue != "error" else {
            throw AIError.invalidResponse(provider: providerID, message: raw["error_code"]?.doubleValue.map { "Transcription job failed with error code \($0.rounded() == $0 ? String(format: "%.0f", $0) : String($0))" } ?? "Transcription job failed")
        }
        try validateGladiaTranscriptionResult(raw, providerID: providerID)
        guard raw["result"]?.objectValue != nil else {
            throw AIError.invalidResponse(provider: providerID, message: "Transcription result is empty")
        }
        let text = raw["result"]?["transcription"]?["full_transcript"]?.stringValue ?? ""
        let segments = gladiaTranscriptionSegments(from: raw)
        return TranscriptionResult(
            text: text,
            rawValue: raw,
            segments: segments,
            language: raw["result"]?["transcription"]?["languages"]?[0]?.stringValue,
            durationInSeconds: raw["result"]?["metadata"]?["audio_duration"]?.doubleValue ?? transcriptionDuration(from: segments),
            warnings: resolved.warnings,
            providerMetadata: ["gladia": raw],
            responseMetadata: aiResponseMetadata(from: raw, response: finalResponse.response, modelID: modelID)
        )
    }

    private func pollGladiaResultResponse(url: String, headers: [String: String], abortSignal: AIAbortSignal?, options: [String: JSONValue]) async throws -> (json: JSONValue, response: AIHTTPResponse) {
        let interval = options["pollIntervalMs"]?.doubleValue ?? Double(config.pollIntervalMs ?? 1_000)
        let timeout = options["pollTimeoutMs"]?.doubleValue ?? Double(config.pollTimeoutMs ?? 600_000)
        let started = DispatchTime.now().uptimeNanoseconds
        while true {
            try Task.checkCancellation()
            try abortSignal?.throwIfAborted()
            if Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000 > timeout {
                throw AIError.invalidResponse(provider: providerID, message: "Transcription job polling timed out after \(String(format: "%.0f", timeout)) ms")
            }
            let pollHeaders = isSameOrigin(url, config.baseURL) ? config.headers.mergingHeaders(headers) : [:]
            let response = try await downloadURL(url, transport: config.transport, headers: pollHeaders, abortSignal: abortSignal)
            guard (200..<300).contains(response.statusCode) else {
                throw audioProviderHTTPStatusError(provider: providerID, response: response)
            }
            let raw = try response.jsonValue()
            guard let status = raw["status"]?.stringValue, ["queued", "processing", "done", "error"].contains(status) else {
                throw AIError.invalidResponse(provider: providerID, message: "Gladia transcription status is invalid.")
            }
            if let code = raw["error_code"], code != .null, code.doubleValue == nil { throw AIError.invalidResponse(provider: providerID, message: "Gladia transcription error_code is invalid.") }
            switch status {
            case "done", "error":
                return (raw, response)
            default:
                do {
                    try await sleepWithAbortSignal(nanoseconds: UInt64(min(interval, Double(UInt64.max / 1_000_000))) * 1_000_000, abortSignal: abortSignal)
                } catch {
                    try abortSignal?.throwIfAborted()
                    throw error
                }
            }
        }
    }
}

private func validateGladiaTranscriptionResult(_ raw: JSONValue, providerID: String) throws {
    guard let result = raw["result"] else { return }
    guard result != .null else { return }
    guard
        result["metadata"]?["audio_duration"]?.doubleValue != nil,
        result["transcription"]?["full_transcript"]?.stringValue != nil,
        let languages = result["transcription"]?["languages"]?.arrayValue,
        let utterances = result["transcription"]?["utterances"]?.arrayValue
    else {
        throw AIError.invalidResponse(provider: providerID, message: "Gladia transcription result is invalid.")
    }
    guard languages.allSatisfy({ $0.stringValue != nil }) else {
        throw AIError.invalidResponse(provider: providerID, message: "Gladia transcription result is invalid.")
    }
    guard utterances.allSatisfy({ $0["start"]?.doubleValue != nil && $0["end"]?.doubleValue != nil && $0["text"]?.stringValue != nil }) else {
        throw AIError.invalidResponse(provider: providerID, message: "Gladia transcription result is invalid.")
    }
}

private func gladiaProviderOptions(from extraBody: [String: JSONValue]) -> [String: JSONValue] {
    var output = extraBody
    if let nested = output.removeValue(forKey: "gladia")?.objectValue {
        output.merge(nested) { _, nested in nested }
    }
    return output
}

private func gladiaProviderOptions(from request: AudioTranscriptionRequest) throws -> [String: JSONValue] {
    var output = gladiaProviderOptions(from: request.extraBody)
    if let value = request.providerOptions["gladia"] {
        guard value != .null else { return output }
        guard let nested = value.objectValue else {
            throw AIError.invalidArgument(argument: "providerOptions.gladia", message: "Gladia provider options must be an object.")
        }
        for key in gladiaTranscriptionProviderOptionKeys {
            output.removeValue(forKey: key)
        }
        output.merge(try gladiaValidateTranscriptionProviderOptions(nested)) { _, providerValue in providerValue }
    }
    return output
}

private let gladiaTranscriptionProviderOptionKeys: Set<String> = [
    "languageConfig", "piiRedaction", "piiRedactionConfig", "pollIntervalMs", "pollTimeoutMs",
    "contextPrompt",
    "customVocabulary",
    "customVocabularyConfig",
    "detectLanguage",
    "enableCodeSwitching",
    "codeSwitchingConfig",
    "language",
    "callback",
    "callbackConfig",
    "subtitles",
    "subtitlesConfig",
    "diarization",
    "diarizationConfig",
    "translation",
    "translationConfig",
    "summarization",
    "summarizationConfig",
    "moderation",
    "namedEntityRecognition",
    "chapterization",
    "nameConsistency",
    "customSpelling",
    "customSpellingConfig",
    "structuredDataExtraction",
    "structuredDataExtractionConfig",
    "sentimentAnalysis",
    "audioToLlm",
    "audioToLlmConfig",
    "customMetadata",
    "sentences",
    "displayMode",
    "punctuationEnhanced"
]

private func gladiaValidateTranscriptionProviderOptions(_ options: [String: JSONValue]) throws -> [String: JSONValue] {
    var output: [String: JSONValue] = [:]
    for (key, value) in options where gladiaTranscriptionProviderOptionKeys.contains(key) {
        if value == .null {
            if ["languageConfig", "piiRedaction", "piiRedactionConfig"].contains(key) { throw AIError.invalidArgument(argument: "providerOptions.gladia.\(key)", message: "Gladia \(key) cannot be null.") }
            continue
        }
        switch key {
        case "pollIntervalMs", "pollTimeoutMs":
            guard let number = value.doubleValue, number.isFinite, number > 0, number.rounded() == number else { throw AIError.invalidArgument(argument: "providerOptions.gladia.\(key)", message: "Gladia \(key) must be a positive integer.") }
            output[key] = value
        case "languageConfig":
            guard let object = value.objectValue else { throw AIError.invalidArgument(argument: "providerOptions.gladia.languageConfig", message: "Gladia languageConfig must be an object.") }
            var config: [String: JSONValue] = [:]
            if let languages = object["languages"] { config["languages"] = try gladiaStringArray(languages, argument: "providerOptions.gladia.languageConfig.languages") }
            if let codeSwitching = object["codeSwitching"] { try gladiaRequireBoolean(codeSwitching, argument: "providerOptions.gladia.languageConfig.codeSwitching", message: "Gladia codeSwitching must be a boolean."); config["codeSwitching"] = codeSwitching }
            output[key] = .object(config)
        case "piiRedactionConfig":
            guard let object = value.objectValue else { throw AIError.invalidArgument(argument: "providerOptions.gladia.piiRedactionConfig", message: "Gladia piiRedactionConfig must be an object.") }
            var config: [String: JSONValue] = [:]
            if let types = object["entityTypes"] { config["entityTypes"] = try gladiaStringArray(types, argument: "providerOptions.gladia.piiRedactionConfig.entityTypes") }
            if let type = object["processedTextType"] {
                guard ["MARKER", "MASK"].contains(type.stringValue ?? "") else { throw AIError.invalidArgument(argument: "providerOptions.gladia.piiRedactionConfig.processedTextType", message: "Gladia processedTextType must be MARKER or MASK.") }
                config["processedTextType"] = type
            }
            output[key] = .object(config)
        case "contextPrompt", "language":
            try gladiaRequireString(value, argument: "providerOptions.gladia.\(key)", message: "Gladia \(key) must be a string.")
            output[key] = value
        case "customVocabulary":
            output[key] = try gladiaValidatedCustomVocabulary(value)
        case "customVocabularyConfig":
            output[key] = try gladiaValidatedCustomVocabularyConfig(value)
        case "piiRedaction", "detectLanguage", "enableCodeSwitching", "callback", "subtitles", "diarization", "translation", "summarization", "moderation", "namedEntityRecognition", "chapterization", "nameConsistency", "customSpelling", "structuredDataExtraction", "sentimentAnalysis", "audioToLlm", "sentences", "displayMode", "punctuationEnhanced":
            try gladiaRequireBoolean(value, argument: "providerOptions.gladia.\(key)", message: "Gladia \(key) must be a boolean.")
            output[key] = value
        case "codeSwitchingConfig":
            output[key] = try gladiaValidatedCodeSwitchingConfig(value)
        case "callbackConfig":
            output[key] = try gladiaValidatedCallbackConfig(value)
        case "subtitlesConfig":
            output[key] = try gladiaValidatedSubtitlesConfig(value)
        case "diarizationConfig":
            output[key] = try gladiaValidatedDiarizationConfig(value)
        case "translationConfig":
            output[key] = try gladiaValidatedTranslationConfig(value)
        case "summarizationConfig":
            output[key] = try gladiaValidatedSummarizationConfig(value)
        case "customSpellingConfig":
            output[key] = try gladiaValidatedCustomSpellingConfig(value)
        case "structuredDataExtractionConfig":
            output[key] = try gladiaValidatedStructuredDataExtractionConfig(value)
        case "audioToLlmConfig":
            output[key] = try gladiaValidatedAudioToLLMConfig(value)
        case "customMetadata":
            guard value.objectValue != nil else {
                throw AIError.invalidArgument(argument: "providerOptions.gladia.customMetadata", message: "Gladia customMetadata must be an object.")
            }
            output[key] = value
        default:
            break
        }
    }
    return output
}

private func gladiaValidatedCustomVocabulary(_ value: JSONValue) throws -> JSONValue {
    if value.boolValue != nil { return value }
    guard value.arrayValue != nil else {
        throw AIError.invalidArgument(argument: "providerOptions.gladia.customVocabulary", message: "Gladia customVocabulary must be a boolean or array.")
    }
    return value
}

private func gladiaValidatedCustomVocabularyConfig(_ value: JSONValue) throws -> JSONValue {
    guard let object = value.objectValue else {
        throw AIError.invalidArgument(argument: "providerOptions.gladia.customVocabularyConfig", message: "Gladia customVocabularyConfig must be an object.")
    }
    guard let vocabulary = object["vocabulary"] else {
        throw AIError.invalidArgument(argument: "providerOptions.gladia.customVocabularyConfig.vocabulary", message: "Gladia customVocabularyConfig.vocabulary is required.")
    }
    var output: [String: JSONValue] = ["vocabulary": try gladiaValidatedVocabulary(vocabulary)]
    if let defaultIntensity = object["defaultIntensity"] {
        if defaultIntensity != .null {
            try gladiaRequireNumber(defaultIntensity, argument: "providerOptions.gladia.customVocabularyConfig.defaultIntensity", message: "Gladia customVocabularyConfig.defaultIntensity must be a number.")
            output["defaultIntensity"] = defaultIntensity
        }
    }
    return .object(output)
}

private func gladiaValidatedVocabulary(_ value: JSONValue) throws -> JSONValue {
    guard let array = value.arrayValue else {
        throw AIError.invalidArgument(argument: "providerOptions.gladia.customVocabularyConfig.vocabulary", message: "Gladia customVocabularyConfig.vocabulary must be an array.")
    }
    return .array(try array.enumerated().map { index, item in
        if item.stringValue != nil { return item }
        guard let object = item.objectValue else {
            throw AIError.invalidArgument(argument: "providerOptions.gladia.customVocabularyConfig.vocabulary[\(index)]", message: "Gladia vocabulary items must be strings or objects.")
        }
        guard let term = object["value"], term.stringValue != nil else {
            throw AIError.invalidArgument(argument: "providerOptions.gladia.customVocabularyConfig.vocabulary[\(index)].value", message: "Gladia vocabulary item value must be a string.")
        }
        var output: [String: JSONValue] = ["value": term]
        if let intensity = object["intensity"] {
            if intensity != .null {
                try gladiaRequireNumber(intensity, argument: "providerOptions.gladia.customVocabularyConfig.vocabulary[\(index)].intensity", message: "Gladia vocabulary intensity must be a number.")
                output["intensity"] = intensity
            }
        }
        if let pronunciations = object["pronunciations"] {
            if pronunciations != .null {
                output["pronunciations"] = try gladiaStringArray(pronunciations, argument: "providerOptions.gladia.customVocabularyConfig.vocabulary[\(index)].pronunciations")
            }
        }
        if let language = object["language"] {
            if language != .null {
                try gladiaRequireString(language, argument: "providerOptions.gladia.customVocabularyConfig.vocabulary[\(index)].language", message: "Gladia vocabulary language must be a string.")
                output["language"] = language
            }
        }
        return .object(output)
    })
}

private func gladiaValidatedCodeSwitchingConfig(_ value: JSONValue) throws -> JSONValue {
    guard let object = value.objectValue else {
        throw AIError.invalidArgument(argument: "providerOptions.gladia.codeSwitchingConfig", message: "Gladia codeSwitchingConfig must be an object.")
    }
    var output: [String: JSONValue] = [:]
    if let languages = object["languages"] {
        if languages != .null {
            output["languages"] = try gladiaStringArray(languages, argument: "providerOptions.gladia.codeSwitchingConfig.languages")
        }
    }
    return .object(output)
}

private func gladiaValidatedCallbackConfig(_ value: JSONValue) throws -> JSONValue {
    guard let object = value.objectValue else {
        throw AIError.invalidArgument(argument: "providerOptions.gladia.callbackConfig", message: "Gladia callbackConfig must be an object.")
    }
    guard let url = object["url"], url.stringValue != nil else {
        throw AIError.invalidArgument(argument: "providerOptions.gladia.callbackConfig.url", message: "Gladia callbackConfig.url must be a string.")
    }
    var output: [String: JSONValue] = ["url": url]
    if let method = object["method"] {
        if method != .null {
            guard let methodValue = method.stringValue, ["POST", "PUT"].contains(methodValue) else {
                throw AIError.invalidArgument(argument: "providerOptions.gladia.callbackConfig.method", message: "Gladia callbackConfig.method must be POST or PUT.")
            }
            output["method"] = method
        }
    }
    return .object(output)
}

private func gladiaValidatedSubtitlesConfig(_ value: JSONValue) throws -> JSONValue {
    guard let object = value.objectValue else {
        throw AIError.invalidArgument(argument: "providerOptions.gladia.subtitlesConfig", message: "Gladia subtitlesConfig must be an object.")
    }
    var output: [String: JSONValue] = [:]
    if let formats = object["formats"] {
        if formats != .null {
            output["formats"] = try gladiaStringArray(formats, argument: "providerOptions.gladia.subtitlesConfig.formats", allowedValues: ["srt", "vtt"])
        }
    }
    for key in ["minimumDuration", "maximumDuration", "maximumCharactersPerRow", "maximumRowsPerCaption"] {
        if let number = object[key] {
            guard number != .null else { continue }
            try gladiaRequireNumber(number, argument: "providerOptions.gladia.subtitlesConfig.\(key)", message: "Gladia subtitlesConfig.\(key) must be a number.")
            output[key] = number
        }
    }
    if let style = object["style"] {
        if style != .null {
            guard let styleValue = style.stringValue, ["default", "compliance"].contains(styleValue) else {
                throw AIError.invalidArgument(argument: "providerOptions.gladia.subtitlesConfig.style", message: "Gladia subtitlesConfig.style must be default or compliance.")
            }
            output["style"] = style
        }
    }
    return .object(output)
}

private func gladiaValidatedDiarizationConfig(_ value: JSONValue) throws -> JSONValue {
    guard let object = value.objectValue else {
        throw AIError.invalidArgument(argument: "providerOptions.gladia.diarizationConfig", message: "Gladia diarizationConfig must be an object.")
    }
    var output: [String: JSONValue] = [:]
    for key in ["numberOfSpeakers", "minSpeakers", "maxSpeakers"] {
        if let number = object[key] {
            guard number != .null else { continue }
            try gladiaRequireNumber(number, argument: "providerOptions.gladia.diarizationConfig.\(key)", message: "Gladia diarizationConfig.\(key) must be a number.")
            output[key] = number
        }
    }
    if let enhanced = object["enhanced"] {
        if enhanced != .null {
            try gladiaRequireBoolean(enhanced, argument: "providerOptions.gladia.diarizationConfig.enhanced", message: "Gladia diarizationConfig.enhanced must be a boolean.")
            output["enhanced"] = enhanced
        }
    }
    return .object(output)
}

private func gladiaValidatedTranslationConfig(_ value: JSONValue) throws -> JSONValue {
    guard let object = value.objectValue else {
        throw AIError.invalidArgument(argument: "providerOptions.gladia.translationConfig", message: "Gladia translationConfig must be an object.")
    }
    guard let targetLanguages = object["targetLanguages"] else {
        throw AIError.invalidArgument(argument: "providerOptions.gladia.translationConfig.targetLanguages", message: "Gladia translationConfig.targetLanguages is required.")
    }
    var output: [String: JSONValue] = [
        "targetLanguages": try gladiaStringArray(targetLanguages, argument: "providerOptions.gladia.translationConfig.targetLanguages")
    ]
    if let model = object["model"] {
        if model != .null {
            guard let modelValue = model.stringValue, ["base", "batch", "enhanced"].contains(modelValue) else {
                throw AIError.invalidArgument(argument: "providerOptions.gladia.translationConfig.model", message: "Gladia translationConfig.model must be base or enhanced.")
            }
            output["model"] = model
        }
    }
    if let matchOriginalUtterances = object["matchOriginalUtterances"] {
        if matchOriginalUtterances != .null {
            try gladiaRequireBoolean(matchOriginalUtterances, argument: "providerOptions.gladia.translationConfig.matchOriginalUtterances", message: "Gladia translationConfig.matchOriginalUtterances must be a boolean.")
            output["matchOriginalUtterances"] = matchOriginalUtterances
        }
    }
    for key in ["lipsync", "contextAdaptation", "informal"] where object[key] != nil {
        try gladiaRequireBoolean(object[key]!, argument: "providerOptions.gladia.translationConfig.\(key)", message: "Gladia \(key) must be a boolean.")
        output[key] = object[key]
    }
    if let context = object["context"] {
        try gladiaRequireString(context, argument: "providerOptions.gladia.translationConfig.context", message: "Gladia context must be a string.")
        output["context"] = context
    }
    return .object(output)
}

private func gladiaValidatedSummarizationConfig(_ value: JSONValue) throws -> JSONValue {
    guard let object = value.objectValue else {
        throw AIError.invalidArgument(argument: "providerOptions.gladia.summarizationConfig", message: "Gladia summarizationConfig must be an object.")
    }
    var output: [String: JSONValue] = [:]
    if let type = object["type"] {
        if type != .null {
            guard let typeValue = type.stringValue, ["general", "bullet_points", "concise"].contains(typeValue) else {
                throw AIError.invalidArgument(argument: "providerOptions.gladia.summarizationConfig.type", message: "Gladia summarizationConfig.type is invalid.")
            }
            output["type"] = type
        }
    }
    return .object(output)
}

private func gladiaValidatedCustomSpellingConfig(_ value: JSONValue) throws -> JSONValue {
    guard let object = value.objectValue else {
        throw AIError.invalidArgument(argument: "providerOptions.gladia.customSpellingConfig", message: "Gladia customSpellingConfig must be an object.")
    }
    guard let dictionary = object["spellingDictionary"], let entries = dictionary.objectValue else {
        throw AIError.invalidArgument(argument: "providerOptions.gladia.customSpellingConfig.spellingDictionary", message: "Gladia customSpellingConfig.spellingDictionary must be an object.")
    }
    var output: [String: JSONValue] = [:]
    for (key, value) in entries {
        output[key] = try gladiaStringArray(value, argument: "providerOptions.gladia.customSpellingConfig.spellingDictionary.\(key)")
    }
    return .object(["spellingDictionary": .object(output)])
}

private func gladiaValidatedStructuredDataExtractionConfig(_ value: JSONValue) throws -> JSONValue {
    guard let object = value.objectValue, let classes = object["classes"] else {
        throw AIError.invalidArgument(argument: "providerOptions.gladia.structuredDataExtractionConfig.classes", message: "Gladia structuredDataExtractionConfig.classes is required.")
    }
    return .object(["classes": try gladiaStringArray(classes, argument: "providerOptions.gladia.structuredDataExtractionConfig.classes")])
}

private func gladiaValidatedAudioToLLMConfig(_ value: JSONValue) throws -> JSONValue {
    guard let object = value.objectValue, let prompts = object["prompts"] else {
        throw AIError.invalidArgument(argument: "providerOptions.gladia.audioToLlmConfig.prompts", message: "Gladia audioToLlmConfig.prompts is required.")
    }
    var output: [String: JSONValue] = ["prompts": try gladiaStringArray(prompts, argument: "providerOptions.gladia.audioToLlmConfig.prompts")]
    if let model = object["model"] { try gladiaRequireString(model, argument: "providerOptions.gladia.audioToLlmConfig.model", message: "Gladia audioToLlmConfig.model must be a string."); output["model"] = model }
    return .object(output)
}

private func gladiaStringArray(_ value: JSONValue, argument: String, allowedValues: Set<String>? = nil) throws -> JSONValue {
    guard let array = value.arrayValue else {
        throw AIError.invalidArgument(argument: argument, message: "Gladia \(argument) must be an array of strings.")
    }
    for item in array {
        guard let string = item.stringValue else {
            throw AIError.invalidArgument(argument: argument, message: "Gladia \(argument) values must be strings.")
        }
        if let allowedValues, !allowedValues.contains(string) {
            throw AIError.invalidArgument(argument: argument, message: "Gladia \(argument) contains an unsupported value.")
        }
    }
    return value
}

private func gladiaRequireString(_ value: JSONValue, argument: String, message: String) throws {
    guard value.stringValue != nil else {
        throw AIError.invalidArgument(argument: argument, message: message)
    }
}

private func gladiaRequireNumber(_ value: JSONValue, argument: String, message: String) throws {
    guard value.doubleValue?.isFinite == true else {
        throw AIError.invalidArgument(argument: argument, message: message)
    }
}

private func gladiaRequireBoolean(_ value: JSONValue, argument: String, message: String) throws {
    guard value.boolValue != nil else {
        throw AIError.invalidArgument(argument: argument, message: message)
    }
}

private func gladiaTranscriptionOptions(from extraBody: [String: JSONValue]) -> [String: JSONValue] {
    var output: [String: JSONValue] = [:]
    for (key, value) in extraBody {
        switch key {
        case "contextPrompt":
            output["context_prompt"] = value
        case "customVocabulary":
            output["custom_vocabulary"] = value
        case "customVocabularyConfig":
            output["custom_vocabulary_config"] = gladiaNestedOptions(value, mapping: ["defaultIntensity": "default_intensity"])
        case "detectLanguage":
            output["detect_language"] = value
        case "enableCodeSwitching":
            output["enable_code_switching"] = value
        case "language":
            output["language"] = value
        case "codeSwitchingConfig":
            output["code_switching_config"] = gladiaNestedOptions(value, mapping: [:])
        case "callback":
            output["callback"] = value
        case "callbackConfig":
            output["callback_config"] = gladiaNestedOptions(value, mapping: [:])
        case "subtitles":
            output["subtitles"] = value
        case "subtitlesConfig":
            output["subtitles_config"] = gladiaNestedOptions(value, mapping: [
                "minimumDuration": "minimum_duration",
                "maximumDuration": "maximum_duration",
                "maximumCharactersPerRow": "maximum_characters_per_row",
                "maximumRowsPerCaption": "maximum_rows_per_caption"
            ])
        case "diarization":
            output["diarization"] = value
        case "diarizationConfig":
            output["diarization_config"] = gladiaNestedOptions(value, mapping: [
                "numberOfSpeakers": "number_of_speakers",
                "minSpeakers": "min_speakers",
                "maxSpeakers": "max_speakers"
            ])
        case "translation":
            output["translation"] = value
        case "translationConfig":
            output["translation_config"] = gladiaNestedOptions(value, mapping: [
                "targetLanguages": "target_languages",
                "matchOriginalUtterances": "match_original_utterances"
            ])
        case "summarization":
            output["summarization"] = value
        case "summarizationConfig":
            output["summarization_config"] = gladiaNestedOptions(value, mapping: [:])
        case "moderation":
            output["moderation"] = value
        case "namedEntityRecognition":
            output["named_entity_recognition"] = value
        case "chapterization":
            output["chapterization"] = value
        case "nameConsistency":
            output["name_consistency"] = value
        case "customSpelling":
            output["custom_spelling"] = value
        case "customSpellingConfig":
            output["custom_spelling_config"] = gladiaNestedOptions(value, mapping: ["spellingDictionary": "spelling_dictionary"])
        case "structuredDataExtraction":
            output["structured_data_extraction"] = value
        case "structuredDataExtractionConfig":
            output["structured_data_extraction_config"] = value
        case "sentimentAnalysis":
            output["sentiment_analysis"] = value
        case "audioToLlm":
            output["audio_to_llm"] = value
        case "audioToLlmConfig":
            output["audio_to_llm_config"] = value
        case "customMetadata":
            output["custom_metadata"] = value
        case "sentences":
            output["sentences"] = value
        case "displayMode":
            output["display_mode"] = value
        case "punctuationEnhanced":
            output["punctuation_enhanced"] = value
        default:
            output[key] = value
        }
    }
    return output
}

private func gladiaNestedOptions(_ value: JSONValue, mapping: [String: String]) -> JSONValue {
    guard let object = value.objectValue else { return value }
    return .object(mapKeys(object, mapping))
}
/// Resolves deprecated options before serialization so only current API fields reach Gladia.
private func gladiaResolvedOptions(_ options: [String: JSONValue], modelID: String) -> (body: [String: JSONValue], warnings: [AIWarning]) {
    var warnings: [AIWarning] = []
    var current = options
    for key in ["contextPrompt", "moderation", "chapterization", "nameConsistency", "structuredDataExtraction", "structuredDataExtractionConfig", "displayMode"] {
        if let value = current.removeValue(forKey: key), value != .null {
            warnings.append(.init(type: "unsupported", feature: key, message: "No longer supported by the Gladia v2 pre-recorded API; ignored."))
        }
    }
    if var diarization = current["diarizationConfig"]?.objectValue, let value = diarization.removeValue(forKey: "enhanced"), value != .null {
        warnings.append(.init(type: "unsupported", feature: "diarizationConfig.enhanced", message: "No longer supported by the Gladia v2 pre-recorded API; ignored."))
        current["diarizationConfig"] = .object(diarization)
    }
    var language = current.removeValue(forKey: "languageConfig")?.objectValue
    let explicitLanguage = language != nil
    if language == nil {
        var resolved: [String: JSONValue] = [:]
        if let switching = options["enableCodeSwitching"], switching != .null { resolved["codeSwitching"] = switching }
        if options["enableCodeSwitching"] == .bool(true), let languages = options["codeSwitchingConfig"]?["languages"], languages != .null {
            resolved["languages"] = languages
        } else if let value = options["language"]?.stringValue {
            resolved["languages"] = .array([.string(value)])
        } else if options["detectLanguage"] == .bool(true) { resolved["languages"] = .array([JSONValue]()) }
        if !resolved.isEmpty { language = resolved }
    }
    for key in ["language", "detectLanguage", "enableCodeSwitching", "codeSwitchingConfig"] {
        if let value = current.removeValue(forKey: key), value != .null {
            warnings.append(.init(type: "deprecated", setting: key, message: explicitLanguage ? "Ignored because languageConfig is provided; remove this deprecated option." : "Use languageConfig instead."))
        }
    }
    if let vocabulary = current["customVocabulary"]?.arrayValue {
        warnings.append(.init(type: "deprecated", setting: "customVocabulary", message: "Use customVocabulary: true with customVocabularyConfig instead of an array."))
        if current["customVocabularyConfig"]?["vocabulary"] != nil {
            warnings.append(.init(type: "other", message: "customVocabularyConfig.vocabulary overrides the deprecated customVocabulary array."))
            current["customVocabulary"] = .bool(true)
        } else {
            let valid = vocabulary.filter { item in
                if item.stringValue != nil { return true }
                guard item["value"]?.stringValue != nil else { return false }
                if let value = item["intensity"], value != .null, value.doubleValue?.isFinite != true { return false }
                if let value = item["language"], value != .null, value.stringValue == nil { return false }
                if let value = item["pronunciations"], value != .null, value.arrayValue?.allSatisfy({ $0.stringValue != nil }) != true { return false }
                return true
            }
            let mapped = valid.map { item -> JSONValue in
                guard let object = item.objectValue else { return item }
                return .object(object.filter { ["value", "intensity", "pronunciations", "language"].contains($0.key) && $0.value != .null })
            }
            if valid.count != vocabulary.count { warnings.append(.init(type: "other", message: "Invalid customVocabulary entries were ignored; use strings or objects with a string value and correctly typed optional fields.")) }
            current.removeValue(forKey: "customVocabulary")
            if !valid.isEmpty {
                current["customVocabulary"] = .bool(true)
                current["customVocabularyConfig"] = .object(["vocabulary": .array(mapped)])
            }
        }
    }
    current.removeValue(forKey: "pollIntervalMs"); current.removeValue(forKey: "pollTimeoutMs")
    var body = gladiaTranscriptionOptions(from: current).filter { $0.value != .null }
    if modelID != "default" { body["model"] = .string(modelID) }
    if let language { body["language_config"] = gladiaNestedOptions(.object(language), mapping: ["codeSwitching": "code_switching"]) }
    if let pii = body.removeValue(forKey: "piiRedaction") { body["pii_redaction"] = pii }
    if let pii = body.removeValue(forKey: "piiRedactionConfig") {
        body["pii_redaction_config"] = gladiaNestedOptions(pii, mapping: ["entityTypes": "entity_types", "processedTextType": "processed_text_type"])
        if options["piiRedaction"] != .bool(true) { warnings.append(.init(type: "other", message: "piiRedactionConfig has no effect unless piiRedaction is true.")) }
    }
    if let translation = body["translation_config"] { body["translation_config"] = gladiaNestedOptions(translation, mapping: ["contextAdaptation": "context_adaptation"]) }
    if modelID == "solaria-3" {
        if language?["languages"]?.arrayValue?.count != 1 { warnings.append(.init(type: "other", message: "The \"solaria-3\" model supports a single language only. Pass exactly one language in languageConfig.languages; Gladia may reject the request.")) }
        if language?["codeSwitching"] == .bool(true) { warnings.append(.init(type: "other", message: "The \"solaria-3\" model does not support code switching; Gladia may reject the request.")) }
    }
    return (body, warnings)
}
