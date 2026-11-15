import Foundation
import SwiftAIProvider
import SwiftAITransport

enum TencentWireKind { case string, number, object, array }
func tencentOptional(_ value: JSONValue?, kinds: [TencentWireKind]) -> Bool {
    guard let value, value != .null else { return true }
    return kinds.contains { kind in
        switch (kind, value) {
        case (.string, .string), (.number, .number), (.object, .object), (.array, .array): return true
        default: return false
        }
    }
}
private func fields(_ value: JSONValue?, strings: [String] = [], numbers: [String] = [], objects: [String] = [], arrays: [String] = []) -> Bool {
    guard let value, value != .null else { return true }
    guard value.objectValue != nil else { return false }
    return strings.allSatisfy { tencentOptional(value[$0], kinds: [.string]) }
        && numbers.allSatisfy { tencentOptional(value[$0], kinds: [.number]) }
        && objects.allSatisfy { tencentOptional(value[$0], kinds: [.object]) }
        && arrays.allSatisfy { tencentOptional(value[$0], kinds: [.array]) }
}
func tencentValidateTokenHubStatus(_ raw: JSONValue, response: AIHTTPResponse) throws {
    func fail() -> AIError { tencentCallError(response, message: "Invalid JSON response") }
    guard tencentOptional(raw["data"], kinds: [.array, .object]), fields(raw["tokenhub_usage"], numbers: ["total_tokens"]) else { throw fail() }
    let tasks = raw["data"]?.arrayValue ?? raw["data"].flatMap { $0 == .null ? nil : [$0] } ?? []
    for task in tasks {
        guard task.objectValue != nil, fields(task, strings: ["id", "status", "message"], arrays: ["outputs"]) else { throw fail() }
        for output in task["outputs"]?.arrayValue ?? [] {
            guard output.objectValue != nil, fields(output, strings: ["type", "id", "url"]), tencentOptional(output["duration"], kinds: [.number, .string]) else { throw fail() }
        }
    }
}
func tencentValidateVodStatus(_ raw: JSONValue, response: AIHTTPResponse) throws {
    func fail() -> AIError { tencentCallError(response, message: "Invalid JSON response") }
    guard fields(raw, strings: ["TaskType", "Status", "RequestId"], objects: ["AigcVideoTask"]) else { throw fail() }
    let task = raw["AigcVideoTask"]
    guard fields(task, strings: ["TaskId", "Status", "ErrCodeExt", "Message"], numbers: ["ErrCode", "Progress"], objects: ["Input", "Output"]),
          fields(task?["Input"], objects: ["OutputConfig"]), fields(task?["Input"]?["OutputConfig"], strings: ["Resolution"]),
          fields(task?["Output"], objects: ["Usage"], arrays: ["FileInfos"]) else { throw fail() }
    for file in task?["Output"]?["FileInfos"]?.arrayValue ?? [] {
        guard file.objectValue != nil, fields(file, strings: ["FileUrl", "FileType", "FileId", "UsageType"], objects: ["MetaData"]), fields(file["MetaData"], numbers: ["Duration"]) else { throw fail() }
    }
    let usage = task?["Output"]?["Usage"]
    guard fields(usage, numbers: ["InputTokens", "ThoughtTokens", "InputImageCount", "InputSeconds", "OutputSeconds", "TotalSeconds"], arrays: ["SpecificationUsages"]) else { throw fail() }
    for entry in usage?["SpecificationUsages"]?.arrayValue ?? [] {
        guard entry.objectValue != nil, fields(entry, strings: ["Specification", "Category"]) else { throw fail() }
    }
}

/// Reproduces the published builder's JSON member order for deterministic TC3 payload signatures.
func tencentCloudPayload(_ body: JSONValue) throws -> Data {
    let order = ["SubAppId", "ModelName", "ModelVersion", "Prompt", "NegativePrompt", "EnhancePrompt", "FileInfos", "OutputConfig", "InputRegion", "SceneType", "Seed", "SessionId", "SessionContext", "TasksPriority", "ExtInfo"]
    func encode(_ value: JSONValue, key: String = "") throws -> String {
        switch value {
        case let .object(object):
            let keys: [String]
            switch key {
            case "FileInfos": keys = ["Type", "Url", "Base64", "Category", "Usage", "ReferenceType"]
            case "OutputConfig": keys = ["StorageMode", "Resolution", "AspectRatio", "Duration", "AudioGeneration", "PersonGeneration", "InputComplianceCheck", "OutputComplianceCheck", "EnhanceSwitch", "OffPeak", "LogoAdd"]
            default: keys = object["TaskId"] != nil ? ["TaskId", "SubAppId"] : order
            }
            let sorted = keys.filter { object[$0] != nil } + object.keys.filter { !keys.contains($0) }.sorted()
            return "{" + (try sorted.map { name in try encode(.string(name)) + ":" + encode(object[name]!, key: name) }).joined(separator: ",") + "}"
        case let .array(array): return "[" + (try array.map { try encode($0, key: key) }).joined(separator: ",") + "]"
        default:
            let encoder = JSONEncoder(); encoder.outputFormatting = [.withoutEscapingSlashes]
            return String(decoding: try encoder.encode(value), as: UTF8.self)
        }
    }
    return Data(try encode(body).utf8)
}
