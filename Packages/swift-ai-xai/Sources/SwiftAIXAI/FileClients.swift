import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAI
import SwiftAIOpenAICompatible

public final class XAIFileClient: AIFileClient, @unchecked Sendable {
    public let providerID = "xai.files"
    private let config: XAIModelConfiguration

    public init(config: XAIModelConfiguration) {
        self.config = config
    }

    public let supportedFileOperations: Set<AIFileOperation> = [
        .upload, .getMetadata, .download, .delete
    ]

    public func uploadFile(_ request: FileUploadRequest) async throws -> FileUploadResult {
        let options: [String: JSONValue]
        do {
            options = try xaiFileOptions(
                providerOptions: request.providerOptions,
                extraBody: request.extraBody
            )
        } catch {
            await request.fileData.cancelStream()
            throw error
        }

        var form = MultipartFormData()
        if let expiresAfter = options["expiresAfter"]?.intValue {
            form.appendField(name: "expires_after", value: String(expiresAfter))
        }
        if let teamID = options["teamId"]?.stringValue ?? options["team_id"]?.stringValue {
            form.appendField(name: "team_id", value: teamID)
        }
        form.appendFile(
            name: "file",
            fileName: request.filename ?? "blob",
            mimeType: request.mediaType,
            content: request.fileData
        )

        do {
            let response = try await sendMultipartFileUpload(
                form: form,
                config: config.openAIConfiguration,
                headers: request.headers,
                abortSignal: request.abortSignal
            )
            guard (200..<300).contains(response.statusCode) else {
                throw apiCallError(provider: providerID, response: response)
            }
            let raw = try response.jsonValue()
            let id = try managedFileResponseID(raw, providerID: providerID)
            let metadata = managedFileProviderMetadata(from: raw)
            return FileUploadResult(
                providerReference: ["xai": id],
                filename: raw["filename"]?.stringValue ?? request.filename,
                mediaType: request.mediaType,
                byteSize: fileInteger(raw["bytes"]),
                createdAt: fileDate(raw["created_at"]),
                expiresAt: fileDate(raw["expires_at"]),
                metadata: ["xai": metadata],
                rawValue: raw,
                warnings: xaiFileUploadWarnings(request),
                providerMetadata: ["xai": metadata],
                requestMetadata: xaiFileUploadRequestMetadata(request, options: options),
                responseMetadata: aiResponseMetadata(from: raw, response: response)
            )
        } catch {
            await request.fileData.cancelStream()
            throw error
        }
    }

    public func getFileMetadata(_ request: FileMetadataRequest) async throws -> FileMetadataResult {
        try await managedFileMetadata(
            request,
            providerReferenceKey: "xai",
            providerID: providerID,
            config: config.openAIConfiguration
        )
    }

    public func downloadFile(_ request: FileDownloadRequest) async throws -> FileDownloadResult {
        try await managedFileDownload(
            request,
            providerReferenceKey: "xai",
            providerID: providerID,
            config: config.openAIConfiguration
        )
    }

    public func deleteFile(_ request: FileDeleteRequest) async throws -> FileDeleteResult {
        try await managedFileDelete(
            request,
            providerReferenceKey: "xai",
            providerID: providerID,
            config: config.openAIConfiguration
        )
    }
}

private func xaiFileOptions(providerOptions: [String: JSONValue], extraBody: [String: JSONValue]) throws -> [String: JSONValue] {
    var output = extraBody
    if let nested = output.removeValue(forKey: "xai")?.objectValue {
        output.merge(nested) { _, nested in nested }
    }
    if let value = providerOptions["xai"] {
        if value != .null {
            guard let nested = value.objectValue else {
                throw AIError.invalidArgument(argument: "providerOptions.xai", message: "xAI file provider options must be an object.")
            }
            output.merge(nested) { _, nested in nested }
        }
    }
    return try xaiValidateFileProviderOptions(output)
}

private func xaiValidateFileProviderOptions(_ options: [String: JSONValue]) throws -> [String: JSONValue] {
    for key in ["teamId", "filePath"] {
        guard let value = options[key] else { continue }
        guard value.stringValue != nil else {
            throw AIError.invalidArgument(argument: "providerOptions.xai.\(key)", message: "xAI \(key) must be a string.")
        }
    }
    if let value = options["expiresAfter"] {
        guard let number = value.doubleValue,
              number.isFinite,
              let seconds = Int(exactly: number),
              (3_600...2_592_000).contains(seconds) else {
            throw AIError.invalidArgument(
                argument: "providerOptions.xai.expiresAfter",
                message: "xAI expiresAfter must be an integer between 3600 and 2592000."
            )
        }
    }
    return options
}

private func xaiFileUploadRequestMetadata(_ request: FileUploadRequest, options: [String: JSONValue]) -> AIRequestMetadata {
    var body: [String: JSONValue] = [
        "file": .object(fileUploadMetadata(request, defaultFilename: "blob")),
        "mediaType": .string(request.mediaType)
    ]
    if let teamID = options["teamId"]?.stringValue ?? options["team_id"]?.stringValue {
        body["teamId"] = .string(teamID)
    }
    if let expiresAfter = options["expiresAfter"]?.doubleValue {
        body["expiresAfter"] = .number(expiresAfter)
    }
    return AIRequestMetadata(body: .object(body), headers: request.headers)
}

private func xaiFileUploadWarnings(_ request: FileUploadRequest) -> [AIWarning] {
    var warnings: [AIWarning] = []
    if request.displayName != nil {
        warnings.append(AIWarning(type: "unsupported", feature: "displayName"))
    }
    if request.purpose != nil {
        warnings.append(AIWarning(type: "unsupported", feature: "purpose"))
    }
    return warnings
}

private func headerValue(_ headers: [String: String], _ name: String) -> String? {
    headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
}