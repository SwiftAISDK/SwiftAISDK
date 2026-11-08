import Foundation
import Testing
@testable import SwiftAITypeSafeAI
import SwiftAIProvider

@Suite("Weekly20261108 TypeSafe state and legends")
struct Weekly20261108DecisionTests {
    @Test func boxWithoutInstructionsEnablesImagesWithoutImageAssets() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"answers":{"box":{"type":"box","box":{"top":0,"bottom":1,"left":0,"right":1}}}}"#))
        let provider = createTypeSafeAI(configuration: .init(apiKey: "key", transport: transport))
        _ = try await provider.decisionModel("jev-latest").doDecide(.init(state: [.text("state")], questions: ["box": .box()]))
        let sent = try #require(await transport.requests().first)
        let body = try JSONDecoder().decode(JSONValue.self, from: #require(sent.body))
        #expect(sent.headers["typesafe-danger-zone-images"] == "true")
        #expect(body["assets"] == .null)
        #expect(body["questions"]?["box"] == ["type": "box", "instructions": .null])
    }

    @Test(arguments: [Optional<JSONValue>.none, JSONValue.null, [:]])
    func missingNullAndEmptyLegendsProduceEmptyMetadata(_ legend: JSONValue?) async throws {
        var answer: [String: JSONValue] = ["type": "score", "score": 0, "probabilities": ["0": 1]]
        if let legend { answer["legend"] = legend }
        let raw: JSONValue = ["answers": ["rating": .object(answer)]]
        let transport = RecordingTransport(response: .init(statusCode: 200, body: try JSONEncoder().encode(raw)))
        let provider = createTypeSafeAI(configuration: .init(apiKey: "key", transport: transport))
        let result = try await provider.decisionModel("jev-latest").doDecide(.init(state: [.text("state")], questions: ["rating": .score(criteria: ["Low"])]))
        #expect(result.providerMetadata["typesafe"]?["legend"] == (legend?.objectValue == nil ? [:] : ["rating": legend!]))
    }

    @Test(arguments: [255, 256])
    func choiceLimitIncludes255(_ count: Int) async throws {
        let criteria = Dictionary(uniqueKeysWithValues: (0..<count).map { (String($0), JSONValue.string("Option \($0)")) })
        let transport = RecordingTransport(response: jsonResponse(#"{"answers":{"q":{"type":"choice","choice":"0","probabilities":{"0":1}}}}"#))
        let provider = createTypeSafeAI(configuration: .init(apiKey: "key", transport: transport))
        let model = try provider.decisionModel("jev-latest")
        let options = AIDecisionModelV4CallOptions(state: [.text("state")], questions: ["q": .choice(criteria: criteria)])
        if count == 255 { _ = try await model.doDecide(options); #expect(await transport.requests().count == 1) }
        else { await #expect(throws: AIError.self) { try await model.doDecide(options) }; #expect(await transport.requests().isEmpty) }
    }

    @Test(arguments: [JSONValue.null, true, false, 0, 42, "literal"])
    func primitiveStateAndStructuredLegends(_ input: JSONValue) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"answers":{"rating":{"type":"score","score":0,"probabilities":{"0":1},"legend":{"0":{"meaning":"Low"}}}}}"#))
        let provider = createTypeSafeAI(configuration: .init(apiKey: "key", transport: transport))
        let result = try await provider.decisionModel("jev-latest").doDecide(.init(state: [.json(input)], questions: ["rating": .score(criteria: ["Low"])]))
        let request = try #require(await transport.requests().first)
        let body = try JSONDecoder().decode(JSONValue.self, from: #require(request.body))
        let expected = try input.stringValue ?? String(data: JSONEncoder().encode(input), encoding: .utf8)!
        #expect(body["state"] == .string(expected))
        #expect(result.providerMetadata["typesafe"]?["legend"] == ["rating": ["0": ["meaning": "Low"]]])
    }
    @Test func emptyAndNullCriteriaFailBeforeHTTP() async throws {
        let transport = RecordingTransport(responses: [])
        let provider = createTypeSafeAI(configuration: .init(apiKey: "key", transport: transport))
        let model = try provider.decisionModel("jev-latest")
        for question in [AIDecisionQuestion.choice(criteria: [:]), .score(criteria: []), .score(criteria: [.null])] {
            await #expect(throws: AIError.self) { try await model.doDecide(.init(state: [.text("state")], questions: ["q": question])) }
        }
        #expect(await transport.requests().isEmpty)
    }
}
