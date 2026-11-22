import Foundation
import SwiftAIProvider
import SwiftAITransport
import Testing
@testable import SwiftAIAssemblyAI

// Translated from assemblyai-error.test.ts at @ai-sdk/assemblyai 3.0.85.
@Suite("AssemblyAI error schema and failed responses (upstream)")
struct AssemblyAIErrorParityTests {
    private static let resourceMessage = "{\n  \"error\": {\n    \"code\": 429,\n    \"message\": \"Resource has been exhausted (e.g. check quota).\",\n    \"status\": \"RESOURCE_EXHAUSTED\"\n  }\n}\n"
    private static let resourceError = #"{"error":{"message":"{\n  \"error\": {\n    \"code\": 429,\n    \"message\": \"Resource has been exhausted (e.g. check quota).\",\n    \"status\": \"RESOURCE_EXHAUSTED\"\n  }\n}\n","code":429}}"#

    @Test func parsesResourceExhaustedError() throws {
        let raw = try decodeJSONBody(Data(Self.resourceError.utf8))
        let expected: JSONValue = ["error": ["message": .string(Self.resourceMessage), "code": 429]]
        #expect(raw == expected)
        #expect(assemblyAIErrorData(from: raw) == expected)
    }

    @Test(arguments: [
        ("Invalid API key", nil as String?),
        ("format_text must be a Boolean", "error"),
        ("Invalid API key", "unexpected")
    ])
    func parsesDocumentedFlatErrorShape(message: String, status: String?) throws {
        var raw: [String: JSONValue] = ["error": .string(message)]
        raw["status"] = status.map(JSONValue.string)
        let decoded = try decodeJSONBody(encodeJSONBody(.object(raw)))
        #expect(decoded == .object(raw))
        #expect(assemblyAIErrorData(from: decoded) == ["error": .string(message)])
    }

    @Test(arguments: [
        (#"{"error":"Invalid API key"}"#, 401, "Invalid API key"),
        (#"{"error":"format_text must be a Boolean","status":"error"}"#, 400, "format_text must be a Boolean")
    ])
    func usesFlatErrorMessage(body: String, statusCode: Int, message: String) throws {
        let error = try failedResponse(body, statusCode: statusCode)
        #expect(error.message == message)
        #expect(error.statusCode == statusCode)
        #expect(error.responseBody == body)
        let decoded = try decodeJSONBody(Data(error.responseBody.utf8))
        #expect(assemblyAIErrorData(from: decoded) == ["error": .string(message)])
    }

    @Test func usesNestedErrorMessage() throws {
        let error = try failedResponse(Self.resourceError, statusCode: 429)
        #expect(error.message == Self.resourceMessage)
        #expect(error.statusCode == 429)
        #expect(error.responseBody == Self.resourceError)
        #expect(error.isRetryable)
        let decoded = try decodeJSONBody(Data(error.responseBody.utf8))
        #expect(assemblyAIErrorData(from: decoded) == ["error": ["message": .string(Self.resourceMessage), "code": 429]])
    }

    @Test(arguments: [
        (#"{"foo":"bar"}"#, 500, "Internal Server Error"),
        ("not json", 502, "Bad Gateway")
    ])
    func fallsBackToHTTPStatusAndKeepsBody(body: String, statusCode: Int, statusText: String) throws {
        let error = try failedResponse(body, statusCode: statusCode)
        #expect(error.message == statusText)
        #expect(error.statusCode == statusCode)
        #expect(error.responseBody == body)
    }

    private func failedResponse(_ body: String, statusCode: Int) throws -> AIAPICallError {
        let url = try requireURL("https://tts.us.assemblyai.com/v1/speech")
        let response = AIHTTPResponse(statusCode: statusCode, body: Data(body.utf8))
        return try #require(assemblyAISpeechHTTPError(response: response, request: AIHTTPRequest(url: url), requestBody: .object([:])).apiCallError)
    }
}
