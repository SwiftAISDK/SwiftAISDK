// Translated from @ai-sdk/scaledown@3.0.3 scaledown-extraction-model.test.ts.
import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
@testable import SwiftAIScaleDown

@Suite("ScaleDown matching-release extraction tests", .serialized)
struct ScaleDownExtractionUpstreamTests {
    @Test func textListsNullValuesConfidenceSourcesAndUsage() async throws {
        let fixture = try scaleDownExtractionResponse()
        let transport = try ScaleDownRecordingTransport(fixture)
        let model = try createScaleDown(configuration: .init(apiKey: "test-key", transport: transport)).extractionModel("extract-1")
        var options = scaleDownExtractionOptions(); options.providerOptions = ["scaledown": ["threshold": 0.5]]
        let result = try await model.doExtract(options)
        let (_, body) = try await scaleDownRequest(transport)
        #expect(body == ["model": "extract-1", "messages": [["role": "user", "content": "Acme Corp. Contacts: Ana, Bo."]],
            "response_format": ["type": "json_schema", "json_schema": ["name": "extraction", "schema": ["type": "object", "properties": [
                "vendor": ["type": "string", "description": "Company name", "top_n": 1],
                "contacts": ["type": "string", "description": "{\"find\":\"Contact names\"}", "top_n": 0],
                "missing": ["type": "string", "top_n": 1], "empty": ["type": "string", "top_n": 0]
            ]]]], "threshold": 0.5, "context_chars": 0])
        #expect(result.answers == [
            "vendor": .init(type: .text, value: "Acme Corp", confidence: 0.97, source: .text(part: 0, start: 0, end: 9)),
            "contacts": .init(type: .list, value: ["Ana", "Bo"], items: [
                .init(confidence: 0.9, source: .text(part: 0, start: 21, end: 24)),
                .init(confidence: 0.85, source: .text(part: 0, start: 26, end: 28))]),
            "missing": .init(type: .text), "empty": .init(type: .list, value: [], items: [])
        ])
        #expect(result.answers["empty"]?.items == [])
        #expect(result.usage == .init(inputTokens: 42, outputTokens: 12))
        #expect(result.response?.id == "extract-123")
        #expect(result.response?.timestamp == Date(timeIntervalSince1970: 1700000000))
        #expect(result.response?.modelID == "extract-1")
        #expect(result.response?.body == fixture)
        #expect(result.warnings.isEmpty)
    }

    @Test func fieldIDsPreserveSpacesCamelCaseUnicodeAndDistinctCasing() async throws {
        let entities: JSONValue = ["entities": [
            ["type": "invoice number", "text": "INV-2041", "confidence": 0.9],
            ["type": "dueDate", "text": "2026-12-01", "confidence": 0.9],
            ["type": "客户名称", "text": "Zoë Martin", "confidence": 0.9],
            ["type": "Vendor", "text": "Acme Corp", "confidence": 0.9]
        ]]
        let transport = try ScaleDownRecordingTransport(scaleDownExtractionResponse(content: entities))
        let model = try createScaleDown(configuration: .init(apiKey: "test-key", transport: transport)).extractionModel("extract-1")
        let result = try await model.doExtract(.init(state: [.text("Invoice INV-2041 issued by Acme Corp to Zoë Martin. Payment is due on 2026-12-01.")], fields: [
            "invoice number": .init(type: .text, instructions: "Invoice identifier"),
            "dueDate": .init(type: .text, instructions: "Exact payment due date"),
            "客户名称": .init(type: .text, instructions: "Name of the person receiving the invoice"),
            "Vendor": .init(type: .text, instructions: "Name of the company issuing the invoice"),
            "vendor": .init(type: .text, instructions: "Name of the company receiving the invoice")
        ]))
        let (_, body) = try await scaleDownRequest(transport)
        #expect(Set(body["response_format"]?["json_schema"]?["schema"]?["properties"]?.objectValue?.keys.map { $0 } ?? []) == Set(["invoice number", "dueDate", "客户名称", "Vendor", "vendor"]))
        #expect(result.answers == [
            "invoice number": .init(type: .text, value: "INV-2041", confidence: 0.9),
            "dueDate": .init(type: .text, value: "2026-12-01", confidence: 0.9),
            "客户名称": .init(type: .text, value: "Zoë Martin", confidence: 0.9),
            "Vendor": .init(type: .text, value: "Acme Corp", confidence: 0.9), "vendor": .init(type: .text)
        ])
    }

    @Test func convertsUTF8OffsetsAcrossJSONAndUnicodeWithoutInventingSources() async throws {
        let content: JSONValue = ["entities": [
            ["type": "names", "text": "Acmé", "confidence": 0.9, "start": 19, "end": 24],
            ["type": "names", "text": "Zoë", "confidence": 0.8, "start": 29, "end": 33],
            ["type": "note", "text": "é", "confidence": 0.9, "start": 9, "end": 11],
            ["type": "invalid", "text": "Acmé", "confidence": 0.9, "start": 20, "end": 25]
        ]]
        let transport = try ScaleDownRecordingTransport(scaleDownExtractionResponse(content: content))
        let model = try createScaleDown(configuration: .init(apiKey: "test-key", transport: transport)).extractionModel("extract-1")
        let result = try await model.doExtract(.init(state: [.json(["note": "é"]), .text("🙂 Acmé and Zoë.")], fields: [
            "names": .init(type: .list, items: .text), "note": .init(type: .text), "invalid": .init(type: .text)
        ]))
        let (_, body) = try await scaleDownRequest(transport)
        #expect(body["messages"] == [["role": "user", "content": "{\"note\":\"é\"}\n🙂 Acmé and Zoë."]])
        #expect(result.answers["names"]?.items == [.init(confidence: 0.9, source: .text(part: 1, start: 3, end: 7)),
                                                 .init(confidence: 0.8, source: .text(part: 1, start: 12, end: 15))])
        #expect(result.answers["note"] == .init(type: .text, value: "é", confidence: 0.9))
        #expect(result.answers["invalid"] == .init(type: .text, value: "Acmé", confidence: 0.9))
    }

    @Test func base64DocumentFileSourcesOCRAndFallbackUsage() async throws {
        var content = try #require(scaleDownExtractionContent().objectValue)
        content["ocr_text"] = "Acme Corp. Contacts: Ana, Bo."
        var fixture = try #require(scaleDownExtractionResponse(content: .object(content)).objectValue); fixture["usage"] = .null
        let transport = try ScaleDownRecordingTransport(.object(fixture))
        let model = try createScaleDown(configuration: .init(apiKey: "test-key", transport: transport)).extractionModel("extract-1")
        var options = scaleDownExtractionOptions()
        options.state = [.file(mediaType: "application/pdf", data: .data(Data([1, 2, 3])))]
        let result = try await model.doExtract(options)
        let (_, body) = try await scaleDownRequest(transport)
        #expect(body["messages"] == [["role": "user", "content": "Extract the requested fields from the document."]])
        #expect(body["document"] == "AQID")
        #expect(body["document_mime_type"] == "application/pdf")
        #expect(result.answers["vendor"]?.source == .file(part: 0))
        #expect(result.providerMetadata == ["scaledown": ["ocrText": "Acme Corp. Contacts: Ana, Bo."]])
        #expect(result.usage == .init(inputTokens: 42, outputTokens: nil))
    }

    @Test func rejectsUnsupportedFieldsAndFilesBeforeIO() async throws {
        let transport = try ScaleDownRecordingTransport(scaleDownExtractionResponse())
        let model = try createScaleDown(configuration: .init(apiKey: "test-key", transport: transport)).extractionModel("extract-1")
        for field: AIExtractionField in [.init(type: .number), .init(type: .date), .init(type: .list, items: .number), .init(type: .list, items: .date)] {
            var options = scaleDownExtractionOptions(); options.fields = ["value": field]
            await #expect(throws: AIExtractionUnsupportedFieldTypeError.self) { _ = try await model.doExtract(options) }
        }
        var options = scaleDownExtractionOptions(); options.state = [.file(mediaType: "audio/wav", data: .base64("AQID"))]
        await #expect(throws: AIDecisionUnsupportedFunctionalityError.self) { _ = try await model.doExtract(options) }
        #expect(await transport.requests.isEmpty)
    }

    @Test func customConfigurationHeadersAbortAndUnsupportedSettings() async throws {
        let transport = try ScaleDownRecordingTransport(scaleDownExtractionResponse())
        let controller = AIAbortController()
        let model = try createScaleDown(configuration: .init(apiKeyProvider: { "custom-key" }, baseURL: "https://custom.example/",
            headers: ["shared": "provider"], transport: transport)).extractionModel("extract")
        var options = scaleDownExtractionOptions(); options.headers = ["shared": "call"]; options.abortSignal = controller.signal
        options.referenceDate = "2026-11-12"; options.reasoning = "high"; options.maxOutputTokens = 10
        let result = try await model.doExtract(options)
        let (request, _) = try await scaleDownRequest(transport)
        #expect(request.url.absoluteString == "https://custom.example/v1/chat/completions")
        #expect(request.headers["x-api-key"] == "custom-key")
        #expect(request.headers["shared"] == "call")
        #expect(request.abortSignal === controller.signal)
        #expect(result.warnings == [.init(type: "unsupported", feature: "referenceDate"), .init(type: "unsupported", feature: "maxOutputTokens"), .init(type: "unsupported", feature: "reasoning")])
    }

    @Test func environmentAuthenticationAndSupportedFieldTypes() async throws {
        let transport = try ScaleDownRecordingTransport(scaleDownExtractionResponse())
        let model = try createScaleDown(configuration: .init(environment: ["SCALEDOWN_API_KEY": "env-key"], transport: transport)).extractionModel("extract-1")
        _ = try await model.doExtract(scaleDownExtractionOptions())
        let (request, _) = try await scaleDownRequest(transport)
        #expect(request.headers["x-api-key"] == "env-key")
        #expect(model.supportedFieldTypes == [.text, .list])
        #expect(model.providerID == "scaledown.extraction")
    }

    @Test func malformedInnerJSONRetainsDataAndAPIErrorsSurface() async throws {
        for content in ["not JSON", "{\"entities\":\"invalid\"}"] {
            var fixture = try #require(scaleDownExtractionResponse().objectValue)
            fixture["choices"] = [["message": ["content": .string(content)]]]
            let transport = try ScaleDownRecordingTransport(.object(fixture))
            let model = try createScaleDown(configuration: .init(apiKey: "test-key", transport: transport)).extractionModel("extract-1")
            await #expect(throws: ScaleDownInvalidExtractionContentError(data: content)) { _ = try await model.doExtract(scaleDownExtractionOptions()) }
        }
        let transport = try ScaleDownRecordingTransport(["detail": "Insufficient credits"], status: 402)
        let model = try createScaleDown(configuration: .init(apiKey: "test-key", transport: transport)).extractionModel("extract-1")
        try await expectScaleDownAPIError(status: 402, message: "Insufficient credits") { _ = try await model.doExtract(scaleDownExtractionOptions()) }
    }
}
