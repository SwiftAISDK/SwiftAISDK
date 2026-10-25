import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
@testable import SwiftAITypeSafeAI
import Foundation
import Testing

@Suite("WeeklyPerplexity20261023")
struct WeeklyPerplexity20261023Tests {


    @Test func typesafeWarnsForUnsupportedSharedDecisionControls() async throws {
        let model = try TypeSafeAIProvider(configuration: .init(apiKey: "key", transport: RecordingTransport(response: jsonResponse(#"{"answers":{"q":{"type":"noul","noul":1}},"usage":{}}"#)))).decisionModel("jev-latest")
        let result = try await model.doDecide(.init(state: [], questions: ["q": .boolean(instructions: "x")], maxOutputTokens: 10, reasoning: "none"))
        #expect(result.warnings.map(\.feature) == ["maxOutputTokens", "reasoning"])
    }
}
