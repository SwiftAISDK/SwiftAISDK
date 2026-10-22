import Darwin
import Foundation
import SwiftAISDK

/// Offline transport-level probe. Compile against a chosen SDK revision and run
/// in a fresh process; compare resident-byte deltas, not machine-independent limits.
@main
struct HTTPStreamingMemoryProbe {
    static func main() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MemoryProbeURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let transport = URLSessionTransport(session: session)
        let payloadBytes = MemoryProbeURLProtocol.payload.count
        let before = try residentBytes()
        let response = try await transport.stream(AIHTTPRequest(
            method: "GET", url: URL(string: "https://probe.invalid/body")!,
            maxResponseBytes: payloadBytes
        ))
        // The consumer deliberately leaves the body unread while data arrives.
        try await Task.sleep(nanoseconds: 2_000_000_000)
        let unread = try residentBytes()
        var iterator = response.body.makeAsyncIterator()
        var prefix = Data()
        for _ in 0..<128 {
            guard let chunk = try await iterator.next() else { break }
            prefix.append(chunk)
        }
        guard prefix == Data(repeating: 65, count: 128) else { throw ProbeError.invalidPrefix }
        response.cancelBody()
        let result: [String: UInt64] = [
            "payloadBytes": UInt64(payloadBytes), "consumedBytes": UInt64(prefix.count),
            "residentBefore": before, "residentUnread": unread,
            "residentGrowthUnread": unread > before ? unread - before : 0,
        ]
        print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), as: UTF8.self))
    }

    static func residentBytes() throws -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { throw ProbeError.taskInfo(status) }
        return info.resident_size
    }
}

private enum ProbeError: Error { case invalidPrefix, taskInfo(kern_return_t) }

private final class MemoryProbeURLProtocol: URLProtocol, @unchecked Sendable {
    static let payload = Data(repeating: 65, count: 1_048_576)
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Length": String(Self.payload.count)]
        ) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.payload)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
