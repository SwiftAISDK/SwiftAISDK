import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
@testable import SwiftAIScaleDown

@Suite("ScaleDown native transport and validation", .serialized)
struct ScaleDownNativeTests {
    @Test func abortedCallsNeverResolveCredentialsOrSend() async throws {
        let transport = try ScaleDownRecordingTransport(scaleDownDecisionResponse())
        let controller = AIAbortController(); controller.abort(reason: "stop")
        let provider = createScaleDown(configuration: .init(apiKeyProvider: { Issue.record("Aborted calls must not resolve credentials"); return "unused" }, transport: transport))
        var decision = scaleDownDecisionOptions(); decision.abortSignal = controller.signal
        var extraction = scaleDownExtractionOptions(); extraction.abortSignal = controller.signal
        await #expect(throws: (any Error).self) { _ = try await provider.decisionModel("classify").doDecide(decision) }
        await #expect(throws: (any Error).self) { _ = try await provider.extractionModel("extract").doExtract(extraction) }
        #expect(await transport.requests.isEmpty)
    }

    @Test func invalidThresholdsAndDocumentCombinationsNeverSend() async throws {
        let transport = try ScaleDownRecordingTransport(scaleDownExtractionResponse())
        let provider = createScaleDown(configuration: .init(apiKey: "test-key", transport: transport))
        let model = try provider.extractionModel("extract")
        for threshold: JSONValue in [-0.1, 1.1, .null, "0.5"] {
            var options = scaleDownExtractionOptions(); options.providerOptions = ["scaledown": ["threshold": threshold]]
            await #expect(throws: AIError.self) { _ = try await model.doExtract(options) }
        }
        let pdf = AIDecisionStatePart.file(mediaType: "application/pdf", data: .base64("AQID"))
        for state: [AIDecisionStatePart] in [[pdf, pdf], [.file(mediaType: "image/png", data: .reference("native-file"))], [.file(mediaType: "image/jpeg", data: .url(URL(string: "https://example.com/a.jpeg")!))]] {
            var options = scaleDownDecisionOptions(); options.state = state
            await #expect(throws: AIDecisionUnsupportedFunctionalityError.self) { _ = try await provider.decisionModel("classify").doDecide(options) }
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test func missingKeyStaysLazyAndIsolatedEnvironmentDoesNotFallBack() async throws {
        let transport = try ScaleDownRecordingTransport(scaleDownDecisionResponse())
        let model = try createScaleDown(configuration: .init(environment: [:], transport: transport)).decisionModel("classify")
        await #expect(throws: AIError.missingAPIKey(provider: "scaledown", environmentVariables: ["SCALEDOWN_API_KEY"])) {
            _ = try await model.doDecide(scaleDownDecisionOptions())
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test func selectsHighestConfidenceAndRetainsFirstOnTies() async throws {
        let content: JSONValue = ["entities": [
            ["type": "vendor", "text": "lower", "confidence": 0.3],
            ["type": "vendor", "text": "best", "confidence": 0.9],
            ["type": "vendor", "text": "tie", "confidence": 0.9]
        ]]
        let transport = try ScaleDownRecordingTransport(scaleDownExtractionResponse(content: content))
        let model = try createScaleDown(configuration: .init(apiKey: "test-key", transport: transport)).extractionModel("extract")
        let result = try await model.doExtract(scaleDownExtractionOptions())
        #expect(result.answers["vendor"] == .init(type: .text, value: "best", confidence: 0.9))
        #expect(result.answers["missing"]?.value == nil)
    }

    @Test func sourcesRejectSplitUTF8CharactersCrossPartSpansAndInvalidOCROffsets() throws {
        let state: [AIDecisionStatePart] = [.text("🙂 Acmé"), .file(mediaType: "application/pdf", data: .base64("AQID"))]
        #expect(try scaleDownExtractionSource(text: "Acmé", start: 5, end: 10, state: state, ocrText: "Acmé") == .text(part: 0, start: 3, end: 7))
        #expect(try scaleDownExtractionSource(text: "Acmé", start: 6, end: 11, state: state, ocrText: "Acmé") == nil)
        #expect(try scaleDownExtractionSource(text: "Acme", start: 5, end: 9, state: state, ocrText: "Acme") == nil)
        #expect(try scaleDownExtractionSource(text: "OCR", start: 10, end: 13, state: state, ocrText: "OCR") == .file(part: 1))
        #expect(try scaleDownExtractionSource(text: "OCR", start: 10, end: 13, state: state, ocrText: "other") == nil)
        #expect(try scaleDownExtractionSource(text: "OCR", start: nil, end: 13, state: state, ocrText: "OCR") == nil)
    }
}
