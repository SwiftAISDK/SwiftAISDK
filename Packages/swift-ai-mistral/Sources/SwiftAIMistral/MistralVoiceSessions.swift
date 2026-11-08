import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

/// Credentials returned by the server control API. Use these with a LiveKit media client.
public struct MistralVoiceSession: Equatable, Sendable {
    public var id: String
    public var participantToken: String
    public var serverURL: String
    public init(id: String, participantToken: String, serverURL: String) { self.id = id; self.participantToken = participantToken; self.serverURL = serverURL }
}

/// Authenticated server control for Mistral managed voice agents.
/// This does not acquire microphones or implement the browser LiveKit media transport.
public struct MistralVoiceSessions: Sendable {
    private let http: AIProviderHTTPClient
    public init(http: AIProviderHTTPClient) { self.http = http }

    public func create(modelID: String, sessionConfiguration: AIRealtimeSessionConfiguration = .init(), headers: [String: String] = [:], abortSignal: AIAbortSignal? = nil) async throws -> MistralVoiceSession {
        guard !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AIError.invalidArgument(argument: "modelID", message: "Mistral voice sessions require a model ID.") }
        try abortSignal?.throwIfAborted()
        let body = try buildSessionConfiguration(sessionConfiguration, modelID: modelID)
        let response = try await http.transport.send(http.request(path: "/audio/sessions", modelID: modelID, body: body, headers: headers, abortSignal: abortSignal))
        guard (200..<300).contains(response.statusCode) else { throw audioProviderHTTPStatusError(provider: "mistral.realtime", response: response) }
        let raw = try response.jsonValue()
        guard let id = raw["id"]?.stringValue, !id.isEmpty, let token = raw["participant_token"]?.stringValue, !token.isEmpty, let server = raw["server_url"]?.stringValue, !server.isEmpty else { throw AIError.invalidResponse(provider: "mistral.realtime", message: "Mistral session response must contain non-empty id, participant_token and server_url.") }
        return .init(id: id, participantToken: token, serverURL: server)
    }

    public func close(sessionID: String, headers: [String: String] = [:], abortSignal: AIAbortSignal? = nil) async throws {
        guard !sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, sessionID != ".", sessionID != ".." else { throw AIError.invalidArgument(argument: "sessionID", message: "Mistral voice sessions require a valid session ID.") }
        try abortSignal?.throwIfAborted()
        let encoded = sessionID.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~")))!
        // Resolve credentials through the same transport as POST. Each invocation resolves once.
        var request = try http.rawRequest(path: "/audio/sessions/\(encoded)", modelID: "", body: Data(), contentType: nil, headers: headers, abortSignal: abortSignal)
        request.method = "DELETE"
        let response = try await http.transport.send(request)
        guard (200..<300).contains(response.statusCode) else { throw audioProviderHTTPStatusError(provider: "mistral.realtime", response: response) }
    }

    /// Serializes the provider's REST configuration or supported session.update subset.
    public func buildSessionConfiguration(_ config: AIRealtimeSessionConfiguration, modelID: String? = nil, update: Bool = false) throws -> JSONValue {
        func unsupported(_ name: String) -> AIError { .invalidArgument(argument: name, message: "Mistral voice agent does not support \(update ? "live update of" : "setting") \(name).") }
        if config.inputAudioFormat != nil { throw unsupported("inputAudioFormat") }
        if config.outputAudioFormat != nil { throw unsupported("outputAudioFormat") }
        if config.turnDetection != nil { throw unsupported("turnDetection") }
        if config.inputAudioTranscription?.prompt != nil { throw unsupported("inputAudioTranscription.prompt") }
        if let output = config.outputAudioTranscription, output.model != nil || output.language != nil || output.prompt != nil { throw unsupported("outputAudioTranscription settings") }
        if let modalities = config.outputModalities, !modalities.contains(.audio) { throw unsupported("outputModalities without audio") }
        if update {
            if config.voice != nil { throw unsupported("voice") }
            if config.inputAudioTranscription != nil { throw unsupported("inputAudioTranscription") }
            if config.outputAudioTranscription != nil { throw unsupported("outputAudioTranscription") }
            if config.outputModalities != nil { throw unsupported("outputModalities") }
        }
        let raw = config.providerOptions?["mistral"]
        var options: [String: JSONValue] = [:]
        if let raw, raw != .null {
            guard let object = raw.objectValue else { throw AIError.invalidArgument(argument: "providerOptions.mistral", message: "Mistral voice options must be an object.") }
            options = object
        }
        try mistralVoiceValidate(options)
        if update { for key in options.keys where key != "turn" { throw unsupported("providerOptions.mistral.\(key)") } }
        if options["agentVersion"] != nil && options["agentId"] == nil { throw AIError.invalidArgument(argument: "providerOptions.mistral.agentVersion", message: "Mistral agentVersion requires agentId.") }
        var body: [String: JSONValue] = [:]
        if let modelID { body["llm"] = .object(["model": .string(modelID)]) }
        body["instructions"] = config.instructions.map(JSONValue.string)
        body["tools"] = config.tools.map { .array($0.map { tool in
            var function: [String: JSONValue] = ["name": .string(tool.name), "parameters": tool.parameters]
            function["description"] = tool.description.map(JSONValue.string)
            return .object(["type": "function", "function": .object(function)])
        }) }
        if options["stt"] != nil || config.inputAudioTranscription != nil {
            let stt = options["stt"]?.objectValue ?? [:]
            var mapped: [String: JSONValue] = [:]
            mapped["model"] = config.inputAudioTranscription?.model.map(JSONValue.string) ?? stt["model"]
            mapped["language"] = config.inputAudioTranscription?.language.map(JSONValue.string) ?? stt["language"]
            mapped["context_bias"] = stt["contextBias"]
            mapped["target_streaming_delay_ms"] = stt["targetStreamingDelayMs"]
            if let turn = stt["turnDetection"] { mapped["turn_detection"] = try mistralTurnDetection(turn, argument: "providerOptions.mistral.stt.turnDetection") }
            body["stt"] = .object(mapped)
        }
        if options["tts"] != nil || config.voice != nil {
            let tts = options["tts"]?.objectValue ?? [:]
            var mapped: [String: JSONValue] = [:]
            mapped["model"] = tts["model"]; mapped["voice_id"] = config.voice.map(JSONValue.string) ?? tts["voiceId"]; mapped["phoneme_hints"] = tts["phonemeHints"]
            body["tts"] = .object(mapped)
        }
        if let turn = options["turn"]?.objectValue {
            var mapped: [String: JSONValue] = [:]; mapped["allow_interruptions"] = turn["allowInterruptions"]
            if let inactivity = turn["inactivity"]?.objectValue { mapped["inactivity"] = .object(mapKeys(inactivity, ["timeoutMs": "timeout_ms", "maxReminders": "max_reminders"])) }
            body["turn"] = .object(mapped)
        }
        body["welcome_message"] = options["welcomeMessage"]; body["agent_id"] = options["agentId"]; body["agent_version"] = options["agentVersion"]
        return .object(body)
    }
}

private func mistralVoiceValidate(_ options: [String: JSONValue]) throws {
    func invalid(_ path: String) -> AIError { .invalidArgument(argument: "providerOptions.mistral.\(path)", message: "Invalid or unknown Mistral voice setting.") }
    func object(_ value: JSONValue, _ path: String, keys: Set<String>) throws -> [String: JSONValue] {
        guard let object = value.objectValue, Set(object.keys).isSubset(of: keys) else { throw invalid(path) }; return object
    }
    guard Set(options.keys).isSubset(of: ["stt", "tts", "turn", "welcomeMessage", "agentId", "agentVersion"]) else { throw invalid("options") }
    for key in ["welcomeMessage", "agentId"] { if let value = options[key], value.stringValue == nil || (key == "agentId" && value.stringValue!.isEmpty) { throw invalid(key) } }
    if let version = options["agentVersion"], version.doubleValue.map({ $0.isFinite && $0 >= 0 && $0.rounded() == $0 }) != true { throw invalid("agentVersion") }
    if let value = options["stt"] {
        let stt = try object(value, "stt", keys: ["model", "language", "contextBias", "targetStreamingDelayMs", "turnDetection"])
        for key in ["model", "language"] { if let value = stt[key], value.stringValue?.isEmpty != false { throw invalid("stt.\(key)") } }
        if let bias = stt["contextBias"], bias.arrayValue?.allSatisfy({ $0.stringValue?.isEmpty == false }) != true { throw invalid("stt.contextBias") }
        if let delay = stt["targetStreamingDelayMs"], delay.doubleValue.map({ $0.rounded() == $0 && (80...1200).contains($0) }) != true { throw invalid("stt.targetStreamingDelayMs") }
        if let turn = stt["turnDetection"] {
            _ = try object(turn, "stt.turnDetection", keys: ["startThreshold", "eagerEndThreshold", "endThreshold", "minSilenceMs", "endTimeoutMs"])
            _ = try mistralTurnDetection(turn, argument: "providerOptions.mistral.stt.turnDetection")
        }
    }
    if let value = options["tts"] {
        let tts = try object(value, "tts", keys: ["model", "voiceId", "phonemeHints"])
        for key in ["model", "voiceId"] { if let value = tts[key], value.stringValue?.isEmpty != false { throw invalid("tts.\(key)") } }
        if let hints = tts["phonemeHints"] {
            guard let entries = hints.objectValue, entries.values.allSatisfy({ $0.arrayValue.map { !$0.isEmpty && $0.allSatisfy { $0.stringValue?.isEmpty == false } } == true }) else { throw invalid("tts.phonemeHints") }
        }
    }
    if let value = options["turn"] {
        let turn = try object(value, "turn", keys: ["allowInterruptions", "inactivity"])
        if let allow = turn["allowInterruptions"], allow.boolValue == nil { throw invalid("turn.allowInterruptions") }
        if let value = turn["inactivity"] {
            let inactivity = try object(value, "turn.inactivity", keys: ["timeoutMs", "maxReminders", "messages"])
            for key in ["timeoutMs", "maxReminders"] { if let value = inactivity[key], value.doubleValue.map({ $0.isFinite && $0 >= 0 && $0.rounded() == $0 }) != true { throw invalid("turn.inactivity.\(key)") } }
            if let messages = inactivity["messages"], messages.arrayValue?.allSatisfy({ $0.stringValue != nil }) != true { throw invalid("turn.inactivity.messages") }
        }
    }
}

public extension MistralVoiceSessions {
    /// Maps managed-agent messages. Revised partial transcripts replace text and emit no delta.
    static func parseServerEvent(_ raw: JSONValue) throws -> [AIRealtimeServerEvent] {
        func malformed() -> AIError { .invalidResponse(provider: "mistral.realtime", message: "Invalid Mistral voice agent event.") }
        switch raw["type"]?.stringValue {
        case "transcription.segment":
            guard let id = raw["id"]?.stringValue, let role = raw["role"]?.stringValue, ["user", "assistant"].contains(role), let content = raw["content"]?.stringValue, let final = raw["final"]?.boolValue else { throw malformed() }
            guard final else { return [] }
            if role == "user" { return [.inputTranscriptionCompleted(itemID: id, transcript: content, raw: raw)] }
            return [.responseCreated(responseID: id, raw: raw), .audioTranscriptDelta(responseID: id, itemID: id, delta: content, raw: raw), .audioTranscriptDone(responseID: id, itemID: id, transcript: content, raw: raw), .responseDone(responseID: id, status: "completed", raw: raw)]
        case "session.updated": return [.sessionUpdated(raw: raw)]
        case "error":
            guard let message = raw["message"]?.stringValue, let code = raw["code"]?.stringValue, raw["fatal"]?.boolValue != nil else { throw malformed() }
            return [.error(message: message, code: code, raw: raw)]
        default: return [.custom(rawType: raw["type"]?.stringValue ?? "unknown", raw: raw)]
        }
    }
}
