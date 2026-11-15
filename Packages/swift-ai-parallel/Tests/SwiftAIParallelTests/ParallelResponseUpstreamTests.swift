import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
import SwiftAIParallel

// Matching-release illustrative fixture, precision and error scenarios preserved.
@Suite("Parallel matching-release responses")
struct ParallelResponseUpstreamTests {
    @Test func preservesFullPrecisionCitationsConfidenceLegendsAndUsage() async throws {
        let (_, model, _) = try parallelSetup()
        let result = try await model.doDecide(parallelOptions())
        #expect(result.answers == [
            "hasSearch": .boolean(probability: 0.9992643798509062),
            "availability": .choice(choice: "available", probabilities: ["available": 0.987654321, "unknown": 0.012345679]),
            "fit": .score(score: 1.7123456789, probabilities: ["0": 0.1, "1": 0.0876543211, "2": 0.8123456789])
        ])
        #expect(result.providerMetadata == ["parallel": .object([
            "citations": parallelFixture["citations"],
            "confidence": ["availability": 0.87654321, "fit": 0.7654321],
            "legend": ["fit": parallelFixture["answers"]!["fit"]!["legend"]!],
            "decisionId": parallelFixture["decision_id"], "mode": "fast"
        ])])
        #expect(result.rounding == nil)
        #expect(result.usage == .init(inputTokens: 4212, outputTokens: 0))
        #expect(result.response?.id == parallelFixture["decision_id"]?.stringValue)
        #expect(result.response?.modelID == "fast")
        #expect(result.response?.body == parallelFixture)
    }

    @Test func preservesRefusalAlongsideSuccessfulAnswers() async throws {
        let fixture = replacingParallelAnswer("hasSearch", with: ["type": "refusal"])
        let (_, model, _) = try parallelSetup(body: fixture)
        let result = try await model.doDecide(parallelOptions())
        #expect(result.answers["hasSearch"] == .refusal)
        #expect(result.answers["fit"] == .score(score: 1.7123456789, probabilities: ["0": 0.1, "1": 0.0876543211, "2": 0.8123456789]))
    }

    @Test(arguments: [JSONValue.array([JSONValue]()), .array([["url": "https://example.com", "excerpts": []]])])
    func preservesEmptyEvidenceFields(_ citations: JSONValue) async throws {
        let (_, model, _) = try parallelSetup(body: replacingParallelFixture("citations", with: citations))
        let result = try await model.doDecide(parallelOptions())
        #expect(result.providerMetadata["parallel"]?["citations"] == citations)
    }

    static let malformedResponses: [JSONValue] = [
        replacingParallelAnswer("hasSearch", with: ["type": "noul", "noul": 2]),
        replacingParallelFixture("answers", with: ["hasSearch": parallelFixture["answers"]!["hasSearch"]!]),
        replacingParallelAnswer("unexpected", with: parallelFixture["answers"]!["hasSearch"]!),
        replacingParallelFixture("citations", with: [["url": "https://example.com", "excerpts": "not-an-array"]])
    ]

    @Test(arguments: malformedResponses)
    func rejectsMalformedProviderResponses(_ response: JSONValue) async throws {
        let (_, model, _) = try parallelSetup(body: response)
        do { _ = try await model.doDecide(parallelOptions()); Issue.record("Expected invalid response") }
        catch let error as AIError {
            switch error { case .invalidResponse, .apiCall: break; default: Issue.record("Unexpected error \(error)") }
        }
    }

    @Test(arguments: [400, 401, 422, 429, 500])
    func preservesProviderErrorsAndRetryHeaders(_ status: Int) async throws {
        let body: JSONValue = ["type": "error", "error": ["message": "Request rejected", "ref_id": "error-123"]]
        let (_, model, _) = try parallelSetup(body: body, status: status)
        do { _ = try await model.doDecide(parallelOptions()); Issue.record("Expected API call error") }
        catch let AIError.apiCall(error) {
            #expect(error.message == "Request rejected")
            #expect(error.statusCode == status)
            #expect(error.responseHeaders["retry-after"] == "2")
            #expect(try JSONDecoder().decode(JSONValue.self, from: Data(error.responseBody.utf8)) == body)
            #expect(error.isRetryable == (status == 429 || status == 500))
        }
    }

    @Test func forwardsFutureModeStringsWithoutPackageUpdate() async throws {
        let transport = try ParallelRecordingTransport(body: replacingParallelFixture("mode", with: "future-mode"))
        let model = try createParallel(configuration: .init(apiKey: "test-key", transport: transport)).decisionModel("future-mode")
        let result = try await model.doDecide(parallelOptions())
        let request = try #require(await transport.requests().first)
        #expect(try parallelRequestBody(request)["mode"] == "future-mode")
        #expect(result.providerMetadata["parallel"]?["mode"] == "future-mode")
        #expect(result.response?.modelID == "future-mode")
    }
}
