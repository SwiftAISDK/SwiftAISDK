import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

/// Native V4 operation-based TokenHub Kling and Tencent Cloud VOD video model.
public final class TencentVideoModel: AsyncVideoModel, Sendable {
    public let providerID = "tencent.video"
    public let modelID: String
    public let maxVideosPerCall = 1
    private let settings: TencentProviderSettings
    private let backend: Backend
    private enum Backend: Sendable { case tokenHub(String); case vod(String, String) }

    public init(modelID: String, configuration: TencentProviderSettings = .init()) throws {
        self.modelID = modelID; self.settings = configuration
        if modelID.hasPrefix("vod/") {
            let rest = String(modelID.dropFirst(4))
            guard let separator = rest.firstIndex(of: "/"), separator != rest.startIndex, rest.index(after: separator) != rest.endIndex else {
                throw AIError.unsupportedModel(provider: "tencent", capability: .video, modelID: modelID)
            }
            backend = .vod(String(rest[..<separator]), String(rest[rest.index(after: separator)...]))
        } else if modelID.hasPrefix("kling-video-motion-control-") { backend = .tokenHub("motion-control") }
        else if modelID.hasPrefix("kling-video-") { backend = .tokenHub(modelID.hasSuffix("-omni") ? "omni" : "standard") }
        else { throw AIError.unsupportedModel(provider: "tencent", capability: .video, modelID: modelID) }
    }

    public func startVideoGeneration(_ operationRequest: VideoGenerationOperationStartRequest) async throws -> VideoGenerationOperationStartResult {
        let date = settings.currentDate()
        let request = operationRequest.request
        try request.abortSignal?.throwIfAborted()
        let options = try tencentOptions(request)
        var warnings: [AIWarning] = []
        if request.fps != nil { warnings.append(tencentWarning("fps", "Tencent video models do not support custom FPS.")) }
        if let count = request.count, count > 1 { warnings.append(tencentWarning("n", "Tencent video models generate one video per call. Only 1 video will be generated.")) }
        let vod: Bool
        if case .vod = backend { vod = true } else { vod = false }
        if !vod, request.seed != nil { warnings.append(tencentWarning("seed", "TokenHub Kling models do not support a seed.")) }
        if operationRequest.webhookURL != nil { warnings.append(tencentWarning("webhookUrl", "Tencent video tasks do not accept a per-request callback URL; the result is retrieved by polling.")) }
        let ignoredKeys = vod ? tencentTokenHubOnly : tencentVodOnly
        let ignoredMessage = vod ? "This option only applies to TokenHub Kling models; it was ignored." : "This option only applies to VOD models; it was ignored."
        for key in ignoredKeys where options[key] != nil { warnings.append(tencentWarning("providerOptions.tencent.\(key)", ignoredMessage)) }
        let raw: JSONValue
        let response: AIHTTPResponse
        let taskID: String
        switch backend {
        case let .tokenHub(kind):
            let prepared = try tencentTokenHubRequest(request, modelID: modelID, kind: kind, options: options, warnings: &warnings)
            (raw, response) = try await tokenHub(path: "/wand/kling/\(prepared.endpoint)", body: prepared.body, headers: request.headers, abortSignal: request.abortSignal)
            guard let id = raw["data"]?["id"]?.stringValue, !id.isEmpty else { throw AIError.invalidResponse(provider: providerID, message: "No task ID returned from TokenHub.") }
            taskID = id
        case let .vod(name, version):
            let credentials = try tencentVodCredentials(settings)
            let body = try tencentVodRequest(request, modelName: name, modelVersion: version, subAppId: credentials.subAppId, options: options, warnings: &warnings)
            (raw, response) = try await tencentPostCloud(settings: settings, action: "CreateAigcVideoTask", body: body, headers: request.headers, abortSignal: request.abortSignal, date: date)
            guard let id = raw["TaskId"]?.stringValue else { throw tencentCallError(response, message: "Invalid JSON response") }
            taskID = id
        }
        return VideoGenerationOperationStartResult(operation: ["taskId": .string(taskID)], warnings: warnings,
            responseMetadata: metadata(response, date: date))
    }

    public func videoGenerationStatus(_ request: VideoGenerationOperationStatusRequest) async throws -> VideoGenerationOperationStatusResult {
        let date = settings.currentDate()
        guard let taskID = request.operation["taskId"]?.stringValue else { throw AIError.invalidArgument(argument: "operation", message: "Tencent video operation must contain taskId.") }
        try request.abortSignal?.throwIfAborted()
        switch backend {
        case .tokenHub:
            let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
            let segment = taskID.addingPercentEncoding(withAllowedCharacters: allowed) ?? taskID
            let (raw, response) = try await tokenHub(path: "/wand/kling/tasks/\(segment)", body: nil, headers: request.headers, abortSignal: request.abortSignal)
            try tencentValidateTokenHubStatus(raw, response: response)
            return tokenHubStatus(raw, taskID: taskID, response: response, date: date)
        case .vod:
            let credentials = try tencentVodCredentials(settings)
            let (raw, response) = try await tencentPostCloud(settings: settings, action: "DescribeTaskDetail", body: ["TaskId": .string(taskID), "SubAppId": .number(credentials.subAppId)], headers: request.headers, abortSignal: request.abortSignal, date: date)
            try tencentValidateVodStatus(raw, response: response)
            return vodStatus(raw, taskID: taskID, response: response, date: date)
        }
    }

    public func generateVideo(_ request: VideoGenerationRequest) async throws -> VideoGenerationResult {
        let started = try await startVideoGeneration(.init(request: request))
        let start = DispatchTime.now().uptimeNanoseconds
        while true {
            switch try await videoGenerationStatus(.init(operation: started.operation, headers: request.headers, abortSignal: request.abortSignal)) {
            case .pending:
                if DispatchTime.now().uptimeNanoseconds - start >= 600_000_000_000 { throw VideoGenerationOperationError.timedOut(milliseconds: 600_000) }
                try await sleepWithAbortSignal(nanoseconds: 5_000_000_000, abortSignal: request.abortSignal)
            case var .completed(result): result.warnings = started.warnings + result.warnings; return result
            case let .failed(message, _, _): throw VideoGenerationOperationError.providerFailed(message)
            }
        }
    }
    private func metadata(_ response: AIHTTPResponse, date: Date) -> AIResponseMetadata { AIResponseMetadata(timestamp: date, modelID: modelID, headers: response.headers) }
    private func tokenHub(path: String, body: JSONValue?, headers: [String: String], abortSignal: AIAbortSignal?) async throws -> (JSONValue, AIHTTPResponse) {
        let client = tencentTokenHubClient(settings, providerID: providerID)
        let request: AIHTTPRequest
        let response: AIHTTPResponse
        if let body {
            request = try client.request(path: path, modelID: modelID, body: body, headers: headers, abortSignal: abortSignal)
            response = try await client.transport.send(request)
        } else {
            let baseURL = withoutTrailingSlash(settings.baseURL ?? tencentTokenHubBaseURL)
            let url = "\(baseURL)\(path)"
            request = AIHTTPRequest(method: "GET", url: try requireURL(url), headers: try await client.resolvedHeaders(headers), abortSignal: abortSignal)
            response = try await downloadURL(url, transport: settings.transport, headers: request.headers,
                abortSignal: abortSignal, trustedOrigin: baseURL, credentialedOrigin: baseURL)
        }
        let raw = try? response.jsonValue()
        guard (200..<300).contains(response.statusCode) else {
            throw tencentCallError(response, message: raw?["error"]?["message"]?.stringValue ?? raw?["message"]?.stringValue ?? response.bodyText, request: request)
        }
        guard let raw, raw.objectValue != nil,
              tencentOptional(raw["code"], kinds: [.string, .number]), tencentOptional(raw["message"], kinds: [.string]), tencentOptional(raw["request_id"], kinds: [.string]) else {
            throw tencentCallError(response, message: "Invalid JSON response", request: request)
        }
        if let code = raw["code"], code != .null, code != .number(0), code != .string("0") {
            throw tencentCallError(response, message: raw["message"]?.stringValue ?? "TokenHub request failed with code \(code.stringValue ?? code.doubleValue.map { String($0) } ?? "")", request: request, retryable: false)
        }
        if body != nil {
            guard tencentOptional(raw["data"], kinds: [.object]), tencentOptional(raw["data"]?["id"], kinds: [.string]), tencentOptional(raw["data"]?["status"], kinds: [.string]) else { throw tencentCallError(response, message: "Invalid JSON response", request: request) }
        }
        return (raw, response)
    }
    private func tokenHubStatus(_ raw: JSONValue, taskID: String, response: AIHTTPResponse, date: Date) -> VideoGenerationOperationStatusResult {
        let tasks = raw["data"]?.arrayValue
        let task = tasks?.first { $0["id"]?.stringValue == taskID } ?? tasks?.first ?? raw["data"]
        guard task?["status"]?.stringValue == "succeeded" else {
            if task?["status"]?.stringValue == "failed" {
                let message = task?["message"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 } ?? "unknown error"
                return .failed(message: "Video generation failed: \(message) (task \(taskID))", responseMetadata: metadata(response, date: date))
            }
            return .pending(responseMetadata: metadata(response, date: date))
        }
        let outputs = (task?["outputs"]?.arrayValue ?? []).filter { $0["url"]?.stringValue != nil && ($0["type"]?.stringValue ?? "video") == "video" }
        guard !outputs.isEmpty else { return .failed(message: "TokenHub Kling task \(taskID) succeeded without a video URL.", responseMetadata: metadata(response, date: date)) }
        let videos: [JSONValue] = outputs.map { output in
            var video: [String: JSONValue] = ["url": output["url"]!]
            if let id = output["id"], id != .null { video["id"] = id }
            let duration = output["duration"]?.doubleValue ?? output["duration"]?.stringValue.flatMap(Double.init)
            if let duration, duration.isFinite { video["duration"] = .number(duration) }
            return .object(video)
        }
        var provider: [String: JSONValue] = ["taskId": .string(taskID), "videos": .array(videos)]
        if let id = raw["request_id"], id != .null { provider["requestId"] = id }
        if let count = raw["tokenhub_usage"]?["total_tokens"], count != .null { provider["usage"] = ["totalTokens": count] }
        var result = VideoGenerationResult(urls: outputs.compactMap { $0["url"]?.stringValue }, operationID: taskID, mediaType: "video/mp4", rawValue: raw,
            providerMetadata: ["tencent": .object(provider)], responseMetadata: metadata(response, date: date))
        result.videoURLDescriptors = outputs.compactMap { output in output["url"]?.stringValue.map { VideoURLDescriptor(url: $0, mediaType: "video/mp4") } }
        return .completed(result)
    }
    private func vodStatus(_ raw: JSONValue, taskID: String, response: AIHTTPResponse, date: Date) -> VideoGenerationOperationStatusResult {
        if raw["Status"]?.stringValue == "ABORTED" { return .failed(message: "Video generation aborted (task \(taskID))", responseMetadata: metadata(response, date: date)) }
        guard raw["Status"]?.stringValue == "FINISH" else { return .pending(responseMetadata: metadata(response, date: date)) }
        let task = raw["AigcVideoTask"]
        if let error = task?["ErrCode"]?.doubleValue, error != 0 {
            let code = task?["ErrCodeExt"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 } ?? (error.rounded() == error ? String(Int(error)) : String(error))
            let message = task?["Message"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 } ?? "unknown error"
            return .failed(message: "Video generation failed (\(code)): \(message) (task \(taskID))", responseMetadata: metadata(response, date: date))
        }
        let allFiles = (task?["Output"]?["FileInfos"]?.arrayValue ?? []).filter { !($0["FileUrl"]?.stringValue ?? "").isEmpty }
        let files = allFiles.filter { $0["UsageType"]?.stringValue != "last_frame_url" }
        guard !files.isEmpty else { return .failed(message: "VOD task \(taskID) finished without a video URL.", responseMetadata: metadata(response, date: date)) }
        let usage = task?["Output"]?["Usage"]
        var provider: [String: JSONValue] = ["taskId": .string(taskID)]
        provider["requestId"] = raw["RequestId"].flatMap { $0 == .null ? nil : $0 }
        if let resolution = task?["Input"]?["OutputConfig"]?["Resolution"]?.stringValue, !resolution.isEmpty { provider["resolution"] = .string(resolution) }
        if let last = allFiles.first(where: { $0["UsageType"]?.stringValue == "last_frame_url" })?["FileUrl"] { provider["lastFrameUrl"] = last }
        provider["videos"] = .array(files.map { file in
            var entry: [String: JSONValue] = ["url": file["FileUrl"]!]
            if let id = file["FileId"]?.stringValue, !id.isEmpty { entry["fileId"] = .string(id) }
            entry["duration"] = (file["MetaData"]?["Duration"]?.doubleValue ?? usage?["OutputSeconds"]?.doubleValue).map(JSONValue.number)
            return .object(entry)
        })
        if let usage, usage != .null {
            var parsed: [String: JSONValue] = [:]
            for (key, name) in [("InputImageCount", "inputImageCount"), ("InputSeconds", "inputSeconds"), ("InputTokens", "inputTokens"), ("OutputSeconds", "outputSeconds"), ("ThoughtTokens", "thoughtTokens"), ("TotalSeconds", "totalSeconds")] {
                if let value = usage[key], value != .null { parsed[name] = value }
            }
            let specifications: [JSONValue] = (usage["SpecificationUsages"]?.arrayValue ?? []).compactMap { entry in
                var result: [String: JSONValue] = [:]
                if let specification = entry["Specification"]?.stringValue, !specification.isEmpty { result["specification"] = .string(specification) }
                if let category = entry["Category"]?.stringValue, !category.isEmpty { result["category"] = .string(category) }
                return result.isEmpty ? nil : .object(result)
            }
            if !specifications.isEmpty { parsed["specificationUsages"] = .array(specifications) }
            provider["usage"] = .object(parsed)
        }
        let type = files.first?["FileType"]?.stringValue?.lowercased() ?? ""
        var result = VideoGenerationResult(urls: files.compactMap { $0["FileUrl"]?.stringValue }, operationID: taskID,
            mediaType: ["mov": "video/quicktime", "mp4": "video/mp4", "webm": "video/webm"][type] ?? "video/mp4", rawValue: raw,
            providerMetadata: ["tencent": .object(provider)], responseMetadata: metadata(response, date: date))
        result.videoURLDescriptors = files.compactMap { file in
            guard let url = file["FileUrl"]?.stringValue else { return nil }
            let type = file["FileType"]?.stringValue?.lowercased() ?? ""
            return VideoURLDescriptor(url: url, mediaType: ["mov": "video/quicktime", "mp4": "video/mp4", "webm": "video/webm"][type] ?? "video/mp4")
        }
        return .completed(result)
    }
}
