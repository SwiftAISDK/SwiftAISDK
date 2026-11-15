import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Testing
@testable import SwiftAIScaleDown

actor ScaleDownRecordingTransport: AITransport {
    var requests: [AIHTTPRequest] = []
    let response: AIHTTPResponse
    init(_ response: JSONValue, status: Int = 200) throws {
        self.response = AIHTTPResponse(statusCode: status, headers: ["content-type": "application/json", "x-request-id": "request-1"],
                                       body: try encodeJSONBody(response))
    }
    func send(_ request: AIHTTPRequest) async throws -> AIHTTPResponse { requests.append(request); return response }
}

func scaleDownDecisionOptions() -> AIDecisionModelV4CallOptions {
    .init(state: [.text("The export crashes in Safari.")], questions: [
        "category": .choice(criteria: ["bug": "Broken functionality", "feedback": .null]),
        "workaround": .boolean(instructions: "Is there a workaround?"),
        "severity": .score(criteria: ["Cosmetic", "Degraded", "Blocking"])
    ])
}

func scaleDownDecisionResponse() -> JSONValue {
    ["model": "classify-1", "answers": [
        "category": ["type": "choice", "choice": "bug", "probabilities": ["bug": 0.93, "feedback": 0.07], "confidence": 0.93],
        "workaround": ["type": "noul", "noul": 0.79],
        "severity": ["type": "score", "score": 1.43, "probabilities": ["0": 0, "1": 0.57, "2": 0.43], "confidence": 0.57,
                     "legend": ["0": "Cosmetic", "1": "Degraded", "2": "Blocking"]]
    ], "usage": ["input_tokens": 103, "output_tokens": 3, "cost": 0.0000044]]
}

func scaleDownExtractionOptions() -> AIExtractionModelV4CallOptions {
    .init(state: [.text("Acme Corp. Contacts: Ana, Bo.")], fields: [
        "vendor": .init(type: .text, instructions: "Company name"),
        "contacts": .init(type: .list, instructions: ["find": "Contact names"], items: .text),
        "missing": .init(type: .text), "empty": .init(type: .list, items: .text)
    ])
}
func scaleDownExtractionContent() -> JSONValue {
    let empty: [JSONValue] = ["vendor", "contacts", "missing", "empty"].map { ["text": "", "type": .string($0), "confidence": 1] }
    return ["entities": .array(empty + [
        ["text": "Acme Corp", "type": "vendor", "confidence": 0.97, "start": 0, "end": 9],
        ["text": "Ana", "type": "contacts", "confidence": 0.9, "start": 21, "end": 24],
        ["text": "Bo", "type": "contacts", "confidence": 0.85, "start": 26, "end": 28]
    ]), "structured_result": .null, "input_tokens": 42, "ocr_text": .null]
}
func scaleDownExtractionResponse(content: JSONValue? = nil) throws -> JSONValue {
    ["id": "extract-123", "created": 1700000000, "model": "extract-1",
     "choices": [["message": ["content": .string(try decisionJSONText(content ?? scaleDownExtractionContent()))]]],
     "usage": ["prompt_tokens": 42, "completion_tokens": 12, "total_tokens": 54]]
}

func scaleDownRequest(_ transport: ScaleDownRecordingTransport) async throws -> (AIHTTPRequest, JSONValue) {
    let request = try #require(await transport.requests.first)
    return (request, try decodeJSONBody(#require(request.body)))
}

func expectScaleDownAPIError(status: Int, message: String, operation: () async throws -> Void) async throws {
    do { try await operation(); Issue.record("Expected API call error") }
    catch let AIError.apiCall(error) {
        #expect(error.statusCode == status)
        #expect(error.message == message)
        #expect(error.responseHeaders["x-request-id"] == "request-1")
        #expect(!error.responseBody.isEmpty)
    }
}
