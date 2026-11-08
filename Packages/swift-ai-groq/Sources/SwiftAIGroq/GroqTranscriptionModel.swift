import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities


public final class GroqTranscriptionModel: TranscriptionModel, @unchecked Sendable {
    public let providerID = "groq.transcription"
    public let modelID: String
    private let config: GroqHTTPConfiguration

    public init(modelID: String, http: AIProviderHTTPClient) {
        self.modelID = modelID
        self.config = GroqHTTPConfiguration(http: http)
    }

    public func transcribe(_ request: AudioTranscriptionRequest) async throws -> TranscriptionResult {
        try await generate(request)
    }

    public func transcribeFromURL(_ request: AudioURLTranscriptionRequest) async throws -> TranscriptionResult? {
        guard ["https", "http"].contains(request.audio.scheme?.lowercased() ?? ""), request.audio.user == nil, request.audio.password == nil else {
            throw AIError.invalidArgument(argument: "audio", message: "Groq URL transcription requires an HTTP(S) URL without userinfo.")
        }
        var components = URLComponents(url: request.audio, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        let local = AudioTranscriptionRequest(audio: Data(), language: request.language, prompt: request.prompt, providerOptions: request.providerOptions, extraBody: request.extraBody, headers: request.headers, abortSignal: request.abortSignal, timestampGranularities: request.timestampGranularities)
        do { return try await generate(local, audioURL: components?.url ?? request.audio) }
        catch AIError.apiCall(let error) {
            let message = error.message ?? error.responseBody
            if error.statusCode == 400, message.range(of: #"^failed to retrieve media: received status code: (301|302|303|307|308)\b"#, options: .regularExpression) != nil { return nil }
            throw AIError.apiCall(error)
        }
    }

    private func generate(_ request: AudioTranscriptionRequest, audioURL: URL? = nil) async throws -> TranscriptionResult {
        var form = MultipartFormData()
        form.appendField(name: "model", value: modelID)
        let uploadFileName = "audio.\(mediaTypeToExtension(request.mimeType))"
        if let audioURL { form.appendField(name: "url", value: audioURL.absoluteString) }
        else { form.appendFile(name: "file", fileName: uploadFileName, mimeType: request.mimeType, data: request.audio) }
        var metadataBody: [String: JSONValue] = [
            "model": .string(modelID),
            "filename": .string(uploadFileName),
            "mime_type": .string(request.mimeType)
        ]
        if let audioURL { metadataBody = ["model": .string(modelID), "url": .string(audioURL.absoluteString)] }
        if let language = request.language {
            form.appendField(name: "language", value: language)
            metadataBody["language"] = .string(language)
        }
        if let prompt = request.prompt {
            form.appendField(name: "prompt", value: prompt)
            metadataBody["prompt"] = .string(prompt)
        }

        let providerOptions = try groqTranscriptionOptions(from: request)
        if let language = providerOptions["language"]?.stringValue, request.language == nil {
            form.appendField(name: "language", value: language)
            metadataBody["language"] = .string(language)
        }
        if let prompt = providerOptions["prompt"]?.stringValue, request.prompt == nil {
            form.appendField(name: "prompt", value: prompt)
            metadataBody["prompt"] = .string(prompt)
        }

        for (key, value) in providerOptions where key != "language" && key != "prompt" {
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
        let response = try await config.transport.send(config.rawRequest(
            path: "/audio/transcriptions",
            modelID: modelID,
            body: body,
            contentType: "multipart/form-data; boundary=\(form.boundary)",
            headers: request.headers,
            abortSignal: request.abortSignal
        ))
        guard (200..<300).contains(response.statusCode) else {
            let raw = try? response.jsonValue()
            var detail = AIAPICallError(provider: providerID, statusCode: response.statusCode, responseHeaders: response.headers, responseBody: response.bodyText)
            detail.message = raw?["error"]?["message"]?.stringValue
            throw AIError.apiCall(detail)
        }
        if providerOptions["response_format"]?.stringValue == "text" {
            let text = String(decoding: response.body, as: UTF8.self)
            let raw: JSONValue = .string(text)
            return TranscriptionResult(
                text: text,
                rawValue: raw,
                requestMetadata: AIRequestMetadata(body: .object(metadataBody), headers: request.headers),
                responseMetadata: aiResponseMetadata(from: raw, response: response, modelID: modelID)
            )
        }
        let raw = try response.jsonValue()
        guard let text = raw["text"]?.stringValue else {
            throw AIError.invalidResponse(provider: providerID, message: "No transcription text found.")
        }
        try validateGroqTranscriptionResponse(raw)
        let segments: [TranscriptionSegment]
        if let rawSegments = raw["segments"], rawSegments != .null {
            segments = standardTranscriptionSegments(from: raw)
        } else {
            segments = transcriptionSegments(from: raw["words"], textKey: "word")
        }
        return TranscriptionResult(
            text: text,
            rawValue: raw,
            segments: segments,
            language: raw["language"]?.stringValue,
            durationInSeconds: raw["duration"]?.doubleValue,
            requestMetadata: AIRequestMetadata(body: .object(metadataBody), headers: request.headers),
            responseMetadata: aiResponseMetadata(from: raw, response: response, modelID: modelID)
        )
    }
}

func validateGroqTranscriptionResponse(_ raw: JSONValue) throws {
    guard raw["x_groq"]?["id"]?.stringValue != nil else {
        throw AIError.invalidResponse(provider: "groq.transcription", message: "Groq transcription response is invalid.")
    }
    if let task = raw["task"], task != .null, task.stringValue == nil {
        throw AIError.invalidResponse(provider: "groq.transcription", message: "Groq transcription response is invalid.")
    }
    if let language = raw["language"], language != .null, language.stringValue == nil {
        throw AIError.invalidResponse(provider: "groq.transcription", message: "Groq transcription response is invalid.")
    }
    if let duration = raw["duration"], duration != .null, duration.doubleValue == nil {
        throw AIError.invalidResponse(provider: "groq.transcription", message: "Groq transcription response is invalid.")
    }
    if let segments = raw["segments"], segments != .null {
        guard let array = segments.arrayValue else {
            throw AIError.invalidResponse(provider: "groq.transcription", message: "Groq transcription response is invalid.")
        }
        for segment in array {
            guard
                segment["id"]?.doubleValue != nil,
                segment["seek"]?.doubleValue != nil,
                segment["start"]?.doubleValue != nil,
                segment["end"]?.doubleValue != nil,
                segment["text"]?.stringValue != nil,
                let tokens = segment["tokens"]?.arrayValue,
                segment["temperature"]?.doubleValue != nil,
                segment["avg_logprob"]?.doubleValue != nil,
                segment["compression_ratio"]?.doubleValue != nil,
                segment["no_speech_prob"]?.doubleValue != nil
            else {
                throw AIError.invalidResponse(provider: "groq.transcription", message: "Groq transcription response is invalid.")
            }
            guard tokens.allSatisfy({ $0.doubleValue != nil }) else {
                throw AIError.invalidResponse(provider: "groq.transcription", message: "Groq transcription response is invalid.")
            }
        }
    }
    if let words = raw["words"], words != .null {
        guard let array = words.arrayValue else {
            throw AIError.invalidResponse(provider: "groq.transcription", message: "Groq transcription response is invalid.")
        }
        for word in array {
            guard
                word["word"]?.stringValue != nil,
                word["start"]?.doubleValue != nil,
                word["end"]?.doubleValue != nil
            else {
                throw AIError.invalidResponse(provider: "groq.transcription", message: "Groq transcription response is invalid.")
            }
        }
    }
}
