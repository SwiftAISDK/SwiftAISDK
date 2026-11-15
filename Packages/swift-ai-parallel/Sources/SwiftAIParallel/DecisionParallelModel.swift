import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

/// The native `/decisions` adapter. It retains full precision and request-level evidence.
public final class DecisionParallelModel: AIDecisionModelV4, Sendable {
    public let specificationVersion = "v4"
    public let providerID = "parallel.decision"
    public let modelID: String
    public let supportedQuestionTypes = parallelSupportedQuestionTypes
    private let configuration: ParallelProviderSettings

    init(modelID: String, configuration: ParallelProviderSettings) {
        self.modelID = modelID
        self.configuration = configuration
    }

    public func doDecide(_ options: AIDecisionModelV4CallOptions) async throws -> AIDecisionModelV4Result {
        try validateParallelQuestions(options.questions, modelID: modelID, providerID: providerID)
        let providerOptions = try parallelOptions(options.providerOptions)
        let state = try parallelState(options.state)
        try options.abortSignal?.throwIfAborted()
        let body: JSONValue = .object([
            "mode": .string(modelID),
            "include_excerpts": providerOptions["includeExcerpts"],
            "state": state,
            "questions": .object(options.questions.mapValues(parallelQuestion))
        ])
        let key = configuration.apiKey ?? (configuration.environment.map { $0["PARALLEL_API_KEY"] }
            ?? environmentValue(["PARALLEL_API_KEY"]))
        guard let key else {
            throw AIError.missingAPIKey(provider: "parallel", environmentVariables: ["PARALLEL_API_KEY"])
        }
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? "https://api.parallel.ai/v1")
        var headers = combineHeaders(["x-api-key": key], normalizeHeaders(configuration.headers))
        headers = withUserAgentSuffix(headers, "ai-sdk-parallel/\(parallelProviderVersion)")
        headers = combineHeaders(["content-type": "application/json"], headers, normalizeHeaders(options.headers))
        let request = AIHTTPRequest(method: "POST", url: try requireURL("\(baseURL)/decisions"), headers: headers,
                                    body: try encodeJSONBody(body), abortSignal: options.abortSignal)
        let response = try await configuration.transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            var error = parallelHTTPError(request: request, body: body, response: response, providerID: providerID)
            error.message = (try? response.jsonValue())?["error"]?["message"]?.stringValue
            throw AIError.apiCall(error)
        }
        let raw: JSONValue
        do { raw = try response.jsonValue() }
        catch {
            var error = parallelHTTPError(request: request, body: body, response: response, providerID: providerID, retryable: false)
            error.message = "Invalid JSON response."
            throw AIError.apiCall(error)
        }
        let parsed = try parseParallelDecisionResponse(raw, questionIDs: Set(options.questions.keys))
        var warnings: [AIWarning] = []
        if options.maxOutputTokens != nil { warnings.append(.init(type: "unsupported", feature: "maxOutputTokens")) }
        if options.reasoning != nil { warnings.append(.init(type: "unsupported", feature: "reasoning")) }
        warnings += providerOptions.keys.sorted().filter { $0 != "includeExcerpts" }.map {
            .init(type: "unsupported", feature: "providerOptions.parallel.\($0)")
        }
        return .init(answers: parsed.answers, usage: parsed.usage, warnings: warnings,
                     providerMetadata: ["parallel": parsed.metadata],
                     response: .init(id: parsed.decisionID, modelID: modelID, headers: response.headers, body: raw))
    }
}

private func parallelOptions(_ options: [String: JSONValue]) throws -> [String: JSONValue] {
    guard let value = options["parallel"], value != .null else { return [:] }
    guard let object = value.objectValue else {
        throw AIError.invalidArgument(argument: "providerOptions.parallel", message: "Parallel options must be an object.")
    }
    if let value = object["includeExcerpts"], value.boolValue == nil {
        throw AIError.invalidArgument(argument: "providerOptions.parallel.includeExcerpts", message: "includeExcerpts must be a boolean.")
    }
    return object
}

private func validateParallelQuestions(_ questions: [String: AIDecisionQuestion], modelID: String, providerID: String) throws {
    guard (1...100).contains(questions.count) else {
        throw AIError.invalidArgument(argument: "questions", message: "Parallel Decisions supports 1 to 100 questions.")
    }
    for (id, question) in questions.sorted(by: { $0.key < $1.key }) {
        guard !id.isEmpty, id.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 95 || $0 == 45 }) else {
            throw AIError.invalidArgument(argument: "questions", message: "Parallel question names may contain only ASCII letters, numbers, underscores, and hyphens.")
        }
        switch question {
        case .box:
            throw AIDecisionUnsupportedQuestionTypeError(questionID: id, questionType: .box, providerID: providerID, modelID: modelID)
        case let .choice(_, criteria) where !(2...255).contains(criteria.count):
            throw AIError.invalidArgument(argument: "questions.\(id).criteria", message: "Parallel Choice questions require 2 to 255 options.")
        case let .score(_, criteria) where !(2...10).contains(criteria.count):
            throw AIError.invalidArgument(argument: "questions.\(id).criteria", message: "Parallel Score questions require 2 to 10 levels.")
        default: break
        }
    }
}

private func parallelState(_ state: [AIDecisionStatePart]) throws -> JSONValue {
    let values: [JSONValue] = try state.map { part in
        switch part {
        case let .text(text): return .string(text)
        case let .json(value): return value
        case .file: throw AIDecisionUnsupportedFunctionalityError(functionality: "Parallel Decisions file input")
        }
    }
    return values.count == 1 ? values[0] : .array(values)
}

private func parallelQuestion(_ question: AIDecisionQuestion) -> JSONValue {
    let instructions: JSONValue? = question.instructions == .null ? nil : question.instructions
    switch question {
    case let .choice(_, criteria): return .object(["type": "choice", "instructions": instructions, "criteria": .object(criteria)])
    case let .score(_, criteria): return .object(["type": "score", "instructions": instructions, "criteria": .array(criteria)])
    case let .boolean(_, criteria): return .object(["type": "noul", "instructions": instructions, "criteria": criteria.map(JSONValue.object)])
    case .box: return .object(["type": "box", "instructions": instructions])
    }
}

private func parallelHTTPError(request: AIHTTPRequest, body: JSONValue, response: AIHTTPResponse,
                               providerID: String, retryable: Bool? = nil) -> AIAPICallError {
    .init(provider: providerID, url: request.url.absoluteString, requestBody: body, statusCode: response.statusCode,
          responseHeaders: response.headers, responseBody: response.bodyText, isRetryable: retryable)
}
