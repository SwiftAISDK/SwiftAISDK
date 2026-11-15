@testable import SwiftAIProdia
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translated from upstream `@ai-sdk/prodia` 2.0.84 `prodia-video-model.test.ts`.

private let upstreamVideoPrompt = "A cat walking on a beach"
private let upstreamVideoModelID = "inference.wan2-2.lightning.txt2vid.v0"
private let upstreamVideoBaseURL = "https://api.example.com/v2"
private let upstreamVideoJobURL = "https://api.example.com/v2/job?price=true"

private let upstreamDefaultVideoJobResult = #"{"id":"job-vid-123","created_at":"2025-01-01T00:00:00Z","updated_at":"2025-01-01T00:00:10Z","state":{"current":"completed"},"config":{"prompt":"A cat walking on a beach","seed":99},"metrics":{"elapsed":5.0,"ips":3.2},"price":{"product":"wan2-2.lightning","dollars":0.05}}"#

/// Mirrors upstream `createVideoMultipartResponse`.
private func upstreamVideoMultipartResponse(
    jobResult: String = upstreamDefaultVideoJobResult,
    videoContent: String = "test-video-content",
    videoContentType: String = "video/mp4",
    videoFilename: String = "output.mp4"
) -> AIHTTPResponse {
    let boundary = "test-boundary-12345"
    var body = Data()
    body.append(Data("--\(boundary)\r\n".utf8))
    body.append(Data("Content-Disposition: form-data; name=\"job\"; filename=\"job.json\"\r\n".utf8))
    body.append(Data("Content-Type: application/json\r\n".utf8))
    body.append(Data("\r\n".utf8))
    body.append(Data(jobResult.utf8))
    body.append(Data("\r\n".utf8))
    body.append(Data("--\(boundary)\r\n".utf8))
    body.append(Data("Content-Disposition: form-data; name=\"output\"; filename=\"\(videoFilename)\"\r\n".utf8))
    body.append(Data("Content-Type: \(videoContentType)\r\n".utf8))
    body.append(Data("\r\n".utf8))
    body.append(Data(videoContent.utf8))
    body.append(Data("\r\n--\(boundary)--\r\n".utf8))
    return AIHTTPResponse(
        statusCode: 200,
        headers: ["content-type": "multipart/form-data; boundary=\(boundary)"],
        body: body
    )
}

private func upstreamVideoModel(
    transport: RecordingTransport,
    headers: [String: String] = [:],
    modelID: String = upstreamVideoModelID
) throws -> any VideoModel {
    try AIProviders.prodia(configuration: ProdiaProviderSettings(
        apiKey: "test-key",
        baseURL: upstreamVideoBaseURL,
        headers: headers,
        transport: transport
    )).videoModel(modelID)
}

private func header(_ request: AIHTTPRequest, _ name: String) -> String? {
    request.headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
}

// describe('constructor')

@Test func prodiaVideoUpstreamExposesCorrectProviderAndModelInformation() throws {
    let model = try #require(try upstreamVideoModel(transport: RecordingTransport(response: upstreamVideoMultipartResponse())) as? ProdiaVideoModel)

    #expect(model.providerID == "prodia.video")
    #expect(model.modelID == "inference.wan2-2.lightning.txt2vid.v0")
    #expect(model.maxVideosPerCall == 1)
    #expect(model.supportsUnaryVideoGeneration)
}

// describe('doGenerate - txt2vid')

@Test func prodiaVideoUpstreamSendsCorrectJSONRequestBodyWithPrompt() async throws {
    let transport = RecordingTransport(response: upstreamVideoMultipartResponse())
    let model = try upstreamVideoModel(transport: transport)

    _ = try await model.generateVideo(VideoGenerationRequest(prompt: upstreamVideoPrompt))

    let request = try #require(await transport.requests().first)
    #expect(try decodeJSONBody(try #require(request.body)) == .object([
        "type": "inference.wan2-2.lightning.txt2vid.v0",
        "config": .object(["prompt": .string(upstreamVideoPrompt)])
    ]))
}

@Test func prodiaVideoUpstreamIncludesSeedWhenProvided() async throws {
    let transport = RecordingTransport(response: upstreamVideoMultipartResponse())
    let model = try upstreamVideoModel(transport: transport)

    _ = try await model.generateVideo(VideoGenerationRequest(prompt: upstreamVideoPrompt, seed: 42))

    let request = try #require(await transport.requests().first)
    #expect(try decodeJSONBody(try #require(request.body)) == .object([
        "type": "inference.wan2-2.lightning.txt2vid.v0",
        "config": .object(["prompt": .string(upstreamVideoPrompt), "seed": 42])
    ]))
}

@Test func prodiaVideoUpstreamIncludesResolutionFromProviderOptions() async throws {
    let transport = RecordingTransport(response: upstreamVideoMultipartResponse())
    let model = try upstreamVideoModel(transport: transport)

    _ = try await model.generateVideo(VideoGenerationRequest(
        prompt: upstreamVideoPrompt,
        providerOptions: ["prodia": .object(["resolution": "720p"])]
    ))

    let request = try #require(await transport.requests().first)
    #expect(try decodeJSONBody(try #require(request.body)) == .object([
        "type": "inference.wan2-2.lightning.txt2vid.v0",
        "config": .object(["prompt": .string(upstreamVideoPrompt), "resolution": "720p"])
    ]))
}

@Test func prodiaVideoUpstreamCallsTheCorrectEndpoint() async throws {
    let transport = RecordingTransport(response: upstreamVideoMultipartResponse())
    let model = try upstreamVideoModel(transport: transport)

    _ = try await model.generateVideo(VideoGenerationRequest(prompt: upstreamVideoPrompt))

    let request = try #require(await transport.requests().first)
    #expect(request.method == "POST")
    #expect(request.url.absoluteString == upstreamVideoJobURL)
}

@Test func prodiaVideoUpstreamSendsCorrectAcceptHeader() async throws {
    let transport = RecordingTransport(response: upstreamVideoMultipartResponse())
    let model = try upstreamVideoModel(transport: transport)

    _ = try await model.generateVideo(VideoGenerationRequest(prompt: upstreamVideoPrompt))

    let request = try #require(await transport.requests().first)
    #expect(header(request, "accept") == "multipart/form-data; video/mp4")
}

@Test func prodiaVideoUpstreamSendsJSONContentTypeForTxt2vid() async throws {
    let transport = RecordingTransport(response: upstreamVideoMultipartResponse())
    let model = try upstreamVideoModel(transport: transport)

    _ = try await model.generateVideo(VideoGenerationRequest(prompt: upstreamVideoPrompt))

    let request = try #require(await transport.requests().first)
    #expect(header(request, "content-type") == "application/json")
}

@Test func prodiaVideoUpstreamMergesProviderAndRequestHeaders() async throws {
    let transport = RecordingTransport(response: upstreamVideoMultipartResponse())
    let model = try upstreamVideoModel(transport: transport, headers: [
        "Custom-Provider-Header": "provider-value",
        "Authorization": "Bearer test-key"
    ])

    _ = try await model.generateVideo(VideoGenerationRequest(
        prompt: upstreamVideoPrompt,
        headers: ["Custom-Request-Header": "request-value"]
    ))

    let request = try #require(await transport.requests().first)
    #expect(header(request, "custom-provider-header") == "provider-value")
    #expect(header(request, "custom-request-header") == "request-value")
    #expect(header(request, "authorization") == "Bearer test-key")
}

@Test func prodiaVideoUpstreamReturnsVideoDataFromMultipartResponse() async throws {
    let transport = RecordingTransport(response: upstreamVideoMultipartResponse())
    let model = try upstreamVideoModel(transport: transport)

    let result = try await model.generateVideo(VideoGenerationRequest(prompt: upstreamVideoPrompt))

    #expect(result.urls.isEmpty)
    #expect(result.base64Videos.count == 1)
    #expect(result.mediaType == "video/mp4")
    let video = try #require(result.base64Videos.first.flatMap { Data(base64Encoded: $0) })
    #expect(String(decoding: video, as: UTF8.self) == "test-video-content")
}

@Test func prodiaVideoUpstreamReturnsProviderMetadata() async throws {
    let transport = RecordingTransport(response: upstreamVideoMultipartResponse())
    let model = try upstreamVideoModel(transport: transport)

    let result = try await model.generateVideo(VideoGenerationRequest(prompt: upstreamVideoPrompt))

    #expect(result.providerMetadata["prodia"] == .object([
        "videos": .array([
            .object([
                "jobId": "job-vid-123",
                "seed": 99,
                "elapsed": 5.0,
                "iterationsPerSecond": 3.2,
                "createdAt": "2025-01-01T00:00:00Z",
                "updatedAt": "2025-01-01T00:00:10Z",
                "dollars": 0.05
            ])
        ])
    ]))
}

@Test func prodiaVideoUpstreamIncludesTimestampAndModelIDInResponse() async throws {
    // Upstream injects `_internal.currentDate`; the Swift configuration has no
    // clock seam, so the timestamp is checked against the request window.
    let transport = RecordingTransport(response: upstreamVideoMultipartResponse())
    let model = try upstreamVideoModel(transport: transport)

    let before = Date()
    let result = try await model.generateVideo(VideoGenerationRequest(prompt: upstreamVideoPrompt))
    let after = Date()

    #expect(result.responseMetadata.modelID == "inference.wan2-2.lightning.txt2vid.v0")
    let timestamp = try #require(result.responseMetadata.timestamp)
    #expect(timestamp >= before && timestamp <= after)
    #expect(result.responseMetadata.headers["content-type"] == "multipart/form-data; boundary=test-boundary-12345")
}

@Test func prodiaVideoUpstreamHandlesAPIErrors() async throws {
    let transport = RecordingTransport(response: AIHTTPResponse(
        statusCode: 400,
        headers: [:],
        body: Data(#"{"message":"Invalid prompt","detail":"Prompt cannot be empty"}"#.utf8)
    ))
    let model = try upstreamVideoModel(transport: transport)

    await #expect(throws: AIError.apiCall(provider: "prodia.video", statusCode: 400, body: "Prompt cannot be empty")) {
        _ = try await model.generateVideo(VideoGenerationRequest(prompt: upstreamVideoPrompt))
    }
    let request = try #require(await transport.requests().first)
    #expect(request.url.absoluteString == upstreamVideoJobURL)
}

// describe('doGenerate - img2vid')

@Test func prodiaVideoUpstreamSendsMultipartFormDataWhenImageIsProvided() async throws {
    let transport = RecordingTransport(response: upstreamVideoMultipartResponse())
    let model = try upstreamVideoModel(transport: transport, modelID: "inference.wan2-2.lightning.img2vid.v0")

    let result = try await model.generateVideo(VideoGenerationRequest(
        prompt: upstreamVideoPrompt,
        image: ImageInputFile(data: Data([1, 2, 3, 4]), mediaType: "image/png")
    ))

    let request = try #require(await transport.requests().first)
    #expect(request.method == "POST")
    #expect(header(request, "content-type")?.contains("multipart/form-data") == true)
    #expect(header(request, "accept") == "multipart/form-data; video/mp4")
    #expect(result.base64Videos == [Data("test-video-content".utf8).base64EncodedString()])
    #expect(result.mediaType == "video/mp4")
}

@Test func prodiaVideoUpstreamDownloadsPublicImageURLAndSendsMultipartFormData() async throws {
    let transport = RecordingTransport(responses: [
        AIHTTPResponse(statusCode: 200, headers: ["content-type": "image/png"], body: Data("input-image-bytes".utf8)),
        upstreamVideoMultipartResponse()
    ])
    let model = try upstreamVideoModel(transport: transport, modelID: "inference.wan2-2.lightning.img2vid.v0")

    _ = try await model.generateVideo(VideoGenerationRequest(
        prompt: upstreamVideoPrompt,
        image: ImageInputFile(url: "https://cdn.example.com/input.png")
    ))

    let requests = await transport.requests()
    #expect(requests.contains { $0.url.absoluteString == "https://cdn.example.com/input.png" })
    let jobCall = try #require(requests.first { $0.url.absoluteString == upstreamVideoJobURL })
    #expect(jobCall.method == "POST")
    #expect(header(jobCall, "content-type")?.contains("multipart/form-data") == true)
    let bodyText = String(decoding: try #require(jobCall.body), as: UTF8.self)
    #expect(bodyText.contains("input-image-bytes"))
    #expect(bodyText.contains("name=\"input\"; filename=\"input.png\""))
}

@Test func prodiaVideoUpstreamBlocksImageURLPointingAtPrivateAddress() async throws {
    let transport = RecordingTransport(response: upstreamVideoMultipartResponse())
    let model = try upstreamVideoModel(transport: transport, modelID: "inference.wan2-2.lightning.img2vid.v0")

    await #expect(throws: AIError.self) {
        _ = try await model.generateVideo(VideoGenerationRequest(
            prompt: upstreamVideoPrompt,
            image: ImageInputFile(url: "http://169.254.169.254/latest/meta-data/")
        ))
    }

    let requests = await transport.requests()
    #expect(!requests.contains { $0.url.absoluteString.contains("169.254.169.254") })
    #expect(!requests.contains { $0.url.absoluteString.contains("/v2/job") })
}

// Local: response-handler media type selection from upstream
// `createVideoMultipartResponseHandler`.

@Test func prodiaVideoUpstreamUsesOutputPartMediaTypeAndDefaultsToMP4() async throws {
    let webm = try await upstreamVideoModel(transport: RecordingTransport(response: upstreamVideoMultipartResponse(
        videoContentType: "video/webm",
        videoFilename: "output.webm"
    ))).generateVideo(VideoGenerationRequest(prompt: upstreamVideoPrompt))
    #expect(webm.mediaType == "video/webm")

    let octet = try await upstreamVideoModel(transport: RecordingTransport(response: upstreamVideoMultipartResponse(
        videoContentType: "application/octet-stream"
    ))).generateVideo(VideoGenerationRequest(prompt: upstreamVideoPrompt))
    #expect(octet.mediaType == "video/mp4")
    #expect(octet.base64Videos == [Data("test-video-content".utf8).base64EncodedString()])
}
