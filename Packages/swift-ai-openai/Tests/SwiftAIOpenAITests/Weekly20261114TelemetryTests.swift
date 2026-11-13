import Foundation
import Testing
import SwiftAI
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIOpenAI

private actor WeeklyOpenAITelemetry: Telemetry.Integration {
    private var values: [Telemetry.Event] = []
    func record(_ event: Telemetry.Event) { values.append(event) }
    func events() -> [Telemetry.Event] { values }
}

@Suite struct Weekly20261114TelemetryTests {
    @Test func providerSecretRedactionAppliesToTelemetryWhileRawBodiesRemainAvailable() async throws {
        let wireTools: JSONValue = [["type": "mcp", "server_label": "remote", "authorization": "tool-secret", "headers": ["X-Key": "tool-secret"]]]
        let raw: JSONValue = ["id": "resp", "status": "completed", "output": [["type": "message", "id": "msg", "content": [["type": "output_text", "text": "ok"]]]], "tools": wireTools]
        let transport = RecordingTransport(response: .init(statusCode: 200, body: try encodeJSONBody(raw)))
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
        let recorder = WeeklyOpenAITelemetry()
        let result = try await AI.generateText(model: provider.responses("gpt-6-sol"), request: .init(messages: [.user("Hi")], tools: ["remote": OpenAITools.mcp(serverLabel: "remote", authorization: "tool-secret", headers: ["X-Key": "tool-secret"], serverURL: "https://example.com")]), retryPolicy: .none, telemetry: .init(integrations: [recorder]), includeResponseBody: true)
        #expect(result.rawValue["tools"] == wireTools)
        #expect(result.responseMetadata.body?["tools"] == wireTools)
        #expect(String(decoding: try encodeJSONBody(try decodeJSONBody(#require(await transport.requests().first?.body))), as: UTF8.self).contains("tool-secret"))
        let events = await recorder.events()
        #expect(!events.isEmpty)
        for event in events {
            for value in [event.input, event.output, event.responseMetadata.body].compactMap({ $0 }) {
                #expect(!String(decoding: try encodeJSONBody(value), as: UTF8.self).contains("tool-secret"))
            }
        }
        #expect(events.contains { event in
            guard let value = event.input ?? event.output else { return false }
            return (try? String(decoding: encodeJSONBody(value), as: UTF8.self).contains("[redacted]")) == true
        })
    }
}
