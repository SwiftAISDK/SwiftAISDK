import Foundation
import SwiftAIProvider

func tencentVodRequest(_ request: VideoGenerationRequest, modelName: String, modelVersion: String, subAppId: Double, options: [String: JSONValue], warnings: inout [AIWarning]) throws -> JSONValue {
    let (first, last) = tencentFrames(request, warnings: &warnings)
    var files: [JSONValue] = []
    func fileInfo(_ file: ImageInputFile, category: String, usage: String) -> JSONValue {
        var info: [String: JSONValue] = ["Category": .string(category), "Usage": .string(usage)]
        if let url = file.url { info["Type"] = "Url"; info["Url"] = .string(url) }
        else { info["Type"] = "Base64"; info["Base64"] = .string(file.data?.base64EncodedString() ?? "") }
        if category == "Video", let reference = options["referenceVideoType"] { info["ReferenceType"] = reference }
        return .object(info)
    }
    if let first { files.append(fileInfo(first, category: "Image", usage: "FirstFrame")) }
    if let last { files.append(fileInfo(last, category: "Image", usage: "LastFrame")) }
    for reference in request.inputReferences {
        let kind = tencentMediaKind(reference)
        files.append(fileInfo(reference, category: kind == "video" ? "Video" : kind == "audio" ? "Audio" : "Image", usage: "Reference"))
    }
    for asset in options["assets"]?.arrayValue ?? [] {
        let usage = asset["usage"]?.stringValue ?? "Reference"
        let url = asset["url"]?.stringValue ?? ""
        if usage != "Reference", files.contains(where: { $0["Usage"]?.stringValue == usage }) {
            warnings.append(tencentWarning("providerOptions.tencent.assets", "VOD accepts one \(usage == "FirstFrame" ? "first" : "last") frame; the asset \(url) was ignored.")); continue
        }
        files.append(["Type": "Url", "Url": .string(url), "Category": asset["category"] ?? "Image", "Usage": .string(usage)])
    }
    var output: [String: JSONValue] = ["StorageMode": "Temporary"]
    output["Resolution"] = tencentResolution(request, options, vod: true, warnings: &warnings)
    output["AspectRatio"] = request.aspectRatio.map(JSONValue.string)
    output["Duration"] = request.durationSeconds.map(JSONValue.number)
    output["AudioGeneration"] = request.generateAudio.map { .string($0 ? "Enabled" : "Disabled") }
    output["PersonGeneration"] = options["personGeneration"]
    for (option, key) in [("inputComplianceCheck", "InputComplianceCheck"), ("outputComplianceCheck", "OutputComplianceCheck"), ("enhanceSwitch", "EnhanceSwitch"), ("offPeak", "OffPeak"), ("watermark", "LogoAdd")] {
        output[key] = options[option]?.boolValue.map { .string($0 ? "Enabled" : "Disabled") }
    }
    var body: [String: JSONValue] = ["SubAppId": .number(subAppId), "ModelName": .string(modelName), "ModelVersion": .string(modelVersion), "OutputConfig": .object(output)]
    if !request.prompt.isEmpty { body["Prompt"] = .string(request.prompt) }
    if !files.isEmpty { body["FileInfos"] = .array(files) }
    body["EnhancePrompt"] = options["enhancePrompt"]?.boolValue.map { .string($0 ? "Enabled" : "Disabled") }
    body["Seed"] = request.seed.map { .number(Double($0)) }
    for (option, key) in [("negativePrompt", "NegativePrompt"), ("inputRegion", "InputRegion"), ("sceneType", "SceneType"), ("sessionId", "SessionId"), ("sessionContext", "SessionContext"), ("tasksPriority", "TasksPriority"), ("extInfo", "ExtInfo")] { body[key] = options[option] }
    return .object(body)
}
