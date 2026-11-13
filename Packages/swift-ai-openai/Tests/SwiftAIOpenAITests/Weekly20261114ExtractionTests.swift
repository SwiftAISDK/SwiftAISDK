import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIOpenAI

@Suite struct Weekly20261114ExtractionTests {
    @Test func responsesExtractionUsesNativeSchemaAndNullableTypedAnswers() async throws {
        let answer: JSONValue = ["f0": ["Ana", "Bo"], "f1": "2027-03-03", "f2": "INV-2041", "f3": .null, "f4": 1250]
        let text = String(decoding: try encodeJSONBody(answer), as: UTF8.self)
        let raw: JSONValue = ["id": "resp", "status": "completed", "output": [["type": "message", "id": "msg", "role": "assistant", "content": [["type": "output_text", "text": .string(text)]]]], "usage": ["input_tokens": 10, "output_tokens": 20]]
        let transport = RecordingTransport(response: .init(statusCode: 200, body: try encodeJSONBody(raw)))
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", transport: transport))
        let model = try provider.extractionModel("gpt-6.1-sol")
        let result = try await model.doExtract(.init(state: [.text("Invoice INV-2041. Total $1,250. Contacts Ana, Bo.")], fields: ["invoiceNumber": .init(type: .text), "total": .init(type: .number, decimals: 2), "dueDate": .init(type: .date), "contacts": .init(type: .list, items: .text), "purchaseOrder": .init(type: .text)], referenceDate: "2026-11-11"))
        #expect(model.providerID == "openai.extraction")
        #expect(provider.supportedCapabilities.contains(.extraction))
        #expect(result.answers["contacts"]?.value == ["Ana", "Bo"])
        #expect(result.answers["dueDate"]?.value == "2027-03-03")
        #expect(result.answers["invoiceNumber"]?.value == "INV-2041")
        #expect(result.answers["purchaseOrder"]?.value == nil)
        #expect(result.answers["total"]?.value == 1250)
        let body = try decodeJSONBody(#require(await transport.requests().first?.body))
        #expect(body["text"]?["format"]?["type"] == "json_schema")
        #expect(body["text"]?["format"]?["name"] == "extraction")
        #expect(body["text"]?["format"]?["strict"] == true)
        #expect(body["text"]?["format"]?["schema"]?["required"] == ["f0", "f1", "f2", "f3", "f4"])
    }
}
