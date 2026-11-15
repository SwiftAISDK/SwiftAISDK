import Foundation
import SwiftAIProvider

func tencentTokenHubRequest(_ request: VideoGenerationRequest, modelID: String, kind: String, options: [String: JSONValue], warnings: inout [AIWarning]) throws -> (endpoint: String, body: JSONValue) {
    let (first, last) = tencentFrames(request, warnings: &warnings)
    let images = request.inputReferences.filter { !["video", "audio"].contains(tencentMediaKind($0)) }
    let videos = request.inputReferences.filter { tencentMediaKind($0) == "video" }
    let audios = request.inputReferences.filter { tencentMediaKind($0) == "audio" }
    let resolution = tencentResolution(request, options, vod: false, warnings: &warnings)
    if !audios.isEmpty { warnings.append(tencentWarning("inputReferences", "TokenHub Kling models do not accept audio references; use `providerOptions.tencent.voices` instead. The audio was ignored.")) }
    var contents: [JSONValue] = request.prompt.isEmpty ? [] : [["type": "prompt", "text": .string(request.prompt)]]
    let elements = options["elements"]?.arrayValue ?? []
    let voices = options["voices"]?.arrayValue ?? []
    func elementContents() -> [JSONValue] { elements.map { .object(["type": "element", "element_id": $0["elementId"], "id": $0["id"]]) } }
    func mediaContent(_ type: String, _ file: ImageInputFile) throws -> JSONValue { ["type": .string(type), "url": .string(try convertImageModelFileToDataURI(file))] }
    var settings: [String: JSONValue] = [:]
    if let resolution { settings["resolution"] = resolution }
    func finish(_ endpoint: String, _ main: [String: JSONValue]) -> (String, JSONValue) {
        var body = main
        if !settings.isEmpty { body["settings"] = .object(settings) }
        var requestOptions: [String: JSONValue] = [:]
        if let external = options["externalTaskId"] { requestOptions["external_task_id"] = external }
        if let watermark = options["watermark"] { requestOptions["watermark_info"] = ["enabled": watermark] }
        if !requestOptions.isEmpty { body["options"] = .object(requestOptions) }
        return (endpoint, .object(body))
    }
    if kind == "motion-control" {
        if request.durationSeconds != nil { warnings.append(tencentWarning("duration", "Motion control output follows the length of the motion reference video.")) }
        if request.aspectRatio != nil { warnings.append(tencentWarning("aspectRatio", "Motion control output follows the aspect ratio of the input media.")) }
        if last != nil { warnings.append(tencentWarning("frameImages", "Motion control does not support a last frame; it was ignored.")) }
        let extraCount = (first == nil ? max(images.count - 1, 0) : images.count) + max(videos.count - 1, 0)
        if extraCount > 0 { warnings.append(tencentWarning("inputReferences", "Motion control uses one character image and one motion reference video; additional references were ignored.")) }
        if let character = first ?? images.first { contents.append(try mediaContent("image", character)) }
        if let motion = videos.first { contents.append(try mediaContent("video", motion)) }
        contents += elementContents()
        settings["character_orientation"] = options["characterOrientation"]
        if let audio = options["audio"] { settings["audio"] = audio }
        else if request.generateAudio == false { settings["audio"] = "off" }
        return finish("motion-control", ["model": .string(modelID), "contents": .array(contents)])
    }
    let supportsAudio = !["kling-video-v4", "kling-video-v3-turbo"].contains(modelID)
    let audio = options["audio"] ?? request.generateAudio.map { .string($0 ? "native" : "off") }
    if audio != nil && !supportsAudio { warnings.append(tencentWarning("generateAudio", "This TokenHub Kling model does not support the audio setting.")) }
    else { settings["audio"] = audio }
    if options["multiShot"] != nil && !supportsAudio { warnings.append(tencentWarning("providerOptions.tencent.multiShot", "This TokenHub Kling model does not support multi-shot output.")) }
    else { settings["multi_shot"] = options["multiShot"] }
    if let duration = request.durationSeconds { settings["duration"] = .number(duration) }
    let hasReferences = !images.isEmpty || !videos.isEmpty || !voices.isEmpty
    let omni = kind == "omni" || (modelID == "kling-video-v4" && (hasReferences || (first == nil && !elements.isEmpty)))
    if omni {
        if let first { contents.append(try mediaContent("first_frame", first)) }
        if let last { contents.append(try mediaContent("last_frame", last)) }
        for image in images { contents.append(try mediaContent("refer_image", image)) }
        for video in videos { contents.append(try mediaContent(options["referenceVideoType"] == "base" ? "base_video" : "feature_video", video)) }
        contents += elementContents()
        contents += voices.map { .object(["type": "voice", "voice_id": $0["voiceId"], "id": $0["id"]]) }
        settings["aspect_ratio"] = request.aspectRatio.map(JSONValue.string)
        return finish("omni-video", ["model": .string(modelID), "contents": .array(contents)])
    }
    if hasReferences { warnings.append(tencentWarning("inputReferences", "\(modelID) does not accept reference inputs; use an omni model such as kling-video-v3-omni or kling-video-v4. The references were ignored.")) }
    if let first {
        if request.aspectRatio != nil { warnings.append(tencentWarning("aspectRatio", "TokenHub Kling image-to-video follows the aspect ratio of the input image.")) }
        contents.append(try mediaContent("first_frame", first))
        if let last { contents.append(try mediaContent("last_frame", last)) }
        contents += elementContents()
        return finish("image-to-video", ["model": .string(modelID), "contents": .array(contents)])
    }
    if last != nil { warnings.append(tencentWarning("frameImages", "TokenHub Kling does not support a last frame without a first frame; the last frame was ignored.")) }
    if !elements.isEmpty { warnings.append(tencentWarning("providerOptions.tencent.elements", "TokenHub Kling text-to-video does not accept elements; the elements were ignored.")) }
    settings["aspect_ratio"] = request.aspectRatio.map(JSONValue.string)
    var body: [String: JSONValue] = ["model": .string(modelID)]
    if !request.prompt.isEmpty { body["prompt"] = .string(request.prompt) }
    return finish("text-to-video", body)
}
