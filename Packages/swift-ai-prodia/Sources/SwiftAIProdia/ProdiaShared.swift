import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities


struct ProdiaLanguageGeneration {
    var result: TextGenerationResult
    var files: [AIStreamFile]
}

func prodiaHTTPStatusError(provider: String, response: AIHTTPResponse) -> AIError {
    let body = prodiaErrorMessage(from: response.body) ?? response.bodyText
    guard !response.headers.isEmpty else {
        return .apiCall(provider: provider, statusCode: response.statusCode, body: body)
    }
    return .apiCall(provider: provider, statusCode: response.statusCode, body: body, headers: response.headers)
}

func prodiaErrorMessage(from data: Data) -> String? {
    guard let json = try? decodeJSONBody(data) else { return nil }
    if let detail = json["detail"] {
        if let message = detail.stringValue {
            return message
        }
        if let encoded = try? encodeJSONBody(detail),
           let text = String(data: encoded, encoding: .utf8) {
            return text
        }
    }
    return json["error"]?.stringValue ?? json["message"]?.stringValue ?? "Unknown Prodia error"
}

/// Parses and validates the multipart `job` part like upstream
/// `parseJSON({ schema: prodiaJobResultSchema() })`; a later job part wins.
func prodiaValidatedJobResult(from parts: [MultipartResponsePart], provider: String) throws -> JSONValue {
    var jobResult: JSONValue?
    for part in parts where part.name == "job" {
        let value = try secureJSONParse(String(decoding: part.body, as: UTF8.self))
        try prodiaValidateJobResultSchema(value)
        jobResult = value
    }
    guard let jobResult else {
        throw AIError.invalidResponse(provider: provider, message: "Prodia multipart response missing job part")
    }
    return jobResult
}

/// Mirrors upstream `prodiaJobResultSchema`.
func prodiaValidateJobResultSchema(_ value: JSONValue) throws {
    func fail(_ path: String, _ message: String) -> AITypeValidationError {
        AITypeValidationError(value: value, path: path, message: message)
    }
    func requireObject(_ field: JSONValue?, _ path: String, optional: Bool, nullable: Bool = false) throws -> [String: JSONValue]? {
        guard let field else {
            if optional { return nil }
            throw fail(path, "Invalid input: expected object, received undefined")
        }
        if field == .null, nullable { return nil }
        guard let object = field.objectValue else {
            throw fail(path, "Invalid input: expected object")
        }
        return object
    }
    func requireString(_ field: JSONValue?, _ path: String, optional: Bool) throws {
        guard let field else {
            if optional { return }
            throw fail(path, "Invalid input: expected string, received undefined")
        }
        guard field.stringValue != nil else {
            throw fail(path, "Invalid input: expected string")
        }
    }
    func requireNumber(_ field: JSONValue?, _ path: String, optional: Bool) throws {
        guard let field else {
            if optional { return }
            throw fail(path, "Invalid input: expected number, received undefined")
        }
        guard case .number = field else {
            throw fail(path, "Invalid input: expected number")
        }
    }

    guard let root = try requireObject(value, "", optional: false) else { return }
    try requireString(root["id"], "id", optional: false)
    try requireString(root["created_at"], "created_at", optional: true)
    try requireString(root["updated_at"], "updated_at", optional: true)
    try requireString(root["expires_at"], "expires_at", optional: true)
    if let state = try requireObject(root["state"], "state", optional: true) {
        try requireString(state["current"], "state.current", optional: false)
    }
    if let config = try requireObject(root["config"], "config", optional: true) {
        try requireNumber(config["seed"], "config.seed", optional: true)
    }
    if let metrics = try requireObject(root["metrics"], "metrics", optional: true) {
        try requireNumber(metrics["elapsed"], "metrics.elapsed", optional: true)
        try requireNumber(metrics["ips"], "metrics.ips", optional: true)
    }
    if let price = try requireObject(root["price"], "price", optional: true, nullable: true) {
        try requireString(price["product"], "price.product", optional: false)
        try requireNumber(price["dollars"], "price.dollars", optional: false)
    }
}

func prodiaProviderMetadata(from jobResult: JSONValue?) -> JSONValue {
    guard let jobResult else { return .object([:]) }
    var metadata: [String: JSONValue] = [:]
    if let jobID = jobResult["id"]?.stringValue {
        metadata["jobId"] = .string(jobID)
    }
    if let seed = jobResult["config"]?["seed"] {
        metadata["seed"] = seed
    }
    if let elapsed = jobResult["metrics"]?["elapsed"] {
        metadata["elapsed"] = elapsed
    }
    if let ips = jobResult["metrics"]?["ips"] {
        metadata["iterationsPerSecond"] = ips
    }
    if let createdAt = jobResult["created_at"]?.stringValue {
        metadata["createdAt"] = .string(createdAt)
    }
    if let updatedAt = jobResult["updated_at"]?.stringValue {
        metadata["updatedAt"] = .string(updatedAt)
    }
    if let dollars = jobResult["price"]?["dollars"] {
        metadata["dollars"] = dollars
    }
    return .object(metadata)
}

/// Mirrors upstream `createLanguageMultipartResponseHandler`: only `output`
/// parts contribute; text (`text/*` or a `.txt` disposition) keeps the last
/// value, and `image/*` parts become files in order.
func prodiaLanguageOutput(from parts: [MultipartResponsePart]) -> (text: String?, files: [AIStreamFile]) {
    var text: String?
    var files: [AIStreamFile] = []
    for part in parts where part.name == "output" {
        let contentType = part.contentType ?? ""
        if contentType.hasPrefix("text/") || part.fileName?.contains(".txt") == true {
            text = String(decoding: part.body, as: UTF8.self)
        } else if contentType.hasPrefix("image/") {
            files.append(AIStreamFile(
                mediaType: contentType,
                data: part.body,
                filename: part.fileName,
                rawValue: .object([
                    "name": part.name.map(JSONValue.string),
                    "fileName": part.fileName.map(JSONValue.string),
                    "contentType": .string(contentType),
                    "base64": .string(part.body.base64EncodedString())
                ])
            ))
        }
    }
    return (text, files)
}
