import Foundation
import SwiftAILiquid
import SwiftAIProvider
import Testing

@Suite struct LiquidRequestUpstreamTests {
    @Test func sendsOneNativeRequestWithConfiguredHeaders() async throws {
        let (model, transport) = try liquidSetup()
        _ = try await model.doDecide(.init(state: liquidState, questions: liquidQuestions, headers: ["shared": "call"]))
        #expect(model.specificationVersion == "v4")
        #expect(model.providerID == "liquid.decision")
        #expect(model.modelID == "d1.2")
        #expect(model.supportedQuestionTypes == [.choice, .score, .boolean, .box])
        let request = try await transport.request()
        #expect(request.method == "POST")
        #expect(request.url.absoluteString == "https://example.com/decisions/v1/systemone")
        #expect(request.headers["authorization"] == "Bearer test-key")
        #expect(request.headers["content-type"] == "application/json")
        #expect(request.headers["x-provider"] == "custom")
        #expect(request.headers["shared"] == "call")
        #expect(request.headers["user-agent"]?.contains("ai-sdk-liquid/") == true)
        #expect(try await transport.requestBody() == [
            "model": "d1.2",
            "state": "Help! My payouts have been failing for 3 days.",
            "questions": [
                "department": [
                    "type": "choice", "instructions": "Which team should handle this?",
                    "criteria": ["billing": "Payments, invoicing, refunds", "technical": "Bugs, outages, integrations", "sales": "Pricing, upgrades, new accounts"]
                ],
                "is_urgent": ["type": "noul", "instructions": "Does this convey urgency?"],
                "frustration": [
                    "type": "score", "instructions": "How frustrated is the customer?",
                    "criteria": ["Calm", "Frustrated", "Very angry"]
                ]
            ]
        ])
    }

    @Test func sendsSeparateOrderedMediaArraysAndJoinsTextAndJSON() async throws {
        let (model, transport) = try liquidSetup(["answers": ["is_urgent": liquidFixture["answers"]!["is_urgent"]!]])
        _ = try await model.doDecide(.init(state: [
            .text("The voice note belongs to this ticket."),
            .file(mediaType: "audio", data: .data(liquidWAV)),
            .file(mediaType: "image", data: .data(liquidPNG)),
            .file(mediaType: "image/webp", data: .base64("UklGRg==")),
            .json(["plan": "enterprise"])
        ], questions: ["is_urgent": liquidUrgency]))
        let request = try await transport.requestBody()
        #expect(request["state"] == "The voice note belongs to this ticket.\n{\"plan\":\"enterprise\"}")
        #expect(request["images"] == ["data:image/png;base64,iVBORw0KGgo=", "data:image/webp;base64,UklGRg=="])
        #expect(request["audio"] == ["data:audio/wav;base64,UklGRgAAAABXQVZF"])
    }

    @Test(arguments: [
        ([AIDecisionStatePart.json(["message": "Refund me"])], JSONValue.object(["message": "Refund me"])),
        ([.file(mediaType: "audio/mpeg", data: .base64("SUQz"))], .null)
    ])
    func sendsStructuredObjectOrNullForOnlyMedia(state: [AIDecisionStatePart], expected: JSONValue) async throws {
        let (model, transport) = try liquidSetup(["answers": ["is_urgent": liquidFixture["answers"]!["is_urgent"]!]])
        _ = try await model.doDecide(.init(state: state, questions: ["is_urgent": liquidUrgency]))
        #expect(try await transport.requestBody()["state"] == expected)
    }

    @Test(arguments: [
        [AIDecisionStatePart](repeating: liquidImage, count: 9),
        [AIDecisionStatePart](repeating: .file(mediaType: "audio/wav", data: .data(liquidWAV)), count: 9)
    ])
    func rejectsTooManyImagesOrAudioBeforeHTTP(state: [AIDecisionStatePart]) async throws {
        let (model, transport) = try liquidSetup()
        await #expect(throws: AIError.invalidArgument(argument: "state",
            message: "Liquid decisions support at most 8 images and 8 audio clips per request.")) {
            _ = try await model.doDecide(.init(state: state, questions: liquidQuestions))
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test(arguments: [
        AIDecisionStatePart.file(mediaType: "image/gif", data: .base64("R0lGOD==")),
        .file(mediaType: "audio", data: .data(Data([1, 2, 3]))),
        .file(mediaType: "video/mp4", data: .base64("AAAA")),
        .file(mediaType: "image/png", data: .url(URL(string: "https://example.com/a.png")!)),
        .file(mediaType: "image/png", data: .reference("file-1"))
    ])
    func rejectsUnsupportedMediaBeforeHTTP(file: AIDecisionStatePart) async throws {
        let (model, transport) = try liquidSetup()
        await #expect(throws: AIDecisionUnsupportedFunctionalityError.self) {
            _ = try await model.doDecide(.init(state: [file], questions: liquidQuestions))
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test(arguments: [
        [String: AIDecisionQuestion](),
        Dictionary(uniqueKeysWithValues: (0..<129).map { (String($0), liquidUrgency) }),
        ["is_urgent": .boolean(criteria: ["true": "Urgent", "false": "Not urgent"])],
        ["department": .choice(instructions: "Which team should handle this?", criteria: ["billing": .null])],
        ["department": .choice(instructions: "Which team should handle this?", criteria:
            Dictionary(uniqueKeysWithValues: (0..<256).map { (String($0), JSONValue.null) }))],
        ["frustration": .score(instructions: "How frustrated is the customer?", criteria: ["Calm"])],
        ["frustration": .score(instructions: "How frustrated is the customer?", criteria: (0..<11).map { .string(String($0)) })],
        ["frustration": .score(instructions: "How frustrated is the customer?", criteria: ["Calm", .null])]
    ])
    func rejectsInvalidQuestionLimitsBeforeHTTP(questions: [String: AIDecisionQuestion]) async throws {
        let (model, transport) = try liquidSetup()
        await #expect {
            _ = try await model.doDecide(.init(state: liquidBoxState, questions: questions))
        } throws: { error in
            guard case AIError.invalidArgument = error else { return false }
            return true
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test(arguments: [liquidState, liquidBoxState + [liquidImage]])
    func rejectsBoxWithoutExactlyOneImageBeforeHTTP(state: [AIDecisionStatePart]) async throws {
        let (model, transport) = try liquidSetup()
        await #expect(throws: AIError.invalidArgument(argument: "state",
            message: "Liquid Box questions require exactly one image in the state.")) {
            _ = try await model.doDecide(.init(state: state, questions: liquidBoxQuestions))
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test func sendsBooleanCriteriaAndNullChoiceDescriptions() async throws {
        let department = liquidTextAnswers["department"]!.objectValue!.merging(["probabilities": ["billing": 0.4, "technical": 0.6]]) { _, new in new }
        let (model, transport) = try liquidSetup(["answers": ["department": .object(department), "is_urgent": liquidTextAnswers["is_urgent"]!]])
        _ = try await model.doDecide(.init(state: liquidState, questions: [
            "department": .choice(instructions: "Which team?", criteria: ["billing": .null, "technical": .null]),
            "is_urgent": .boolean(instructions: "Urgent?", criteria: ["true": "Needs action today", "false": "Can wait"])
        ]))
        #expect(try await transport.requestBody()["questions"] == [
            "department": ["type": "choice", "instructions": "Which team?", "criteria": ["billing": .null, "technical": .null]],
            "is_urgent": ["type": "noul", "instructions": "Urgent?", "criteria": ["true": "Needs action today", "false": "Can wait"]]
        ])
    }

    @Test func warnsAboutUnsupportedSettingsWithoutAddingRequestFields() async throws {
        let (model, transport) = try liquidSetup()
        let result = try await model.doDecide(.init(state: liquidState, questions: liquidQuestions, maxOutputTokens: 10,
            reasoning: "low", providerOptions: ["liquid": ["temperature": 0]]))
        #expect(result.warnings == [
            .init(type: "unsupported", feature: "maxOutputTokens"),
            .init(type: "unsupported", feature: "reasoning"),
            .init(type: "unsupported", feature: "providerOptions.liquid.temperature")
        ])
        let body = try #require(try await transport.requestBody().objectValue)
        #expect(Set(body.keys) == ["model", "state", "questions"])
    }
}
