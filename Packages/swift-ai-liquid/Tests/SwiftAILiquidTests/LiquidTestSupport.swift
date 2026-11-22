import Foundation
import SwiftAILiquid
import SwiftAIProvider
import SwiftAITransport
import Testing

// Fixtures from @ai-sdk/liquid@3.0.1, release 3dad57f204c7332178d28c3467c7311875b66a3e.
let liquidFixture = loadLiquidFixture("decisions")
let liquidNotFoundFixture = loadLiquidFixture("decisions-box-not-found")
let liquidPNG = Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
let liquidWAV = Data([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45])
let liquidImage = AIDecisionStatePart.file(mediaType: "image/png", data: .data(liquidPNG))
let liquidState: [AIDecisionStatePart] = [.text("Help! My payouts have been failing for 3 days.")]
let liquidUrgency: AIDecisionQuestion = .boolean(instructions: "Does this convey urgency?")
let liquidQuestions: [String: AIDecisionQuestion] = [
    "department": .choice(instructions: "Which team should handle this?", criteria: [
        "billing": "Payments, invoicing, refunds", "technical": "Bugs, outages, integrations", "sales": "Pricing, upgrades, new accounts"
    ]),
    "is_urgent": liquidUrgency,
    "frustration": .score(instructions: "How frustrated is the customer?", criteria: ["Calm", "Frustrated", "Very angry"])
]
let liquidBoxQuestions: [String: AIDecisionQuestion] = ["subject": .box(instructions: "The animal in the picture.")]
let liquidBoxState: [AIDecisionStatePart] = [.text("A support screenshot."), liquidImage]
let liquidTextAnswers = liquidFixture["answers"]!.objectValue!.filter { liquidQuestions.keys.contains($0.key) }
let liquidTextResponse = JSONValue.object(liquidFixture.objectValue!.merging(["answers": .object(liquidTextAnswers)]) { _, new in new })

private func loadLiquidFixture(_ name: String) -> JSONValue {
    let url = Bundle.module.url(forResource: name, withExtension: "json")!
    return try! JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: url))
}

actor LiquidTestTransport: AITransport {
    let response: AIHTTPResponse
    private(set) var requests: [AIHTTPRequest] = []

    init(_ body: JSONValue = liquidTextResponse, status: Int = 200) throws {
        response = .init(statusCode: status, headers: ["content-type": "application/json", "x-trace": "trace-1"],
                         body: try encodeJSONBody(body))
    }

    func send(_ request: AIHTTPRequest) async throws -> AIHTTPResponse {
        requests.append(request)
        return response
    }

    func request() throws -> AIHTTPRequest {
        #expect(requests.count == 1)
        return try #require(requests.first)
    }

    func requestBody() throws -> JSONValue {
        let request = try request()
        return try decodeJSONBody(#require(request.body))
    }
}

func liquidSetup(_ body: JSONValue = liquidTextResponse, status: Int = 200) throws
    -> (model: any AIDecisionModelV4, transport: LiquidTestTransport) {
    let transport = try LiquidTestTransport(body, status: status)
    let provider = createLiquid(configuration: .init(apiKey: "test-key", baseURL: "https://example.com/",
        headers: ["x-provider": "custom", "shared": "provider"], environment: [:], transport: transport))
    return (provider.decisionModel("d1.2"), transport)
}
