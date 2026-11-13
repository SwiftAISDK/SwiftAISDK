import Foundation
import Testing
import SwiftAIProvider
@testable import SwiftAIZAI

@Suite struct Weekly20261114WarningTests {
    @Test(arguments: [false, true])
    func unsupportedTopKIsReportedOnceAcrossTheCompatibleAdapter(_ streaming: Bool) async throws {
        let raw = #"{"choices":[{"message":{"content":"answer"},"delta":{"content":"answer"},"finish_reason":"stop"}]}"#
        let transport = RecordingTransport(response: streaming ? sseResponse("data: " + raw) : jsonResponse(raw))
        let model = try createZai(configuration: .init(apiKey: "fixture", transport: transport)).languageModel("glm-5.3")
        let request = LanguageModelRequest(messages: [.user("hi")], topK: 5)
        var warnings: [AIWarning] = []
        if streaming {
            for try await part in model.stream(request) {
                if case let .streamStart(value) = part { warnings += value }
            }
        } else { warnings = try await model.generate(request).warnings }
        #expect(warnings.filter { $0.feature == "topK" }.count == 1)
        #expect(warnings.first?.type == "unsupported")
    }
}
