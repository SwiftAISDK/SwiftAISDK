import Foundation
import SwiftAIProvider
import SwiftAITransport

/// Pass `providerOptions` to a video's `VideoGenerationRequest`.
public struct TencentVideoModelOptions: Codable, Sendable {
    public struct Element: Codable, Sendable {
        public var elementId: String; public var id: String?
        public init(elementId: String, id: String? = nil) { self.elementId = elementId; self.id = id }
    }
    public struct Voice: Codable, Sendable {
        public var voiceId: String; public var id: String
        public init(voiceId: String, id: String) { self.voiceId = voiceId; self.id = id }
    }
    public struct Asset: Codable, Sendable {
        public var url: String; public var usage: String?; public var category: String?
        public init(url: String, usage: String? = nil, category: String? = nil) { self.url = url; self.usage = usage; self.category = category }
    }
    public var resolution: String?
    public var audio: String?
    public var multiShot: Bool?
    public var characterOrientation: String?
    public var elements: [Element]?
    public var voices: [Voice]?
    public var referenceVideoType: String?
    public var watermark: Bool?
    public var externalTaskId: String?
    public var negativePrompt: String?
    public var enhancePrompt: Bool?
    public var inputRegion: String?
    public var sceneType: String?
    public var personGeneration: String?
    public var inputComplianceCheck: Bool?
    public var outputComplianceCheck: Bool?
    public var enhanceSwitch: Bool?
    public var offPeak: Bool?
    public var sessionId: String?
    public var sessionContext: String?
    public var tasksPriority: Int?
    public var extInfo: String?
    public var assets: [Asset]?
    public init() {}
    public var providerOptions: [String: JSONValue] {
        get throws { ["tencent": try decodeJSONBody(JSONEncoder().encode(self))] }
    }
}

let tencentTokenHubOnly = ["audio", "multiShot", "characterOrientation", "elements", "voices", "externalTaskId"]
let tencentVodOnly = ["negativePrompt", "enhancePrompt", "inputRegion", "sceneType", "personGeneration", "inputComplianceCheck", "outputComplianceCheck", "enhanceSwitch", "offPeak", "sessionId", "sessionContext", "tasksPriority", "extInfo", "assets"]
func tencentOptions(_ request: VideoGenerationRequest) throws -> [String: JSONValue] {
    guard let raw = request.providerOptions["tencent"] else { return [:] }
    guard let options = raw.objectValue else { throw AIError.invalidArgument(argument: "providerOptions.tencent", message: "Tencent options must be an object.") }
    let strings = Set(["resolution", "externalTaskId", "negativePrompt", "sceneType", "sessionId", "sessionContext", "extInfo"])
    let bools = Set(["multiShot", "watermark", "enhancePrompt", "inputComplianceCheck", "outputComplianceCheck", "enhanceSwitch", "offPeak"])
    let enums: [String: [String]] = ["audio": ["native", "original", "off"], "characterOrientation": ["image", "video"], "referenceVideoType": ["feature", "base"], "inputRegion": ["Oversea", "OverseaUSWest", "Mainland"], "personGeneration": ["AllowAdult", "Disallowed"]]
    var validated: [String: JSONValue] = [:]
    func fail(_ key: String) -> AIError { .invalidArgument(argument: "providerOptions.tencent.\(key)", message: "Invalid Tencent provider option.") }
    for (key, value) in options {
        if strings.contains(key) { guard value.stringValue != nil else { throw fail(key) }; validated[key] = value }
        else if bools.contains(key) { guard value.boolValue != nil else { throw fail(key) }; validated[key] = value }
        else if let cases = enums[key] { guard let string = value.stringValue, cases.contains(string) else { throw fail(key) }; validated[key] = value }
        else if key == "tasksPriority" { guard let n = value.doubleValue, n.isFinite, n.rounded() == n, (-10...10).contains(n) else { throw fail(key) }; validated[key] = value }
        else if ["elements", "voices", "assets"].contains(key) {
            guard let array = value.arrayValue else { throw fail(key) }
            var items: [JSONValue] = []
            for item in array {
                guard let object = item.objectValue else { throw fail(key) }
                let required = key == "elements" ? ["elementId"] : key == "voices" ? ["voiceId", "id"] : ["url"]
                for field in required { guard object[field]?.stringValue != nil else { throw fail(key) } }
                var fields = Dictionary(uniqueKeysWithValues: required.map { ($0, object[$0]!) })
                let optional = key == "elements" ? ["id"] : key == "assets" ? ["usage", "category"] : []
                for field in optional where object[field] != nil {
                    guard let text = object[field]?.stringValue else { throw fail(key) }
                    if field == "usage", !["FirstFrame", "LastFrame", "Reference"].contains(text) { throw fail(key) }
                    if field == "category", !["Image", "Video", "Audio"].contains(text) { throw fail(key) }
                    fields[field] = .string(text)
                }
                items.append(.object(fields))
            }
            validated[key] = .array(items)
        }
    }
    return validated
}
func tencentWarning(_ feature: String, _ message: String) -> AIWarning { AIWarning(type: "unsupported", feature: feature, message: message) }
func tencentResolution(_ request: VideoGenerationRequest, _ options: [String: JSONValue], vod: Bool, warnings: inout [AIWarning]) -> JSONValue? {
    if let resolution = options["resolution"] { return resolution }
    guard let resolution = request.resolution else { return nil }
    let sides = resolution.split(separator: "x").compactMap { Int($0) }
    let tiers = vod ? [480: "480P", 720: "720P", 1080: "1080P", 1440: "2K", 2160: "4K"] : [720: "720p", 1080: "1080p", 2160: "4k"]
    if sides.count == 2, let value = tiers[sides.min()!] { return .string(value) }
    warnings.append(tencentWarning("resolution", "Resolution \(resolution) does not map to a supported tier (\(tiers.keys.sorted().compactMap { tiers[$0] }.joined(separator: ", "))); the default resolution was used."))
    return nil
}
func tencentMediaKind(_ file: ImageInputFile) -> String { file.mediaType?.split(separator: "/").first.map(String.init) ?? "image" }
func tencentFrame(_ file: ImageInputFile?, warnings: inout [AIWarning]) -> ImageInputFile? {
    guard let file else { return nil }
    guard !["audio", "video"].contains(tencentMediaKind(file)) else {
        warnings.append(tencentWarning("frameImages", "Frame images must be images; the frame was ignored.")); return nil
    }
    return file
}
func tencentFrames(_ request: VideoGenerationRequest, warnings: inout [AIWarning]) -> (ImageInputFile?, ImageInputFile?) {
    let first = tencentFrame(request.frameImages.first { $0.frameType == .firstFrame }?.image ?? request.image, warnings: &warnings)
    let last = tencentFrame(request.frameImages.first { $0.frameType == .lastFrame }?.image, warnings: &warnings)
    return (first, last)
}
