// Translated from @ai-sdk/scaledown@3.0.1 scaledown-decision-model.test.ts.
// Exact source ref and scenario dispositions: Porting/upstream-tests.json.
import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
@testable import SwiftAIScaleDown

@Suite("ScaleDown matching-release decision tests", .serialized)
struct ScaleDownDecisionUpstreamTests {
    @Test func mapsQuestionsNativeAnswersUsageAndMetadata() async throws {
        let fixture = scaleDownDecisionResponse()
        let transport = try ScaleDownRecordingTransport(fixture)
        let provider = createScaleDown(configuration: .init(apiKey: "test-key", transport: transport))
        let model = try provider.decisionModel("classify-1")
        let result = try await model.doDecide(scaleDownDecisionOptions())
        let (request, body) = try await scaleDownRequest(transport)
        #expect(body == ["model": "classify-1", "state": ["text": "The export crashes in Safari."], "questions": [
            "category": ["type": "choice", "criteria": ["bug": "Broken functionality", "feedback": "feedback"]],
            "workaround": ["type": "noul", "instructions": "Is there a workaround?"],
            "severity": ["type": "score", "criteria": ["Cosmetic", "Degraded", "Blocking"]]
        ]])
        #expect(request.url.absoluteString == "https://api.scaledown.xyz/v1/scaledown")
        #expect(request.headers["x-api-key"] == "test-key")
        #expect(result.answers == ["category": .choice(choice: "bug", probabilities: ["bug": 0.93, "feedback": 0.07]),
                                   "workaround": .boolean(probability: 0.79),
                                   "severity": .score(score: 1.43, probabilities: ["0": 0, "1": 0.57, "2": 0.43])])
        #expect(result.usage == .init(inputTokens: 103, outputTokens: 3))
        #expect(result.providerMetadata == ["scaledown": ["confidence": ["category": 0.93, "severity": 0.57],
            "legend": ["severity": ["0": "Cosmetic", "1": "Degraded", "2": "Blocking"]], "cost": 0.0000044]])
        #expect(result.response?.modelID == "classify-1")
        #expect(result.response?.body == fixture)
        #expect(result.warnings.isEmpty)
        #expect(result.rounding == nil)
    }

    @Test func preservesJSONStructuredRubricsAndBooleanCriteriaAsText() async throws {
        let transport = try ScaleDownRecordingTransport(scaleDownDecisionResponse())
        let model = try createScaleDown(configuration: .init(apiKey: "test-key", transport: transport)).decisionModel("classify-1")
        _ = try await model.doDecide(.init(state: [.json(["ticket": "Export is broken"])], questions: [
            "category": .choice(instructions: ["task": "Route"], criteria: ["bug": ["Broken"]]),
            "workaround": .boolean(criteria: ["true": "Another browser works", "false": "No alternative works"])
        ]))
        let (_, body) = try await scaleDownRequest(transport)
        #expect(body["state"] == ["text": "{\"ticket\":\"Export is broken\"}"])
        #expect(body["questions"]?["category"]?["instructions"] == "{\"task\":\"Route\"}")
        #expect(body["questions"]?["category"]?["criteria"] == ["bug": "[\"Broken\"]"])
        #expect(body["questions"]?["workaround"] == ["type": "noul", "instructions": "Answer yes when: Another browser works\nAnswer no when: No alternative works"])
    }

    @Test func encodesDocumentAlongsideText() async throws {
        let transport = try ScaleDownRecordingTransport(scaleDownDecisionResponse())
        var options = scaleDownDecisionOptions()
        options.state = [.text("Classify this invoice."), .file(mediaType: "application/pdf", data: .data(Data([1, 2, 3])))]
        let model = try createScaleDown(configuration: .init(apiKey: "test-key", transport: transport)).decisionModel("classify-1")
        _ = try await model.doDecide(options)
        let (_, body) = try await scaleDownRequest(transport)
        #expect(body["state"] == ["text": "Classify this invoice.", "document": "AQID", "document_mime_type": "application/pdf"])
    }

    @Test func customAsyncCredentialsURLHeadersAbortSignalAndModelID() async throws {
        let transport = try ScaleDownRecordingTransport(scaleDownDecisionResponse())
        let controller = AIAbortController()
        let model = try createScaleDown(configuration: .init(apiKeyProvider: { "custom-key" }, baseURL: "https://custom.example/",
            headers: ["shared": "provider"], transport: transport)).decisionModel("classify")
        var options = scaleDownDecisionOptions(); options.abortSignal = controller.signal; options.headers = ["shared": "call"]
        _ = try await model.doDecide(options)
        let (request, body) = try await scaleDownRequest(transport)
        #expect(request.url.absoluteString == "https://custom.example/v1/scaledown")
        #expect(request.headers["x-api-key"] == "custom-key")
        #expect(request.headers["user-agent"]?.contains("ai-sdk-scaledown/3.0.3") == true)
        #expect(request.headers["shared"] == "call")
        #expect(request.abortSignal === controller.signal)
        #expect(body["model"] == "classify")
    }

    @Test func environmentAuthenticationAliasesAndSupportedTypes() async throws {
        let transport = try ScaleDownRecordingTransport(scaleDownDecisionResponse())
        let provider = createScaleDown(configuration: .init(environment: ["SCALEDOWN_API_KEY": "env-key"], transport: transport))
        let model = try provider.decisionModel("classify-1")
        _ = try await model.doDecide(scaleDownDecisionOptions())
        let (request, _) = try await scaleDownRequest(transport)
        #expect(request.headers["x-api-key"] == "env-key")
        #expect(model.supportedQuestionTypes == [.choice, .boolean, .score])
        #expect(model.providerID == "scaledown.decision")
        #expect(model.specificationVersion == "v4")
        #expect(scaleDown === scaledown)
    }

    @Test func unsupportedSettingsAndProviderOptionWarnings() async throws {
        let transport = try ScaleDownRecordingTransport(scaleDownDecisionResponse())
        var options = scaleDownDecisionOptions(); options.maxOutputTokens = 10; options.reasoning = "high"
        options.providerOptions = ["scaledown": ["reasoning": true]]
        let model = try createScaleDown(configuration: .init(apiKey: "test-key", transport: transport)).decisionModel("classify-1")
        let result = try await model.doDecide(options)
        #expect(result.warnings == [.init(type: "unsupported", feature: "maxOutputTokens"), .init(type: "unsupported", feature: "reasoning"),
                                   .init(type: "unsupported", feature: "providerOptions.scaledown.reasoning")])
    }

    @Test(arguments: [[JSONValue.string("Only level")], Array(repeating: JSONValue.string("Level"), count: 11), ["Low", .null]])
    func rejectsUnsupportedScoreCriteriaBeforeIO(_ criteria: [JSONValue]) async throws {
        let transport = try ScaleDownRecordingTransport(scaleDownDecisionResponse())
        let model = try createScaleDown(configuration: .init(apiKey: "test-key", transport: transport)).decisionModel("classify-1")
        var options = scaleDownDecisionOptions(); options.questions = ["severity": .score(criteria: criteria)]
        await #expect(throws: AIError.invalidArgument(argument: "questions.severity.criteria", message: "ScaleDown Score questions require 2 to 10 non-null levels.")) {
            _ = try await model.doDecide(options)
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test func unsupportedQuestionsFilesAndFactoriesFailBeforeIO() async throws {
        let transport = try ScaleDownRecordingTransport(scaleDownDecisionResponse())
        let provider = createScaleDown(configuration: .init(apiKey: "test-key", transport: transport))
        let model = try provider.decisionModel("classify-1")
        var options = scaleDownDecisionOptions(); options.questions = ["location": .box()]
        await #expect(throws: AIDecisionUnsupportedQuestionTypeError(questionID: "location", questionType: .box, providerID: "scaledown.decision", modelID: "classify-1")) {
            _ = try await model.doDecide(options)
        }
        options = scaleDownDecisionOptions(); options.state = [.file(mediaType: "audio/wav", data: .base64("AQID"))]
        await #expect(throws: AIDecisionUnsupportedFunctionalityError.self) { _ = try await model.doDecide(options) }
        #expect(await transport.requests.isEmpty)
        #expect(throws: AIError.unsupportedModel(provider: "scaledown", capability: .language, modelID: "unknown")) { _ = try provider.languageModel("unknown") }
        #expect(throws: AIError.unsupportedModel(provider: "scaledown", capability: .embedding, modelID: "unknown")) { _ = try provider.embeddingModel("unknown") }
        #expect(throws: AIError.unsupportedModel(provider: "scaledown", capability: .image, modelID: "unknown")) { _ = try provider.imageModel("unknown") }
    }

    @Test(arguments: [JSONValue.object(["detail": "Insufficient credits"]), ["detail": [["msg": "Invalid model"]]]])
    func surfacesAPIErrorDetails(_ body: JSONValue) async throws {
        let transport = try ScaleDownRecordingTransport(body, status: 422)
        let model = try createScaleDown(configuration: .init(apiKey: "test-key", transport: transport)).decisionModel("classify-1")
        try await expectScaleDownAPIError(status: 422, message: body["detail"]?.stringValue ?? "Invalid model") {
            _ = try await model.doDecide(scaleDownDecisionOptions())
        }
    }

    @Test func rejectsMalformedSuccessfulResponseAsAPICallError() async throws {
        let transport = try ScaleDownRecordingTransport(["answers": ["category": ["type": "choice"]]])
        let model = try createScaleDown(configuration: .init(apiKey: "test-key", transport: transport)).decisionModel("classify-1")
        await #expect(throws: AIError.self) { _ = try await model.doDecide(scaleDownDecisionOptions()) }
        do { _ = try await model.doDecide(scaleDownDecisionOptions()); Issue.record("Expected malformed-response error") }
        catch let AIError.apiCall(error) { #expect(error.statusCode == 200); #expect(!error.isRetryable) }
    }
}
