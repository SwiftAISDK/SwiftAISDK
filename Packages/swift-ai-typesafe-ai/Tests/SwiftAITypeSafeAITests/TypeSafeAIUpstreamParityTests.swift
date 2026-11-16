import Foundation
import Testing
@testable import SwiftAITypeSafeAI
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

// Translated from packages/typesafe-ai/src/typesafe-ai-decision-model.test.ts and
// typesafe-ai-provider.test.ts. `decision-request.json` and `decision-response.json`
// are copied verbatim from __fixtures__.

private let nativeRequest = """
{
  "model": "jev-latest",
  "state": {"message": "I was charged twice. Please refund the duplicate.", "order": {"amount": 49}},
  "questions": {
    "department": {
      "type": "choice",
      "instructions": {"question": "Which team should handle this?"},
      "criteria": {"billing": {"includes": ["Charges", "Invoices", "Refunds"]}, "technical": ["Bugs", "Outages"], "other": null}
    },
    "severity": {
      "type": "score",
      "instructions": ["How severe is the issue?"],
      "criteria": [{"meaning": "Cosmetic; functionality works"}, "Functionality impaired; workaround exists", "Blocking; no workaround"]
    },
    "requestsRefund": {
      "type": "noul",
      "instructions": "Is the customer requesting a refund?",
      "criteria": {"true": {"meaning": "Explicit request for money back"}, "false": null}
    }
  }
}
"""

private let nativeResponse = """
{
  "model": "jev-1.13.0",
  "answers": {
    "department": {"type": "choice", "choice": "billing", "confidence": 1.0, "probabilities": {"technical": 0.0, "other": 0.0, "billing": 1.0}},
    "severity": {"type": "score", "score": 0.97, "confidence": 0.64, "legend": {"0": {"meaning": "Cosmetic; functionality works"}}, "probabilities": {"0": 0.13, "1": 0.76, "2": 0.11}},
    "requestsRefund": {"type": "noul", "noul": 0.99}
  },
  "usage": {"input_tokens": 471, "output_tokens": 71}
}
"""

private func fixture(_ text: String) -> JSONValue { try! decodeJSONBody(Data(text.utf8)) }

private let expectedRequest = fixture(nativeRequest)

private let questions: [String: AIDecisionQuestion] = [
    "department": .choice(
        instructions: ["question": "Which team should handle this?"],
        criteria: ["billing": ["includes": ["Charges", "Invoices", "Refunds"]], "technical": ["Bugs", "Outages"], "other": .null]
    ),
    "severity": .score(
        instructions: ["How severe is the issue?"],
        criteria: [["meaning": "Cosmetic; functionality works"], "Functionality impaired; workaround exists", "Blocking; no workaround"]
    ),
    "requestsRefund": .boolean(
        instructions: "Is the customer requesting a refund?",
        criteria: ["true": ["meaning": "Explicit request for money back"], "false": .null]
    )
]

private let state: [AIDecisionStatePart] = [.json(expectedRequest["state"]!)]

private func options(
    state: [AIDecisionStatePart] = state,
    questions: [String: AIDecisionQuestion] = questions,
    maxOutputTokens: Int? = nil,
    reasoning: String? = nil,
    headers: [String: String] = [:],
    providerOptions: [String: JSONValue] = [:]
) -> AIDecisionModelV4CallOptions {
    AIDecisionModelV4CallOptions(state: state, questions: questions, maxOutputTokens: maxOutputTokens, reasoning: reasoning, headers: headers, providerOptions: providerOptions)
}

private func model(_ transport: RecordingTransport, modelID: String = "jev-latest", settings: TypeSafeAIProviderSettings? = nil) throws -> any AIDecisionModelV4 {
    var configuration = settings ?? TypeSafeAIProviderSettings(apiKey: "test-api-key", environment: [:])
    configuration.transport = transport
    return try createTypeSafeAi(configuration: configuration).decisionModel(modelID)
}

private func nativeTransport() -> RecordingTransport { RecordingTransport(response: jsonResponse(nativeResponse)) }

private func png(_ base64: String = "iVBORw==", reference: JSONValue? = nil, insertReference: Bool? = nil, filename: String? = nil) -> AIDecisionStatePart {
    var typesafe: [String: JSONValue] = [:]
    if let reference { typesafe["reference"] = reference }
    if let insertReference { typesafe["insertReference"] = .bool(insertReference) }
    return .file(mediaType: "image/png", data: .base64(base64), filename: filename, providerOptions: typesafe.isEmpty ? [:] : ["typesafe": .object(typesafe)])
}

private func jpeg(reference: String? = nil, insertReference: Bool? = nil) -> AIDecisionStatePart {
    var typesafe: [String: JSONValue] = [:]
    if let reference { typesafe["reference"] = .string(reference) }
    if let insertReference { typesafe["insertReference"] = .bool(insertReference) }
    return .file(mediaType: "image/jpeg", data: .base64("/9j/4A=="), providerOptions: typesafe.isEmpty ? [:] : ["typesafe": .object(typesafe)])
}

struct MultipartPart { var name: String; var filename: String?; var contentType: String?; var data: Data }

private func multipartParts(_ request: AIHTTPRequest) throws -> [MultipartPart] {
    let contentType = try #require(request.headers["content-type"])
    let boundary = try #require(contentType.components(separatedBy: "boundary=").last)
    let body = try #require(request.body)
    let delimiter = Data("--\(boundary)".utf8)
    var parts: [MultipartPart] = []
    var ranges: [Range<Data.Index>] = []
    var search = body.startIndex..<body.endIndex
    while let range = body.range(of: delimiter, in: search) {
        ranges.append(range)
        search = range.upperBound..<body.endIndex
    }
    for (index, range) in ranges.enumerated() where index + 1 < ranges.count {
        let chunk = body[range.upperBound..<ranges[index + 1].lowerBound]
        guard let split = chunk.range(of: Data("\r\n\r\n".utf8)) else { continue }
        let header = String(decoding: chunk[chunk.startIndex..<split.lowerBound], as: UTF8.self)
        var content = chunk[split.upperBound..<chunk.endIndex]
        if content.suffix(2) == Data("\r\n".utf8) { content = content.dropLast(2) }
        func attribute(_ key: String) -> String? {
            guard let start = header.range(of: "\(key)=\"") else { return nil }
            return String(header[start.upperBound...].prefix { $0 != "\"" })
        }
        let type = header.components(separatedBy: "\r\n").first { $0.lowercased().hasPrefix("content-type:") }
            .map { $0.dropFirst("content-type:".count).trimmingCharacters(in: .whitespaces) }
        parts.append(MultipartPart(name: attribute("name") ?? "", filename: attribute("filename"), contentType: type, data: Data(content)))
    }
    return parts
}

private func multipartRequestBody(_ transport: RecordingTransport, call: Int = 0) async throws -> (JSONValue, [MultipartPart]) {
    let request = try #require(await transport.requests().dropFirst(call).first)
    let parts = try multipartParts(request)
    let requestPart = try #require(parts.first { $0.name == "request" })
    // JSONDecoder, not secureJSONParse: the request legitimately carries `__proto__` references.
    return (try JSONDecoder().decode(JSONValue.self, from: requestPart.data), parts)
}

private func jsonBody(_ transport: RecordingTransport) async throws -> JSONValue {
    try decodeJSONBody(try #require(await transport.requests().first?.body))
}

@Suite("TypeSafe decision model (upstream)", .serialized)
struct TypeSafeAIUpstreamDecisionTests {
    @Test func sendsAllThreeQuestionTypesAndStructuredRubricsInOneRequest() async throws {
        let transport = nativeTransport()
        _ = try await model(transport).doDecide(options())
        let request = try #require(await transport.requests().first)
        #expect(await transport.requests().count == 1)
        #expect(try decodeJSONBody(try #require(request.body)) == expectedRequest)
        #expect(request.headers["authorization"] == "Bearer test-api-key")
        #expect(request.headers["content-type"] == "application/json")
    }

    @Test func preservesNativeScoresProbabilitiesConfidenceMetadataAndUsage() async throws {
        let result = try await model(nativeTransport()).doDecide(options())
        #expect(result.answers == [
            "department": .choice(choice: "billing", probabilities: ["technical": 0, "other": 0, "billing": 1]),
            "severity": .score(score: 0.97, probabilities: ["0": 0.13, "1": 0.76, "2": 0.11]),
            "requestsRefund": .boolean(probability: 0.99)
        ])
        #expect(result.rounding == AIDecisionRounding(probabilityDecimals: 2, scoreDecimals: 2))
        #expect(result.providerMetadata == ["typesafe": ["confidence": ["department": 1, "severity": 0.64], "legend": ["severity": ["0": ["meaning": "Cosmetic; functionality works"]]]]])
        #expect(result.usage == AIDecisionModelUsage(inputTokens: 471, outputTokens: 71))
        #expect(result.response?.modelID == "jev-1.13.0")
        #expect(result.response?.body == fixture(nativeResponse))
    }

    @Test func reportsUnsupportedProviderOptionsWithoutPassingThemThrough() async throws {
        let transport = nativeTransport()
        let result = try await model(transport).doDecide(options(providerOptions: ["typesafe": ["temperature": 0]]))
        #expect(result.warnings == [AIWarning(type: "unsupported", feature: "providerOptions.typesafe.temperature")])
        #expect(try await jsonBody(transport) == expectedRequest)
    }

    @Test(arguments: ["jev-1.13.0", "jev-1.14.0", "jev-latest", "jev-preview"])
    func sendsTheModelIDOrAliasUnchanged(modelID: String) async throws {
        let transport = nativeTransport()
        _ = try await model(transport, modelID: modelID).doDecide(options())
        var expected = try #require(expectedRequest.objectValue)
        expected["model"] = .string(modelID)
        #expect(try await jsonBody(transport) == .object(expected))
    }

    @Test(arguments: [true, false, nil] as [Bool?])
    func enablesTheLongContextHeaderOnlyWhenTrue(longContext: Bool?) async throws {
        let transport = nativeTransport()
        let result = try await model(transport).doDecide(options(
            providerOptions: longContext.map { ["typesafe": ["longContext": .bool($0)]] } ?? [:]
        ))
        let request = try #require(await transport.requests().first)
        #expect(request.headers["typesafe-danger-zone-long-context"] == (longContext == true ? "true" : nil))
        #expect(try decodeJSONBody(try #require(request.body)) == expectedRequest)
        #expect(result.warnings == [])
    }

    @Test func combinesLongContextWithImageSupportAndWarnsOnlyForUnknownOptions() async throws {
        let transport = nativeTransport()
        let result = try await model(transport).doDecide(options(
            state: [png()],
            headers: ["x-custom": "custom"],
            providerOptions: ["typesafe": ["longContext": true, "temperature": 0]]
        ))
        let headers = try #require(await transport.requests().first).headers
        #expect(headers["typesafe-danger-zone-images"] == "true")
        #expect(headers["typesafe-danger-zone-long-context"] == "true")
        #expect(headers["x-custom"] == "custom")
        #expect(result.warnings == [AIWarning(type: "unsupported", feature: "providerOptions.typesafe.temperature")])
    }

    @Test(arguments: [JSONValue.string("true"), .number(1), .null])
    func rejectsInvalidLongContextValues(longContext: JSONValue) async throws {
        let transport = nativeTransport()
        await #expect(throws: AIError.self) {
            _ = try await model(transport).doDecide(options(providerOptions: ["typesafe": .object(["longContext": longContext])]))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test(arguments: [
        AIDecisionQuestion.choice(criteria: [:]),
        .choice(instructions: "Pick", criteria: Dictionary(uniqueKeysWithValues: (0..<256).map { (String($0), JSONValue.null) })),
        .score(instructions: "Rate", criteria: (0..<11).map { .string("Level \($0)") }),
        .score(criteria: []),
        .score(criteria: [.null]),
        .score(criteria: ["Low", .null])
    ])
    func rejectsProviderLimitsBeforeHTTP(question: AIDecisionQuestion) async throws {
        let transport = nativeTransport()
        await #expect {
            _ = try await model(transport).doDecide(options(state: [.text("test")], questions: ["question": question]))
        } throws: { error in
            if case .invalidArgument(argument: "questions.question.criteria", _) = error as? AIError { return true }
            return false
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func rejectsMalformedSuccessfulResponsesAsInvalidJSONResponse() async throws {
        let body = #"{"answers":{"test":{"type":"noul"}}}"#
        do {
            _ = try await model(RecordingTransport(response: jsonResponse(body))).doDecide(options())
            Issue.record("Expected an API call error")
        } catch let AIError.apiCall(error) {
            #expect(error.message == "Invalid JSON response")
            #expect(error.responseBody == body)
            #expect(error.isRetryable == false)
        }
    }

    @Test func mapsTextAndJSONPartsToNativeTextState() async throws {
        let transport = nativeTransport()
        _ = try await model(transport).doDecide(options(state: [.text("Inspect."), .json([1, .null])]))
        #expect(try await jsonBody(transport)["state"] == "Inspect.\n[1,null]")
    }

    @Test(arguments: [JSONValue.object(["nested": ["amount": 49], "history": ["refund"]]), .array([1, .null])])
    func preservesASingleJSONStatePartAsNativeJSON(value: JSONValue) async throws {
        let transport = nativeTransport()
        _ = try await model(transport).doDecide(options(state: [.json(value)]))
        #expect(try await jsonBody(transport)["state"] == value)
    }

    @Test func preservesASingleJSONStringStateWithoutAddingQuotes() async throws {
        let transport = nativeTransport()
        _ = try await model(transport).doDecide(options(state: [.json("Customer requests a refund.")]))
        #expect(try await jsonBody(transport)["state"] == "Customer requests a refund.")
    }

    @Test(arguments: [1, 10])
    func supportsNonNullScoreLevels(length: Int) async throws {
        let criteria = (0..<length).map { JSONValue.string("Level \($0)") }
        let legend = JSONValue.object(Dictionary(uniqueKeysWithValues: criteria.enumerated().map { (String($0.offset), $0.element) }))
        let probabilities = JSONValue.object(Dictionary(uniqueKeysWithValues: (0..<length).map { (String($0), JSONValue.number($0 == 0 ? 1 : 0)) }))
        let response: JSONValue = ["model": "jev-1.13.0", "answers": ["rating": ["type": "score", "score": 0, "probabilities": probabilities, "confidence": 1, "legend": legend]]]
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 200, headers: ["content-type": "application/json"], body: try encodeJSONBody(response)))
        let result = try await model(transport).doDecide(options(questions: ["rating": .score(criteria: criteria)]))
        #expect(try await jsonBody(transport)["questions"]?["rating"] == ["type": "score", "criteria": .array(criteria)])
        var expectedProbabilities: [String: Double] = [:]
        for level in 0..<length {
            expectedProbabilities[String(level)] = level == 0 ? 1 : 0
        }
        let expected = AIDecisionAnswer.score(score: 0, probabilities: expectedProbabilities)
        #expect(result.answers["rating"] == expected)
        #expect(result.providerMetadata["typesafe"]?["legend"] == ["rating": legend])
    }

    @Test func forwardsOptionalBoxInstructions() async throws {
        // Swift's `.box()` default stands for upstream `{}` / `{ instructions: undefined }`,
        // which JSON.stringify omits; the explicit-null variant is not representable.
        let box: JSONValue = ["top": 0.25, "bottom": 0.82, "left": 0.44, "right": 0.84]
        let response: JSONValue = ["answers": ["target": ["type": "box", "box": box, "confidence": .null]]]
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 200, headers: ["content-type": "application/json"], body: try encodeJSONBody(response)))
        let result = try await model(transport).doDecide(options(questions: ["target": .box()]))
        let request = try #require(await transport.requests().first)
        #expect(try decodeJSONBody(try #require(request.body))["questions"]?["target"] == ["type": "box"])
        #expect(request.headers["typesafe-danger-zone-images"] == "true")
        #expect(result.answers["target"] == .box(box: AIDecisionBox(top: 0.25, bottom: 0.82, left: 0.44, right: 0.84)))
    }

    @Test(arguments: [true, false])
    func sendsBoxQuestionsAndEnablesTheImagesHeader(withImage: Bool) async throws {
        var response = try #require(fixture(nativeResponse).objectValue)
        var answers = try #require(response["answers"]?.objectValue)
        answers["target"] = ["type": "box", "box": ["top": 0.25, "bottom": 0.82, "left": 0.44, "right": 0.84], "confidence": 0.92]
        response["answers"] = .object(answers)
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 200, headers: ["content-type": "application/json"], body: try encodeJSONBody(.object(response))))
        var boxQuestions = questions
        boxQuestions["target"] = .box(instructions: "The mug")
        let result = try await model(transport).doDecide(options(
            state: withImage ? [.file(mediaType: "image/png", data: .data(Data([1, 2, 3])))] : state,
            questions: boxQuestions
        ))
        #expect(result.answers["target"] == .box(box: AIDecisionBox(top: 0.25, bottom: 0.82, left: 0.44, right: 0.84)))
        #expect(result.providerMetadata["typesafe"]?["confidence"]?["target"] == 0.92)
        let request = try #require(await transport.requests().first)
        #expect(request.headers["typesafe-danger-zone-images"] == "true")
        let body = withImage ? try await multipartRequestBody(transport).0 : try decodeJSONBody(try #require(request.body))
        #expect(body["questions"]?["target"] == ["type": "box", "instructions": "The mug"])
    }

    @Test func warnsAboutUnsupportedMaxOutputTokensWithoutSendingIt() async throws {
        let transport = nativeTransport()
        let result = try await model(transport).doDecide(options(maxOutputTokens: 512))
        #expect(result.warnings == [AIWarning(type: "unsupported", feature: "maxOutputTokens")])
        #expect(try await jsonBody(transport) == expectedRequest)
    }

    @Test(arguments: [nil, "none", "provider-default", "high"] as [String?])
    func warnsAboutUnsupportedReasoningWithoutSendingIt(reasoning: String?) async throws {
        let transport = nativeTransport()
        let result = try await model(transport).doDecide(options(reasoning: reasoning))
        #expect(result.warnings == (reasoning == nil ? [] : [AIWarning(type: "unsupported", feature: "reasoning")]))
        #expect(try await jsonBody(transport) == expectedRequest)
    }

    @Test func ordersProviderOptionWarningsBeforeSharedControlWarnings() async throws {
        // getArgs pushes provider-option warnings first, then maxOutputTokens, then reasoning.
        let result = try await model(nativeTransport()).doDecide(options(
            maxOutputTokens: 10,
            reasoning: "high",
            providerOptions: ["typesafe": ["temperature": 0]]
        ))
        #expect(result.warnings.map(\.feature) == ["providerOptions.typesafe.temperature", "maxOutputTokens", "reasoning"])
    }

    @Test func preservesStructuredScoreLegendsInProviderMetadataAndTheRawResponse() async throws {
        let legend: JSONValue = ["0": ["meaning": "Cosmetic", "examples": ["Color mismatch"]], "1": ["Workaround exists", ["impact": "Limited"]], "2": "Blocking"]
        var response = try #require(fixture(nativeResponse).objectValue)
        var answers = try #require(response["answers"]?.objectValue)
        var severity = try #require(answers["severity"]?.objectValue)
        severity["legend"] = legend
        answers["severity"] = .object(severity)
        response["answers"] = .object(answers)
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 200, headers: ["content-type": "application/json"], body: try encodeJSONBody(.object(response))))
        let result = try await model(transport).doDecide(options())
        #expect(result.providerMetadata["typesafe"]?["legend"] == ["severity": legend])
        #expect(result.response?.body == .object(response))
    }
}

@Suite("TypeSafe image input (upstream)", .serialized)
struct TypeSafeAIUpstreamImageTests {
    @Test(arguments: ["[animal-photo]", "__proto__", "constructor", "request"])
    func usesAnExplicitReferenceInAssetsStateInstructionsAndCriteria(reference: String) async throws {
        let transport = nativeTransport()
        let imageQuestions: [String: AIDecisionQuestion] = [
            "cat": .boolean(instructions: .string("Does \(reference) show a cat?"), criteria: ["true": ["image": .string(reference)]])
        ]
        let result = try await model(transport).doDecide(options(
            state: [png(reference: .string(reference), filename: "unrelated-name.png"), jpeg()],
            questions: imageQuestions
        ))
        let (body, parts) = try await multipartRequestBody(transport)
        let assets = try #require(body["assets"]?.objectValue)
        #expect(assets.count == 2)
        #expect(assets[reference] == ["type": "image", "part": "image-0"])
        let generated = try #require(assets.keys.first { $0 != reference })
        #expect(body["state"] == .string("\(reference)\n\(generated)"))
        #expect(parts.first { $0.name == "image-0" }?.filename == "unrelated-name.png")
        #expect(body["questions"]?["cat"] == ["type": "noul", "instructions": .string("Does \(reference) show a cat?"), "criteria": ["true": ["image": .string(reference)]]])
        #expect(result.warnings == [])
    }

    @Test(arguments: [JSONValue.string(""), .string(" \t\n"), .number(123), .bool(true), .null])
    func rejectsInvalidReferencesBeforeHTTP(reference: JSONValue) async throws {
        let transport = nativeTransport()
        await #expect(throws: AIError.self) {
            _ = try await model(transport).doDecide(options(state: [png(reference: reference)]))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func keepsJSONStateAsAnObjectWhenItAlreadyContainsTheReference() async throws {
        let transport = nativeTransport()
        _ = try await model(transport).doDecide(options(state: [
            .json(["photo": "[photo]", "note": "Box arrived wet."]),
            png(reference: "[photo]")
        ]))
        let (body, parts) = try await multipartRequestBody(transport)
        #expect(body["state"] == ["photo": "[photo]", "note": "Box arrived wet."])
        #expect(body["assets"] == ["[photo]": ["type": "image", "part": "image-1"]])
        #expect(parts.map(\.name) == ["request", "image-1"])
        #expect(try #require(await transport.requests().first).headers["typesafe-danger-zone-images"] == "true")
    }

    @Test func leavesTextStateUnchangedWhenItAlreadyContainsTheReference() async throws {
        let transport = nativeTransport()
        _ = try await model(transport).doDecide(options(state: [.text("Is [photo] damaged?"), jpeg(reference: "[photo]")]))
        let (body, _) = try await multipartRequestBody(transport)
        #expect(body["state"] == "Is [photo] damaged?")
        #expect(body["assets"]?.objectValue?.keys.sorted() == ["[photo]"])
    }

    @Test func findsReferencesInNestedJSONStringValuesButNotInObjectKeys() async throws {
        let transport = nativeTransport()
        _ = try await model(transport).doDecide(options(state: [
            .json(["frames": [["seconds_ago": 0, "frame": "Latest frame: [frame]"]], "[label]": "A key is not a reference."]),
            png(reference: "[frame]"),
            png(reference: "[label]")
        ]))
        let (body, _) = try await multipartRequestBody(transport)
        // Platform difference: Swift JSON objects are unordered, so keys are sorted
        // where JSON.stringify keeps insertion order.
        #expect(body["state"]?.stringValue == #"{"[label]":"A key is not a reference.","frames":[{"frame":"Latest frame: [frame]","seconds_ago":0}]}"# + "\n[label]")
    }

    @Test func sendsAQuestionOnlyImageWithoutTouchingStateWhenInsertReferenceIsFalse() async throws {
        let transport = nativeTransport()
        _ = try await model(transport).doDecide(options(
            state: [.json(["photo": "[found]"]), jpeg(reference: "[found]"), jpeg(reference: "[poster]", insertReference: false)],
            questions: ["same": .boolean(instructions: "Is the dog in `photo` the dog in [poster]?")]
        ))
        let (body, _) = try await multipartRequestBody(transport)
        #expect(body["state"] == ["photo": "[found]"])
        #expect(body["assets"]?.objectValue?.keys.sorted() == ["[found]", "[poster]"])
    }

    @Test func insertsAReferenceAlreadyInStateWhenInsertReferenceIsTrue() async throws {
        let transport = nativeTransport()
        _ = try await model(transport).doDecide(options(state: [.text("Before: [photo]"), png(reference: "[photo]", insertReference: true)]))
        let (body, _) = try await multipartRequestBody(transport)
        #expect(body["state"] == "Before: [photo]\n[photo]")
    }

    @Test func insertsOnlyTheReferencesThatAreNotAlreadyPlaced() async throws {
        let transport = nativeTransport()
        _ = try await model(transport).doDecide(options(state: [
            .text("Compare [before] with the new photo."),
            png(reference: "[before]", insertReference: false),
            png(reference: "[after]")
        ]))
        let (body, _) = try await multipartRequestBody(transport)
        #expect(body["state"] == "Compare [before] with the new photo.\n[after]")
        #expect(body["assets"] == ["[before]": ["type": "image", "part": "image-1"], "[after]": ["type": "image", "part": "image-2"]])
    }

    @Test func rejectsInsertReferenceFalseWithoutAnExplicitReferenceBeforeHTTP() async throws {
        let transport = nativeTransport()
        await #expect {
            _ = try await model(transport).doDecide(options(state: [png(insertReference: false)]))
        } throws: { error in
            if case .invalidArgument(argument: "providerOptions.typesafe.reference", _) = error as? AIError { return true }
            return false
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func rejectsDuplicateImageReferencesBeforeHTTP() async throws {
        let transport = nativeTransport()
        await #expect(throws: AIError.invalidArgument(argument: "providerOptions.typesafe.reference", message: "Duplicate TypeSafe image reference: [photo]")) {
            _ = try await model(transport).doDecide(options(state: ["iVBORw==", "/9j/4A=="].map { png($0, reference: "[photo]") }))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func mapsMixedTextJSONAndMultipleImagesToReferencedAssets() async throws {
        let transport = nativeTransport()
        _ = try await model(transport).doDecide(options(state: [
            .text("Compare these images."),
            .file(mediaType: "image/png", data: .data(Data([137, 80, 78, 71]))),
            .json(["label": "second"]),
            jpeg()
        ]))
        let (body, parts) = try await multipartRequestBody(transport)
        let assets = try #require(body["assets"]?.objectValue)
        let first = try #require(assets.first { $0.value["part"]?.stringValue == "image-1" }?.key)
        let second = try #require(assets.first { $0.value["part"]?.stringValue == "image-3" }?.key)
        #expect(assets.count == 2 && first != second)
        #expect(body["state"] == .string("Compare these images.\n\(first)\n{\"label\":\"second\"}\n\(second)"))
        #expect(parts.map(\.name) == ["request", "image-1", "image-3"])
        #expect(parts[0].contentType == "application/json")
        #expect(parts[1].contentType == "image/png")
        #expect(parts[1].filename == "image-1.png")
        #expect(parts[1].data == Data([137, 80, 78, 71]))
        #expect(parts[2].contentType == "image/jpeg")
        #expect(parts[2].data == Data([255, 216, 255, 224]))
        let headers = try #require(await transport.requests().first).headers
        #expect(headers["content-type"]?.hasPrefix("multipart/form-data; boundary=") == true)
        #expect(headers["typesafe-danger-zone-images"] == "true")
    }

    @Test func omitsAssetsAndTheImageHeaderForTextOnlyInput() async throws {
        let transport = nativeTransport()
        _ = try await model(transport).doDecide(options())
        #expect(try await jsonBody(transport)["assets"] == nil)
        #expect(try #require(await transport.requests().first).headers["typesafe-danger-zone-images"] == nil)
    }

    @Test func usesFreshReferencesForEachRequest() async throws {
        let transport = nativeTransport()
        let decision = try model(transport)
        let imageOptions = options(state: [png("iVBORw0KGgo=")])
        _ = try await decision.doDecide(imageOptions)
        _ = try await decision.doDecide(imageOptions)
        let first = try await multipartRequestBody(transport, call: 0).0["state"]
        let second = try await multipartRequestBody(transport, call: 1).0["state"]
        #expect(first != second)
    }

    @Test(arguments: ["application/pdf", "image/webp", "image/gif", "image"])
    func rejectsUnsupportedOrUnrecognizedMediaBeforeHTTP(mediaType: String) async throws {
        let transport = nativeTransport()
        await #expect(throws: AIDecisionUnsupportedFunctionalityError(functionality: "TypeSafe AI decision image media type: \(mediaType)")) {
            _ = try await model(transport).doDecide(options(state: [.file(mediaType: mediaType, data: .base64("AAAA"))]))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test(arguments: [
        (AIDecisionFileData.url(URL(string: "https://example.com/image.png")!), "url"),
        (.reference("file-id"), "reference")
    ])
    func rejectsUnsupportedFileDataBeforeHTTP(data: AIDecisionFileData, kind: String) async throws {
        let transport = nativeTransport()
        await #expect(throws: AIDecisionUnsupportedFunctionalityError(functionality: "TypeSafe AI decision file input: image/png (\(kind))")) {
            _ = try await model(transport).doDecide(options(state: [.file(mediaType: "image/png", data: data)]))
        }
        #expect(await transport.requests().isEmpty)
    }
}

@Suite("TypeSafe provider (upstream)", .serialized)
struct TypeSafeAIUpstreamProviderTests {
    private func noulTransport() -> RecordingTransport {
        RecordingTransport(response: jsonResponse(#"{"model":"jev-latest","answers":{"configured":{"type":"noul","noul":1}}}"#))
    }

    private func decide(_ settings: TypeSafeAIProviderSettings, _ transport: RecordingTransport) async throws -> String {
        _ = try await model(transport, settings: settings).doDecide(AIDecisionModelV4CallOptions(
            state: [.text("The request used the configured endpoint.")],
            questions: ["configured": .boolean(instructions: "Did the request use the configured endpoint?")]
        ))
        return try #require(await transport.requests().first).url.absoluteString
    }

    @Test func providesTheExperimentalDecisionCapabilityAndDeprecatedAlias() throws {
        let provider = createTypeSafeAi(configuration: .init(apiKey: "key", environment: [:]))
        let decision = try provider.decisionModel("jev-latest")
        #expect(decision.specificationVersion == "v4")
        #expect(decision.providerID == "typesafe.decision")
        #expect(decision.modelID == "jev-latest")
        #expect(decision.supportedQuestionTypes == [.choice, .score, .boolean, .box])
        #expect(try provider.evaluationModel("jev-latest").providerID == "typesafe.decision")
    }

    @Test func usesTheDefaultBaseURLWhenTypeSafeBaseURLIsNotSet() async throws {
        #expect(try await decide(.init(apiKey: "test-api-key", environment: [:]), noulTransport()) == "https://api.typesafe.ai/v1/systemone")
    }

    @Test func usesTypeSafeBaseURLWithoutATrailingSlash() async throws {
        let url = try await decide(.init(apiKey: "test-api-key", environment: ["TYPESAFE_AI_BASE_URL": "https://proxy.example/v1/"]), noulTransport())
        #expect(url == "https://proxy.example/v1/systemone")
    }

    @Test func prefersTheBaseURLOptionOverTypeSafeBaseURL() async throws {
        let url = try await decide(.init(
            apiKey: "test-api-key",
            baseURL: "https://option.example/v1/",
            environment: ["TYPESAFE_AI_BASE_URL": "https://environment.example/v1"]
        ), noulTransport())
        #expect(url == "https://option.example/v1/systemone")
    }
}
