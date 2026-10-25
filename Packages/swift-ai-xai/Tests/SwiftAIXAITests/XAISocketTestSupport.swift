import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
final class RealtimeTestWebSocketTransport:
    AIDuplexWebSocketTransport,
    @unchecked Sendable {
    let connection = RealtimeTestWebSocketConnection()

    private let lock = NSLock()
    private var recordedRequests: [AIDuplexWebSocketRequest] = []

    func connect(
        _ request: AIDuplexWebSocketRequest
    ) async throws -> any AIDuplexWebSocketConnection {
        record(request)
        return connection
    }

    private func record(_ request: AIDuplexWebSocketRequest) {
        lock.lock()
        recordedRequests.append(request)
        lock.unlock()
    }

    func requests() -> [AIDuplexWebSocketRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }
}

final class RealtimeTestWebSocketConnection:
    AIDuplexWebSocketConnection,
    @unchecked Sendable {
    let events: AsyncThrowingStream<AIDuplexWebSocketEvent, Error>

    private let continuation:
        AsyncThrowingStream<AIDuplexWebSocketEvent, Error>.Continuation
    private let lock = NSLock()
    private var sent: [AIDuplexWebSocketMessage] = []
    private var closes: [(code: Int, reason: Data?)] = []

    init() {
        let pair = AsyncThrowingStream<AIDuplexWebSocketEvent, Error>
            .makeStream()
        events = pair.stream
        continuation = pair.continuation
    }

    func send(_ message: AIDuplexWebSocketMessage) async throws {
        record(message)
    }

    private func record(_ message: AIDuplexWebSocketMessage) {
        lock.lock()
        sent.append(message)
        lock.unlock()
    }

    func close(code: Int, reason: Data?) async {
        recordClose(code: code, reason: reason)
        continuation.finish()
    }

    private func recordClose(code: Int, reason: Data?) {
        lock.lock()
        closes.append((code, reason))
        lock.unlock()
    }

    func open(protocol: String? = nil) {
        continuation.yield(.opened(protocol: `protocol`))
    }

    func sendJSON(_ value: JSONValue) {
        guard let data = try? JSONEncoder().encode(value),
              let text = String(data: data, encoding: .utf8) else {
            Issue.record("Could not encode realtime test JSON")
            return
        }
        continuation.yield(.message(.text(text)))
    }

    func serverClose(code: Int, reason: String? = nil) {
        continuation.yield(.closed(AIDuplexWebSocketCloseMetadata(
            code: code,
            reason: reason
        )))
        continuation.finish()
    }

    func sentMessages() -> [AIDuplexWebSocketMessage] {
        lock.lock()
        defer { lock.unlock() }
        return sent
    }

    func sentJSONMessages() throws -> [JSONValue] {
        try sentMessages().map { message in
            let data: Data
            switch message {
            case let .text(text):
                data = Data(text.utf8)
            case let .binary(binary):
                data = binary
            }
            return try JSONDecoder().decode(JSONValue.self, from: data)
        }
    }

    func closeCalls() -> [(code: Int, reason: Data?)] {
        lock.lock()
        defer { lock.unlock() }
        return closes
    }
}

func realtimeWait(
    _ condition: @escaping @Sendable () -> Bool
) async -> Bool {
    for _ in 0..<10_000 {
        if condition() { return true }
        await Task.yield()
    }
    return condition()
}

func realtimeCollect<T: Sendable>(
    _ stream: AsyncThrowingStream<T, Error>
) async throws -> [T] {
    var values: [T] = []
    for try await value in stream {
        values.append(value)
    }
    return values
}
