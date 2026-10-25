import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible
public final class MultipartFileClient: AIFileClient, @unchecked Sendable {
    public let providerID: String
    private let providerReferenceKey: String
    private let config: OpenAIModelConfiguration
    private let betaHeader: (String, String)?
    private let includePurpose: Bool
    private let defaultFilename: String
    private let providerOptionsName: String?

    public init(providerID: String, providerReferenceKey: String, config: OpenAIModelConfiguration, betaHeader: (String, String)? = nil, includePurpose: Bool = false, defaultFilename: String = "file", providerOptionsName: String? = nil) {
        self.providerID = providerID
        self.providerReferenceKey = providerReferenceKey
        self.config = config
        self.betaHeader = betaHeader
        self.includePurpose = includePurpose
        self.defaultFilename = defaultFilename
        self.providerOptionsName = providerOptionsName
    }

    public var supportedFileOperations: Set<AIFileOperation> {
        providerReferenceKey == "openai"
            ? [.upload, .getMetadata, .download, .delete]
            : [.upload]
    }

    public func uploadFile(_ request: FileUploadRequest) async throws -> FileUploadResult {
        let options: MultipartFileProviderOptions
        do {
            options = try multipartFileProviderOptions(
                request.providerOptions,
                providerOptionsName: providerOptionsName
            )
            if request.fileData.isStream, providerReferenceKey != "openai" {
                throw unsupportedStreamingFileUpload(providerID: providerID)
            }
        } catch {
            await request.fileData.cancelStream()
            throw error
        }

        let wireFilename = request.filename
            ?? (providerReferenceKey == "openai" ? "blob" : defaultFilename)
        var form = MultipartFormData()
        let appendFields = {
            if self.includePurpose {
                form.appendField(name: "purpose", value: options.purpose ?? request.purpose ?? "assistants")
            }
            if let expiresAfter = options.expiresAfter {
                form.appendField(name: "expires_after[anchor]", value: "created_at")
                form.appendField(
                    name: "expires_after[seconds]",
                    value: jsonScalarString(.number(expiresAfter)) ?? String(expiresAfter)
                )
            }
            for (key, value) in request.extraBody.sorted(by: { $0.key < $1.key }) {
                if let scalar = jsonScalarString(value) {
                    form.appendField(name: key, value: scalar)
                }
            }
        }

        // Native FormData appends the buffered file first. Streaming multipart
        // puts scalar fields first, matching OpenAI's current implementation.
        if request.fileData.isStream {
            appendFields()
            form.appendFile(
                name: "file",
                fileName: wireFilename,
                mimeType: request.mediaType,
                content: request.fileData
            )
        } else {
            form.appendFile(
                name: "file",
                fileName: wireFilename,
                mimeType: request.mediaType,
                content: request.fileData
            )
            appendFields()
        }

        var headers = request.headers
        if let betaHeader {
            headers[betaHeader.0] = headers[betaHeader.0] ?? betaHeader.1
        }
        do {
            let response = try await sendMultipartFileUpload(
                form: form,
                config: config,
                headers: headers,
                abortSignal: request.abortSignal
            )
            guard (200..<300).contains(response.statusCode) else {
                throw apiCallError(provider: providerID, response: response)
            }
            let raw = try response.jsonValue()
            let id: String
            if providerReferenceKey == "openai" {
                id = try managedFileResponseID(raw, providerID: providerID)
            } else {
                id = raw["id"]?.stringValue ?? raw["file"]?["id"]?.stringValue ?? ""
            }
            let providerMetadata = providerReferenceKey == "openai"
                ? managedFileProviderMetadata(from: raw)
                : fileProviderMetadata(from: raw)
            return FileUploadResult(
                providerReference: [providerReferenceKey: id],
                filename: raw["filename"]?.stringValue ?? request.filename,
                mediaType: raw["mime_type"]?.stringValue ?? request.mediaType,
                byteSize: providerReferenceKey == "openai" ? fileInteger(raw["bytes"]) : nil,
                createdAt: providerReferenceKey == "openai" ? fileDate(raw["created_at"]) : nil,
                expiresAt: providerReferenceKey == "openai" ? fileDate(raw["expires_at"]) : nil,
                metadata: fileMetadata(from: raw),
                rawValue: raw,
                warnings: multipartFileUploadWarnings(request, includePurpose: includePurpose),
                providerMetadata: [providerReferenceKey: providerMetadata],
                requestMetadata: multipartFileUploadRequestMetadata(request, includePurpose: includePurpose, defaultFilename: wireFilename, options: options),
                responseMetadata: aiResponseMetadata(from: raw, response: response)
            )
        } catch {
            await request.fileData.cancelStream()
            throw error
        }
    }

    public func getFileMetadata(_ request: FileMetadataRequest) async throws -> FileMetadataResult {
        try requireOpenAIFileManagement()
        return try await managedFileMetadata(
            request,
            providerReferenceKey: providerReferenceKey,
            providerID: providerID,
            config: config
        )
    }

    public func downloadFile(_ request: FileDownloadRequest) async throws -> FileDownloadResult {
        try requireOpenAIFileManagement()
        return try await managedFileDownload(
            request,
            providerReferenceKey: providerReferenceKey,
            providerID: providerID,
            config: config
        )
    }

    public func deleteFile(_ request: FileDeleteRequest) async throws -> FileDeleteResult {
        try requireOpenAIFileManagement()
        return try await managedFileDelete(
            request,
            providerReferenceKey: providerReferenceKey,
            providerID: providerID,
            config: config
        )
    }

    private func requireOpenAIFileManagement() throws {
        guard providerReferenceKey == "openai" else {
            throw AIError.invalidArgument(
                argument: "client",
                message: "The \(providerID) files client only supports file upload."
            )
        }
    }
}
public func sendMultipartFileUpload(
    form: MultipartFormData,
    config: OpenAIModelConfiguration,
    headers requestHeaders: [String: String],
    abortSignal: AIAbortSignal?
) async throws -> AIHTTPResponse {
    var form = form
    let contentType = "multipart/form-data; boundary=\(form.boundary)"
    guard form.containsStream else {
        try abortSignal?.throwIfAborted()
        return try await config.transport.send(config.rawRequest(
            path: "/files",
            modelID: "",
            body: form.finalize(),
            contentType: contentType,
            headers: requestHeaders,
            abortSignal: abortSignal
        ))
    }

    let streamingBody = form.streamingBody()
    do {
        try abortSignal?.throwIfAborted()
        var headers = config.headers.mergingHeaders(requestHeaders)
        headers["content-type"] = headers["content-type"] ?? contentType
        headers["user-agent"] = headers["user-agent"] ?? userAgent(config.providerID)
        let request = AIHTTPRequest(
            method: "POST",
            url: try config.url("", "/files"),
            headers: headers,
            bodyStream: streamingBody.stream,
            cancelBodyStream: { await streamingBody.cancel() },
            abortSignal: abortSignal
        )
        let response = try await config.transport.send(request)
        if !(200..<300).contains(response.statusCode) {
            await streamingBody.cancel()
        }
        return response
    } catch {
        await streamingBody.cancel()
        throw error
    }
}
public func managedFileMetadata(
    _ request: FileMetadataRequest,
    providerReferenceKey: String,
    providerID: String,
    config: OpenAIModelConfiguration
) async throws -> FileMetadataResult {
    let fileID = try managedFileID(
        request.file,
        providerReferenceKey: providerReferenceKey
    )
    try request.abortSignal?.throwIfAborted()
    let url = try config.url("", "/files/\(encodePathSegment(fileID))")
    let headers = managedFileHeaders(config: config, requestHeaders: request.headers)
    let (httpRequest, response) = try await getFromAPI(
        url: url,
        transport: config.transport,
        headers: headers,
        abortSignal: request.abortSignal
    )
    guard (200..<300).contains(response.statusCode) else {
        throw apiCallError(provider: providerID, response: response)
    }
    let raw = try response.jsonValue()
    let responseID = try managedFileResponseID(raw, providerID: providerID)
    return FileMetadataResult(
        providerReference: [providerReferenceKey: responseID],
        filename: raw["filename"]?.stringValue,
        byteSize: fileInteger(raw["bytes"]),
        createdAt: fileDate(raw["created_at"]),
        expiresAt: fileDate(raw["expires_at"]),
        providerMetadata: [providerReferenceKey: managedFileProviderMetadata(from: raw)],
        rawValue: raw,
        requestMetadata: managedFileRequestMetadata(
            request.file,
            headers: httpRequest.headers,
            providerOptions: request.providerOptions
        ),
        responseMetadata: aiResponseMetadata(from: raw, response: response)
    )
}
public func managedFileDownload(
    _ request: FileDownloadRequest,
    providerReferenceKey: String,
    providerID: String,
    config: OpenAIModelConfiguration
) async throws -> FileDownloadResult {
    let fileID = try managedFileID(
        request.file,
        providerReferenceKey: providerReferenceKey
    )
    try request.abortSignal?.throwIfAborted()
    let url = try config.url("", "/files/\(encodePathSegment(fileID))/content")
    let headers = managedFileHeaders(config: config, requestHeaders: request.headers)
    let (httpRequest, response) = try await getBinaryStreamFromAPI(
        url: url,
        transport: config.transport,
        providerID: providerID,
        headers: headers,
        abortSignal: request.abortSignal,
        trustedOrigin: config.baseURL,
        credentialedOrigin: config.baseURL
    )
    let mediaType = response.headerValue("content-type")?
        .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
        .first
        .map(String.init)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return FileDownloadResult(
        content: response.body,
        mediaType: mediaType?.isEmpty == false ? mediaType : nil,
        requestMetadata: managedFileRequestMetadata(
            request.file,
            headers: httpRequest.headers,
            providerOptions: request.providerOptions
        ),
        responseMetadata: AIResponseMetadata(
            timestamp: Date(),
            headers: response.headers
        )
    )
}
public func managedFileDelete(
    _ request: FileDeleteRequest,
    providerReferenceKey: String,
    providerID: String,
    config: OpenAIModelConfiguration
) async throws -> FileDeleteResult {
    let fileID = try managedFileID(
        request.file,
        providerReferenceKey: providerReferenceKey
    )
    try request.abortSignal?.throwIfAborted()
    let url = try config.url("", "/files/\(encodePathSegment(fileID))")
    let headers = managedFileHeaders(config: config, requestHeaders: request.headers)
    let (httpRequest, response) = try await deleteFromAPI(
        url: url,
        transport: config.transport,
        headers: headers,
        abortSignal: request.abortSignal
    )
    guard (200..<300).contains(response.statusCode) else {
        throw apiCallError(provider: providerID, response: response)
    }
    let raw = try response.jsonValue()
    let responseID = try managedFileResponseID(raw, providerID: providerID)
    guard let deleted = raw["deleted"]?.boolValue else {
        throw AIError.invalidResponse(
            provider: providerID,
            message: "File delete response is missing deleted."
        )
    }
    return FileDeleteResult(
        providerReference: [providerReferenceKey: responseID],
        deleted: deleted,
        rawValue: raw,
        requestMetadata: managedFileRequestMetadata(
            request.file,
            headers: httpRequest.headers,
            providerOptions: request.providerOptions
        ),
        responseMetadata: aiResponseMetadata(from: raw, response: response)
    )
}
private func managedFileID(
    _ reference: [String: String],
    providerReferenceKey: String
) throws -> String {
    guard let fileID = reference[providerReferenceKey],
          !fileID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw AIError.invalidArgument(
            argument: "file",
            message: "file reference is missing an '\(providerReferenceKey)' file id."
        )
    }
    return fileID
}
public func managedFileResponseID(_ raw: JSONValue, providerID: String) throws -> String {
    guard let id = raw["id"]?.stringValue else {
        throw AIError.invalidResponse(
            provider: providerID,
            message: "Files response is missing id."
        )
    }
    return id
}
private func managedFileHeaders(
    config: OpenAIModelConfiguration,
    requestHeaders: [String: String]
) -> [String: String] {
    var headers = config.headers.mergingHeaders(requestHeaders)
    headers["user-agent"] = headers["user-agent"] ?? userAgent(config.providerID)
    return headers
}
private func managedFileRequestMetadata(
    _ file: [String: String],
    headers: [String: String],
    providerOptions: [String: JSONValue]
) -> AIRequestMetadata {
    AIRequestMetadata(body: .object([
        "file": .object(file.mapValues(JSONValue.string)),
        "providerOptions": providerOptions.isEmpty ? nil : .object(providerOptions)
    ]), headers: headers)
}
public func managedFileProviderMetadata(from raw: JSONValue) -> JSONValue {
    .object([
        "filename": raw["filename"],
        "purpose": raw["purpose"],
        "bytes": raw["bytes"],
        "createdAt": raw["created_at"],
        "status": raw["status"],
        "expiresAt": raw["expires_at"]
    ].compactMapValues { value in
        guard let value, value != .null else { return nil }
        return value
    })
}
