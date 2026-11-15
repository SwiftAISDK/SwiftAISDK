@testable import SwiftAIProdia
@testable import SwiftAIProvider
@testable import SwiftAITransport
import Foundation

/// Builds the multipart bodies used by upstream Prodia tests
/// (`createMultipartResponse`, `createLanguageMultipartResponse`): every part
/// carries a `filename`, and the body ends with `\r\n--boundary--\r\n`.
func prodiaUpstreamMultipartResponse(
    _ parts: [(name: String, fileName: String, contentType: String, body: Data)],
    boundary: String = "test-boundary-12345"
) -> AIHTTPResponse {
    var body = Data()
    for part in parts {
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(part.name)\"; filename=\"\(part.fileName)\"\r\n".utf8))
        body.append(Data("Content-Type: \(part.contentType)\r\n".utf8))
        body.append(Data("\r\n".utf8))
        body.append(part.body)
        body.append(Data("\r\n".utf8))
    }
    body.append(Data("--\(boundary)--\r\n".utf8))
    return AIHTTPResponse(
        statusCode: 200,
        headers: ["content-type": "multipart/form-data; boundary=\(boundary)"],
        body: body
    )
}

func prodiaUpstreamJobPart(_ json: String) -> (name: String, fileName: String, contentType: String, body: Data) {
    (name: "job", fileName: "job.json", contentType: "application/json", body: Data(json.utf8))
}

func prodiaHeader(_ request: AIHTTPRequest, _ name: String) -> String? {
    request.headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
}

/// Parses a multipart request body the way the upstream tests inspect
/// captured `FormData`.
func prodiaRequestFormParts(_ request: AIHTTPRequest) throws -> [MultipartResponsePart] {
    try parseMultipartResponse(AIHTTPResponse(
        statusCode: 200,
        headers: ["content-type": prodiaHeader(request, "content-type") ?? ""],
        body: request.body ?? Data()
    ))
}
