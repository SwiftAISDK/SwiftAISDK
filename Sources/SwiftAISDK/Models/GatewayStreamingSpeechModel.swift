import Foundation

public typealias GatewaySpeechFactoryGetTokenOptions = GatewayTranscriptionFactoryGetTokenOptions
public typealias GatewaySpeechFactoryGetTokenResult = GatewayTranscriptionFactoryGetTokenResult

/// Mints speech-bound client secrets on a trusted server and constructs native
/// duplex speech models. A returned token can be supplied as the client's key.
public struct GatewaySpeechFactory: Sendable {
    private let config: ModelHTTPConfig
    private let webSocketTransport: any AIDuplexWebSocketTransport
    init(config: ModelHTTPConfig, webSocketTransport: any AIDuplexWebSocketTransport) { self.config = config; self.webSocketTransport = webSocketTransport }
    public func callAsFunction(_ modelID: String) -> GatewaySpeechModel { GatewaySpeechModel(modelID: modelID, config: config, webSocketTransport: webSocketTransport) }
    public func getToken(_ options: GatewaySpeechFactoryGetTokenOptions) async throws -> GatewaySpeechFactoryGetTokenResult {
        let body: JSONValue = .object(["model": .string(options.model), "routeKind": "speech", "expiresIn": options.expiresAfterSeconds.map { .number(Double($0)) }])
        let response: AIHTTPResponse
        do {
            response = try await config.transport.send(AIHTTPRequest(method: "POST", url: try gatewaySpeechOriginURL(config.baseURL),
                                                                      headers: config.headers.mergingHeaders(["content-type": "application/json"]), body: try encodeJSONBody(body)))
        } catch { throw speechGatewayConnectionError(error) }
        guard (200..<300).contains(response.statusCode) else {
            throw gatewayErrorFromHTTPStatus(statusCode: response.statusCode, body: response.bodyText, headers: response.headers)
        }
        let raw = try response.jsonValue()
        guard let token = raw["token"]?.stringValue, !token.isEmpty else { throw AIError.invalidResponse(provider: "gateway", message: "Gateway speech client-secret response did not contain a non-empty token.") }
        return .init(token: token, url: try gatewaySpeechWebSocketURL(baseURL: config.baseURL, modelID: options.model).absoluteString, expiresAt: raw["expiresAt"]?.intValue)
    }
}

private func gatewaySpeechOriginURL(_ base: String) throws -> URL {
    guard var value = URLComponents(string: base) else { throw AIError.invalidURL(base) }
    value.path = "/v1/realtime/client-secrets"; value.query = nil; value.fragment = nil
    guard let url = value.url else { throw AIError.invalidURL(base) }; return url
}

extension GatewaySpeechModel {
    public func stream(_ request: StreamingSpeechRequest) async throws -> StreamingSpeechModelResult {
        do {
            try request.abortSignal?.throwIfAborted()
            let headers = config.headers.mergingHeaders(request.headers).mergingHeaders(["ai-speech-model-specification-version": "4", "ai-model-id": modelID])
            let connection = try await webSocketTransport.connect(.init(url: try gatewaySpeechWebSocketURL(baseURL: config.baseURL, modelID: modelID),
                                                                        headers: headers, protocols: gatewaySpeechProtocols(headers), abortSignal: request.abortSignal))
            let start = SpeechStreamEnvelope.startFrame(request)
            let session = SpeechSocketSession(connection: connection, input: request.text, abortSignal: request.abortSignal,
                                              startFrame: start, decode: { text in
                guard let part = SpeechStreamEnvelope.parsePart(text) else { return [] }
                if case let .error(error) = part {
                    let raw = (error as? AIStreamingSpeechError)?.rawValue ?? .string(String(describing: error))
                    return [.error(speechGatewayServerError(raw))]
                }
                return [part]
            }, inputPump: { session in
                for try await part in request.text {
                    var pieces = splitSpeechTextDelta(part.text)
                    if pieces.isEmpty && (part.voice != nil || !part.providerOptions.isEmpty) { pieces = [""] }
                    for (index, piece) in pieces.enumerated() {
                        try await session.send(.object(["type": .string(SpeechStreamEnvelope.textDeltaFrameType), "delta": .string(piece),
                                                        "voice": part.voice.map(JSONValue.string),
                                                        "providerOptions": index == 0 && !part.providerOptions.isEmpty ? .object(part.providerOptions) : nil]))
                    }
                }
                try await session.send(.object(["type": .string(SpeechStreamEnvelope.textDoneFrameType)]))
            }, connectionError: speechGatewayConnectionError)
            return .init(stream: session.makeStream(), requestMetadata: .init(body: start, headers: request.headers),
                         responseMetadata: .init(timestamp: Date(), modelID: modelID), cancel: { session.cancel() })
        } catch { request.text.cancelFromConsumer(); throw speechGatewayConnectionError(error) }
    }
}

func gatewaySpeechWebSocketURL(baseURL: String, modelID: String) throws -> URL {
    guard var components = URLComponents(string: baseURL) else { throw AIError.invalidURL(baseURL) }
    switch components.scheme?.lowercased() {
    case "https": components.scheme = "wss"
    case "http": components.scheme = "ws"
    case "wss", "ws": break
    default: throw AIError.invalidURL(baseURL)
    }
    components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    components.path = "/" + components.path + (components.path.isEmpty ? "" : "/") + "speech-model"
    var allowed = CharacterSet.urlQueryAllowed; allowed.remove(charactersIn: "/?&=+")
    components.percentEncodedQuery = "ai-model-id=" + (modelID.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")
    components.fragment = nil
    guard let url = components.url else { throw AIError.invalidURL(baseURL) }; return url
}

func gatewaySpeechProtocols(_ headers: [String: String]) -> [String] {
    let headers = normalizeHeaders(headers)
    var result = ["ai-gateway-speech.v1"]
    guard let authorization = headers["authorization"], authorization.hasPrefix("Bearer ") else { return result }
    result.append("ai-gateway-auth." + authorization.dropFirst(7))
    if let team = headers["x-vercel-ai-gateway-team"], !team.isEmpty {
        result.append("ai-gateway-team." + Data(team.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: ""))
    }
    return result
}

func splitSpeechTextDelta(_ delta: String) -> [String] {
    var output: [String] = []; var piece = ""; var count = 0
    for scalar in delta.unicodeScalars {
        let size = scalar.utf16.count
        if count + size > 8 * 1024 { output.append(piece); piece = ""; count = 0 }
        piece.unicodeScalars.append(scalar); count += size
    }
    if !piece.isEmpty { output.append(piece) }; return output
}

func speechGatewayServerError(_ raw: JSONValue) -> any Error {
    let codes: [String: Int] = ["authentication_error": 401, "failed_dependency": 424, "forbidden": 403,
                               "internal_server_error": 500, "invalid_request_error": 400, "model_not_found": 404, "rate_limit_exceeded": 429]
    if let type = raw["type"]?.stringValue, let code = codes[type], let message = raw["message"]?.stringValue,
       let kind = GatewayErrorType(rawValue: type) { return GatewayError(type: kind, message: message, statusCode: code, response: .object(["error": raw])) }
    return AIStreamingSpeechError(provider: "gateway", message: "AI Gateway speech stream failed: " + (raw["message"]?.stringValue ?? raw.stringValue ?? String(describing: raw)), rawValue: raw)
}

func speechGatewayConnectionError(_ error: any Error) -> any Error {
    if error is GatewayError || error is AIAbortError || error is CancellationError || error is AIStreamingSpeechError { return error }
    return GatewayError(type: .internalServerError, message: "Connection error on AI Gateway speech stream: \(error)", statusCode: 500)
}

/// Shared native socket lifecycle. Async sends apply transport backpressure;
/// every terminal path releases both input and connection.
final class SpeechSocketSession: @unchecked Sendable {
    private let lock = NSLock()
    private let connection: any AIDuplexWebSocketConnection
    private let input: AIStreamingTextInput
    private let abortSignal: AIAbortSignal?
    private let startFrame: JSONValue
    private let initialParts: [StreamingSpeechPart]
    private let decode: @Sendable (String) throws -> [StreamingSpeechPart]
    private let inputPump: @Sendable (SpeechSocketSession) async throws -> Void
    private let connectionError: @Sendable (any Error) -> any Error
    private let keepaliveFrame: JSONValue?
    private var continuation: AsyncThrowingStream<StreamingSpeechPart, Error>.Continuation?
    private var tasks: [Task<Void, Never>] = []
    private var registration: AIAbortHandlerRegistration?
    private var completed = false
    private var inputEnded = false
    private var lastSend = Date()
    private var serverError: (any Error)?

    init(connection: any AIDuplexWebSocketConnection, input: AIStreamingTextInput, abortSignal: AIAbortSignal?, startFrame: JSONValue,
         initialParts: [StreamingSpeechPart] = [], keepaliveFrame: JSONValue? = nil,
         decode: @escaping @Sendable (String) throws -> [StreamingSpeechPart],
         inputPump: @escaping @Sendable (SpeechSocketSession) async throws -> Void,
         connectionError: @escaping @Sendable (any Error) -> any Error = { $0 }) {
        self.connection = connection; self.input = input; self.abortSignal = abortSignal; self.startFrame = startFrame
        self.initialParts = initialParts; self.keepaliveFrame = keepaliveFrame; self.decode = decode
        self.inputPump = inputPump; self.connectionError = connectionError
    }

    func makeStream() -> AsyncThrowingStream<StreamingSpeechPart, Error> {
        AsyncThrowingStream { continuation in
            lock.withLock { self.continuation = continuation }
            continuation.onTermination = { [weak self] termination in if case .cancelled = termination { self?.cancel() } }
            let registration = abortSignal?.addAbortHandler { [weak self, weak signal = abortSignal] reason in self?.finish(AIAbortError(reason: reason, reasonName: signal?.reasonName)) }
            let accepted = lock.withLock { () -> Bool in if completed { return false }; self.registration = registration; return true }
            if !accepted { registration?.cancel() }
            let task = Task { [self] in await consumeEvents() }; add(task)
        }
    }

    func send(_ frame: JSONValue) async throws {
        try Task.checkCancellation(); try abortSignal?.throwIfAborted()
        guard lock.withLock({ !completed && serverError == nil }) else { throw CancellationError() }
        let text = String(decoding: try encodeJSONBody(frame), as: UTF8.self)
        try await connection.send(text: text)
        lock.withLock { lastSend = Date() }
    }

    func cancel() { finish(AIAbortError(reason: "Speech stream was cancelled.")) }

    private func add(_ task: Task<Void, Never>) { let active = lock.withLock { () -> Bool in if completed { return false }; tasks.append(task); return true }; if !active { task.cancel() } }

    private func consumeEvents() async {
        do {
            for try await event in connection.events {
                if lock.withLock({ completed }) { return }
                switch event {
                case .opened:
                    for part in initialParts { lock.withLock { continuation }?.yield(part) }
                    try await send(startFrame)
                    let task = Task { [self] in
                        do { try await inputPump(self); lock.withLock { inputEnded = true } }
                        catch { if !lock.withLock({ completed || serverError != nil }) { finish(connectionError(error)) } }
                    }; add(task)
                    if let keepaliveFrame {
                        add(Task { [self] in
                            do {
                                while !Task.isCancelled {
                                    try await Task.sleep(nanoseconds: 1_000_000_000)
                                    let idle = lock.withLock { !completed && !inputEnded && Date().timeIntervalSince(lastSend) >= 15 }
                                    if idle { try await send(keepaliveFrame) }
                                }
                            } catch { if !lock.withLock({ completed || inputEnded }) { finish(error) } }
                        })
                    }
                case let .message(.text(text)):
                    for part in try decode(text) {
                        if case let .error(error) = part { lock.withLock { serverError = error }; input.cancelFromConsumer() }
                        lock.withLock { continuation }?.yield(part)
                        if case .finish = part { finish(nil); return }
                    }
                case .message(.binary): break
                case let .closed(metadata):
                    let error = lock.withLock { serverError } ?? AIStreamingSpeechError(provider: "speech", message: "Speech stream closed before completion (code \(metadata.code)\(metadata.reason.map { ": " + $0 } ?? "")).")
                    finish(connectionError(error)); return
                }
            }
            if !lock.withLock({ completed }) {
                let failure: (any Error)? = lock.withLock { serverError }
                let error: any Error = failure ?? AIStreamingSpeechError(provider: "speech", message: "Speech stream ended before completion.")
                finish(error)
            }
        } catch { finish(connectionError(error)) }
    }

    private func finish(_ error: (any Error)?) {
        let resources = lock.withLock { () -> (AsyncThrowingStream<StreamingSpeechPart, Error>.Continuation?, [Task<Void, Never>], AIAbortHandlerRegistration?) in
            guard !completed else { return (nil, [], nil) }; completed = true
            let values = (continuation, tasks, registration); continuation = nil; tasks = []; registration = nil; return values
        }
        guard let continuation = resources.0 else { return }
        resources.2?.cancel(); for task in resources.1 { task.cancel() }; input.cancelFromConsumer()
        if let error { continuation.finish(throwing: error) } else { continuation.finish() }
        Task { await connection.close(code: 1000) }
    }
}
