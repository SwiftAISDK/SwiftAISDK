import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIParallel

actor ParallelRecordingTransport: AITransport {
    private var recorded: [AIHTTPRequest] = []
    let response: AIHTTPResponse
    init(body: JSONValue = parallelFixture, status: Int = 200) throws {
        response = AIHTTPResponse(statusCode: status, headers: ["retry-after": "2", "x-request-id": "request-123"],
                                  body: try JSONEncoder().encode(body))
    }
    init(response: AIHTTPResponse) { self.response = response }
    func send(_ request: AIHTTPRequest) async throws -> AIHTTPResponse {
        recorded.append(request)
        return response
    }
    func requests() -> [AIHTTPRequest] { recorded }
}

let parallelFixture: JSONValue = {
    let url = Bundle.module.url(forResource: "decisions", withExtension: "json", subdirectory: "Fixtures")
        ?? Bundle.module.url(forResource: "decisions", withExtension: "json")!
    return try! JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: url))
}()

let parallelQuestions: [String: AIDecisionQuestion] = [
    "hasSearch": .boolean(instructions: "Does it offer web search?"),
    "availability": .choice(instructions: "Is the API available?", criteria: [
        "available": "Publicly available", "unknown": "Insufficient evidence"
    ]),
    "fit": .score(instructions: "How well does it fit?", criteria: ["No fit", "Partial fit", "Full fit"])
]

func parallelOptions() -> AIDecisionModelV4CallOptions {
    .init(state: [.json(["company": "Parallel", "website": "https://parallel.ai"])], questions: parallelQuestions)
}

func parallelSetup(body: JSONValue = parallelFixture, status: Int = 200) throws
    -> (transport: ParallelRecordingTransport, model: any AIDecisionModelV4, provider: ParallelProvider) {
    let transport = try ParallelRecordingTransport(body: body, status: status)
    let provider = createParallel(configuration: .init(apiKey: "test-key", baseURL: "https://example.com/v1/",
        headers: ["x-provider": "custom"], environment: [:], transport: transport))
    return (transport, try provider.decisionModel("fast"), provider)
}

func replacingParallelFixture(_ key: String, with value: JSONValue) -> JSONValue {
    var object = parallelFixture.objectValue!
    object[key] = value
    return .object(object)
}

func replacingParallelAnswer(_ key: String, with value: JSONValue) -> JSONValue {
    var answers = parallelFixture["answers"]!.objectValue!
    answers[key] = value
    return replacingParallelFixture("answers", with: .object(answers))
}

func parallelRequestBody(_ request: AIHTTPRequest) throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: request.body!)
}
