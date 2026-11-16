import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

/// Realtime Ink speech-to-text model using Cartesia's STT WebSocket APIs.
///
/// Mirrors upstream `CartesiaRealtimeModel` (`experimental_realtime`): it mints
/// a short-lived access token, selects the turn-detected (`/stt/turns/websocket`)
/// or manual-finalize (`/stt/websocket`) endpoint, sends audio as binary frames
/// and normalizes Ink 2 turn and transcript events. Like upstream, the event
/// parser and finalize mode are per-model state, so use one model instance per
/// realtime session.
public final class CartesiaRealtimeModel: AIRealtimeModelV4, AIRealtimeModelV4ValidationHooks, @unchecked Sendable {
    public let specificationVersion = "v4"
    public let providerID: String
    public let modelID: String

    private let config: CartesiaHTTPConfiguration
    private let version: String
    private let currentDate: @Sendable () -> Date

    private let lock = NSLock()
    private var manualText = ""
    private var manualDuration = 0.0
    private var manualEvents: [JSONValue] = []
    private var sessionCreated = false
    private var useTurnDetection = true

    init(
        modelID: String,
        config: CartesiaHTTPConfiguration,
        version: String,
        currentDate: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.providerID = "cartesia.realtime"
        self.modelID = modelID
        self.config = config
        self.version = version
        self.currentDate = currentDate
    }

    public func doCreateClientSecret(
        _ options: AIRealtimeClientSecretOptions
    ) async throws -> AIRealtimeClientSecretResult {
        let expiresIn = options.expiresAfterSeconds
        if let expiresIn, expiresIn <= 0 || expiresIn > 3600 {
            throw AIError.invalidArgument(
                argument: "expiresAfterSeconds",
                message: "Cartesia realtime client secrets must expire between 1 and 3600 seconds."
            )
        }

        let sessionConfig = options.sessionConfig
        let language = sessionConfig?.inputAudioTranscription?.language
        if let language, language != "en" {
            throw AIError.invalidArgument(
                argument: "sessionConfig.inputAudioTranscription.language",
                message: "Cartesia Ink 2 currently supports English only."
            )
        }

        var body: [String: JSONValue] = ["grants": .object(["stt": .bool(true)])]
        if let expiresIn {
            body["expires_in"] = .number(Double(expiresIn))
        }
        let response = try await config.transport.send(config.request(
            path: "/access-token",
            modelID: modelID,
            body: .object(body),
            abortSignal: options.abortSignal
        ))
        guard (200..<300).contains(response.statusCode) else {
            throw apiCallError(
                provider: providerID,
                statusCode: response.statusCode,
                body: "Cartesia realtime client secret request failed: \(response.statusCode) \(response.bodyText)",
                headers: response.headers
            )
        }
        let raw = try response.jsonValue()
        guard let token = raw["token"]?.stringValue, !token.isEmpty else {
            throw AIError.invalidResponse(
                provider: providerID,
                message: "Cartesia realtime client secret response did not include a token."
            )
        }

        // Swift has no separate `null` turn detection; a missing configuration
        // keeps Cartesia's turn detection and `.disabled` selects manual finalize.
        let useTurnDetection = sessionConfig?.turnDetection?.type != .disabled
        let encoding = try cartesiaRealtimeEncoding(sessionConfig?.inputAudioFormat?.type)
        let path = useTurnDetection ? "/stt/turns/websocket" : "/stt/websocket"
        let baseURL = try config.url(modelID, path)
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw AIError.invalidURL(baseURL.absoluteString)
        }
        components.scheme = components.scheme?.lowercased() == "http" ? "ws" : "wss"
        var items = [
            URLQueryItem(name: "model", value: modelID),
            URLQueryItem(name: "encoding", value: encoding),
            URLQueryItem(name: "sample_rate", value: String(sessionConfig?.inputAudioFormat?.rate ?? 24_000)),
            URLQueryItem(name: "cartesia_version", value: version)
        ]
        if !useTurnDetection, let language {
            items.append(URLQueryItem(name: "language", value: language))
        }
        components.queryItems = (components.queryItems ?? []) + items
        guard let url = components.url else {
            throw AIError.invalidURL(baseURL.absoluteString)
        }

        return AIRealtimeClientSecretResult(
            token: token,
            url: url.absoluteString,
            expiresAt: expiresIn.map { Int(currentDate().timeIntervalSince1970.rounded(.down)) + $0 }
        )
    }

    public func getWebSocketConfig(token: String, url: String) -> AIRealtimeWebSocketConfiguration {
        (try? getValidatedWebSocketConfig(token: token, url: url)) ?? AIRealtimeWebSocketConfiguration(url: url)
    }

    public func getValidatedWebSocketConfig(token: String, url: String) throws -> AIRealtimeWebSocketConfiguration {
        guard var components = URLComponents(string: url), components.scheme != nil else {
            throw AIError.invalidURL(url)
        }
        withLock { useTurnDetection = components.path.contains("/stt/turns/websocket") }
        var items = components.queryItems ?? []
        if let index = items.firstIndex(where: { $0.name == "access_token" }) {
            items[index].value = token
            var seen = false
            items.removeAll { item in
                guard item.name == "access_token" else { return false }
                defer { seen = true }
                return seen
            }
        } else {
            items.append(URLQueryItem(name: "access_token", value: token))
        }
        components.queryItems = items
        guard let resolved = components.url else { throw AIError.invalidURL(url) }
        return AIRealtimeWebSocketConfiguration(url: resolved.absoluteString)
    }

    public func buildSessionConfig(_ config: AIRealtimeSessionConfiguration) -> JSONValue {
        .null
    }

    public func buildValidatedSessionConfig(_ config: AIRealtimeSessionConfiguration) throws -> JSONValue {
        .null
    }

    public func serializeClientEvent(_ event: AIRealtimeClientEvent) async throws -> AIRealtimeWireMessage? {
        switch event {
        case .sessionUpdate, .sessionUpdateWithEventID, .inputAudioClear, .responseCreate:
            return nil
        case let .inputAudioAppend(audio), let .inputAudioAppendWithEventID(audio, _):
            guard let data = Data(base64Encoded: audio) else {
                throw AIError.invalidArgument(argument: "audio", message: "Realtime input audio must be base64 encoded.")
            }
            return .binary(data)
        case .inputAudioCommit:
            return withLock { useTurnDetection } ? nil : .text("finalize")
        default:
            throw AIError.invalidArgument(
                argument: "event",
                message: "Cartesia Ink 2 does not support realtime client event \"\(cartesiaRealtimeClientEventType(event))\"."
            )
        }
    }

    public func parseServerEvent(_ raw: JSONValue) -> [AIRealtimeServerEvent] {
        withLock { parseServerEventLocked(raw) }
    }

    private func parseServerEventLocked(_ raw: JSONValue) -> [AIRealtimeServerEvent] {
        let type = raw["type"]?.stringValue ?? ""
        let requestID = raw["request_id"]?.stringValue ?? "cartesia-realtime"
        let mapped: [AIRealtimeServerEvent]

        switch type {
        case "connected":
            sessionCreated = true
            return [.sessionCreated(sessionID: raw["request_id"]?.stringValue, raw: raw)]
        case "turn.start":
            mapped = [.speechStarted(itemID: requestID, raw: raw)]
        case "turn.resume":
            mapped = [.speechStarted(itemID: requestID, raw: raw), .custom(rawType: type, raw: raw)]
        case "turn.end":
            mapped = [
                .speechStopped(itemID: requestID, raw: raw),
                .inputTranscriptionCompleted(itemID: requestID, transcript: raw["transcript"]?.stringValue ?? "", raw: raw)
            ]
        case "transcript":
            if raw["is_final"]?.boolValue == true {
                manualText += raw["text"]?.stringValue ?? ""
                manualDuration += raw["duration"]?.doubleValue ?? 0
                manualEvents.append(raw)
            }
            mapped = [.custom(rawType: type, raw: raw)]
        case "flush_done":
            mapped = finishManualTranscript(raw)
        case "done":
            if manualText.isEmpty {
                mapped = [.custom(rawType: type, raw: raw)]
            } else {
                mapped = finishManualTranscript(raw) + [.custom(rawType: type, raw: raw)]
            }
        case "error":
            mapped = [.error(
                message: raw["message"]?.stringValue ?? "Unknown Cartesia realtime error",
                code: raw["error_code"]?.stringValue,
                raw: raw
            )]
        default:
            mapped = [.custom(rawType: type, raw: raw)]
        }

        guard !sessionCreated else { return mapped }
        sessionCreated = true
        return [.sessionCreated(sessionID: requestID, raw: raw)] + mapped
    }

    private func finishManualTranscript(_ raw: JSONValue) -> [AIRealtimeServerEvent] {
        let text = manualText, duration = manualDuration, events = manualEvents
        manualText = ""; manualDuration = 0; manualEvents = []
        guard !text.isEmpty else {
            return [.custom(rawType: raw["type"]?.stringValue ?? "", raw: raw)]
        }
        return [
            .audioCommitted(itemID: raw["request_id"]?.stringValue, previousItemID: nil, raw: raw),
            .inputTranscriptionCompleted(
                itemID: raw["request_id"]?.stringValue ?? "cartesia-realtime",
                transcript: text,
                raw: .object([
                    "event": raw,
                    "transcriptEvents": .array(events),
                    "duration": .number(duration)
                ])
            )
        ]
    }

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}

private func cartesiaRealtimeEncoding(_ type: String?) throws -> String {
    switch type {
    case nil, "audio/pcm":
        return "pcm_s16le"
    case "audio/pcmu":
        return "pcm_mulaw"
    case "audio/pcma":
        return "pcm_alaw"
    case let type?:
        throw AIError.invalidArgument(
            argument: "inputAudioFormat",
            message: "Unsupported Cartesia realtime audio format: \(type)"
        )
    }
}

private func cartesiaRealtimeClientEventType(_ event: AIRealtimeClientEvent) -> String {
    switch event {
    case .sessionUpdate, .sessionUpdateWithEventID: "session-update"
    case .sessionStart: "session-start"
    case .sessionClose: "session-close"
    case .inputAudioMute: "input-audio-mute"
    case .inputAudioUnmute: "input-audio-unmute"
    case .contextAppend: "context-append"
    case .inputAudioAppend, .inputAudioAppendWithEventID: "input-audio-append"
    case .inputAudioCommit: "input-audio-commit"
    case .inputAudioClear: "input-audio-clear"
    case .conversationItemCreate: "conversation-item-create"
    case .conversationItemTruncate: "conversation-item-truncate"
    case .responseCreate: "response-create"
    case .responseCancel: "response-cancel"
    }
}
