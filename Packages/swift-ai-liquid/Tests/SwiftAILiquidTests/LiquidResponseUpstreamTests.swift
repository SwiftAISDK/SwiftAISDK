import SwiftAILiquid
import SwiftAIProvider
import Testing

@Suite struct LiquidResponseUpstreamTests {
    @Test func mapsAnswersAndPreservesConfidenceLegendsUsageCostAndResponseMetadata() async throws {
        let (model, _) = try liquidSetup()
        let result = try await model.doDecide(.init(state: liquidState, questions: liquidQuestions))
        #expect(result.answers == [
            "department": .choice(choice: "billing", probabilities: [
                "billing": 0.7977884625727154, "technical": 0.1945331761734925, "sales": 0.007678361253792198
            ]),
            "is_urgent": .boolean(probability: 0.946241977297085),
            "frustration": .score(score: 0.9021501653859363, probabilities: [
                "0": 0.23247550647082207, "1": 0.6328988216724196, "2": 0.13462567185675836
            ])
        ])
        #expect(result.rounding == nil)
        #expect(result.usage == .init(inputTokens: 612, outputTokens: 0))
        #expect(result.warnings.isEmpty)
        #expect(result.providerMetadata == ["liquid": [
            "cost": 0.00001224,
            "confidence": ["department": 0.6966826938590731, "frustration": 0.4493482325086293],
            "legend": ["frustration": ["0": "Calm", "1": "Frustrated", "2": "Very angry"]],
            "found": [:]
        ]])
        #expect(result.response?.modelID == "d1.2")
        #expect(result.response?.headers["x-trace"] == "trace-1")
        #expect(result.response?.body == liquidTextResponse)
    }

    @Test func sendsBoxWithImageAndMapsBox() async throws {
        let (model, transport) = try liquidSetup(["model": "d1.2", "answers": ["subject": liquidFixture["answers"]!["subject"]!]])
        let result = try await model.doDecide(.init(state: liquidBoxState, questions: liquidBoxQuestions))
        #expect(try await transport.requestBody() == [
            "model": "d1.2", "state": "A support screenshot.",
            "images": ["data:image/png;base64,iVBORw0KGgo="],
            "questions": ["subject": ["type": "box", "instructions": "The animal in the picture."]]
        ])
        #expect(result.answers == ["subject": .box(box: .init(
            top: 0.005667045050048388, bottom: 0.9912829814932079, left: 0.012289810011782244, right: 0.9958878113456595
        ))])
        #expect(result.providerMetadata["liquid"]?["confidence"] == ["subject": 0.9874605055292258])
        #expect(result.providerMetadata["liquid"]?["found"] == ["subject": 1])
    }

    @Test func returnsRefusalWhenBoxObjectIsNotFound() async throws {
        let (model, _) = try liquidSetup(liquidNotFoundFixture)
        let result = try await model.doDecide(.init(state: liquidBoxState, questions: ["car": .box(instructions: "The red sports car.")]))
        #expect(result.answers == ["car": .refusal])
        #expect(result.providerMetadata["liquid"]?["found"] == ["car": 0.0012875843247724626])
    }

    @Test(arguments: [
        [String: JSONValue](),
        liquidTextAnswers.merging(["extra": liquidTextAnswers["is_urgent"]!]) { _, new in new },
        liquidTextAnswers.filter { $0.key != "is_urgent" }
    ])
    func rejectsMissingAndUnexpectedAnswers(answers: [String: JSONValue]) async throws {
        let (model, _) = try liquidSetup(["answers": .object(answers)])
        await #expect(throws: AIError.invalidResponse(provider: "liquid.decision", message: "Liquid must return exactly one answer for every question.")) {
            _ = try await model.doDecide(.init(state: liquidState, questions: liquidQuestions))
        }
    }

    @Test(arguments: [
        ["is_urgent": JSONValue.object(["type": "noul", "noul": 1.01])],
        ["department": ["type": "choice", "choice": "technical"]],
        ["is_urgent": ["type": "text", "text": "yes"]]
    ])
    func rejectsMalformedNativeResponses(replacement: [String: JSONValue]) async throws {
        let answers = liquidTextAnswers.merging(replacement) { _, new in new }
        let (model, _) = try liquidSetup(["answers": .object(answers)])
        await #expect {
            _ = try await model.doDecide(.init(state: liquidState, questions: liquidQuestions))
        } throws: { error in
            guard case let AIError.apiCall(call) = error else { return false }
            return call.statusCode == 200 && !call.isRetryable
        }
    }

    @Test func preservesLiquidErrorMessageAndCode() async throws {
        let (model, _) = try liquidSetup(["error": [
            "message": "Invalid API key provided.", "type": "authentication_error",
            "param": .null, "code": "invalid_api_key"
        ]], status: 401)
        await #expect {
            _ = try await model.doDecide(.init(state: liquidState, questions: liquidQuestions))
        } throws: { error in
            guard case let AIError.apiCall(call) = error else { return false }
            #expect(call.message == "Invalid API key provided. (invalid_api_key)")
            #expect(call.statusCode == 401)
            return true
        }
    }
}
