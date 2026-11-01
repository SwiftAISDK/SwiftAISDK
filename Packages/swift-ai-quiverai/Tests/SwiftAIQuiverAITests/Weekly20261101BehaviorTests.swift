import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIQuiverAI

@Suite struct Weekly20261101QuiverBehaviorTests {
    @Test(arguments: [("none", "low"), ("minimal", "low"), ("max", "xhigh")], [false, true])
    func portableReasoningMapsToClosestSupportedEffort(_ fixture: (String, String), _ streaming: Bool) async throws {
        let raw = #"{"id":"r","status":"completed","output_text":"done"}"#
        let transport = RecordingTransport(response: streaming ? sseResponse("data: {\"type\":\"response.completed\",\"response\":" + raw + "}") : jsonResponse(raw))
        let model = try QuiverAIProvider(configuration: .init(apiKey: "key", transport: transport)).languageModel("arrow-2")
        let request = LanguageModelRequest(messages: [.user("Hi")], reasoning: fixture.0)
        var warnings: [AIWarning] = []
        if streaming { for try await part in model.stream(request) { if case let .streamStart(value) = part { warnings = value } } }
        else { warnings = try await model.generate(request).warnings }
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["reasoning"]?["effort"] == .string(fixture.1))
        #expect(warnings.contains { $0.type == "compatibility" && $0.feature == "reasoning" })
    }
}
