@testable import SwiftAIProdia
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translated from upstream `@ai-sdk/prodia` 2.0.84 `prodia-language-model.test.ts`.

private let upstreamLanguagePrompt = "Describe this image"
private let upstreamLanguageModelID = "inference.nano-banana.img2img.v2"
private let upstreamDefaultLanguageJobResult = #"{"id":"job-lang-123","created_at":"2025-01-01T00:00:00Z","updated_at":"2025-01-01T00:00:03Z","state":{"current":"completed"},"config":{"prompt":"Describe this image","seed":7},"metrics":{"elapsed":1.5,"ips":20.0},"price":{"product":"nano-banana","dollars":0.01}}"#

/// Mirrors upstream `createLanguageMultipartResponse`.
private func upstreamLanguageResponse(
    jobResult: String = upstreamDefaultLanguageJobResult,
    textContent: String? = "This is a beautiful landscape.",
    imageContent: String? = "test-image-bytes"
) -> AIHTTPResponse {
    var parts = [prodiaUpstreamJobPart(jobResult)]
    if let textContent {
        parts.append((name: "output", fileName: "message.txt", contentType: "text/plain", body: Data(textContent.utf8)))
    }
    if let imageContent {
        parts.append((name: "output", fileName: "image.png", contentType: "image/png", body: Data(imageContent.utf8)))
    }
    return prodiaUpstreamMultipartResponse(parts)
}

private func upstreamLanguageModel(
    transport: RecordingTransport,
    headers: [String: String] = [:]
) throws -> any LanguageModel {
    try AIProviders.prodia(configuration: ProdiaProviderSettings(
        apiKey: "test-key",
        baseURL: "https://api.example.com/v2",
        headers: headers,
        transport: transport
    )).languageModel(upstreamLanguageModelID)
}

private func sentJob(_ transport: RecordingTransport) async throws -> JSONValue {
    let request = try #require(await transport.requests().first)
    let job = try #require(try prodiaRequestFormParts(request).first { $0.name == "job" })
    return try decodeJSONBody(job.body)
}

private func sentInput(_ transport: RecordingTransport) async throws -> MultipartResponsePart? {
    let request = try #require(await transport.requests().first)
    return try prodiaRequestFormParts(request).first { $0.name == "input" }
}

// describe('constructor')

@Test func prodiaLanguageUpstreamExposesCorrectProviderAndModelInformation() throws {
    let model = try upstreamLanguageModel(transport: RecordingTransport(response: upstreamLanguageResponse()))

    #expect(model.providerID == "prodia.language")
    #expect(model.modelID == upstreamLanguageModelID)
    #expect(model.supportedURLs.isEmpty)
}

// describe('doGenerate')

@Test func prodiaLanguageUpstreamExtractsTextFromUserMessageAndSendsCorrectRequest() async throws {
    let transport = RecordingTransport(response: upstreamLanguageResponse())

    _ = try await upstreamLanguageModel(transport: transport).generate(LanguageModelRequest(messages: [
        AIMessage(role: .user, content: [
            .file(mimeType: "image/png", data: Data([1, 2, 3])),
            .text("Describe this image")
        ])
    ]))

    let request = try #require(await transport.requests().first)
    #expect(request.method == "POST")
    #expect(prodiaHeader(request, "content-type")?.contains("multipart/form-data") == true)
}

@Test func prodiaLanguageUpstreamRoutesTopLevelOnlyImageMediaTypeWithDetectedFullMIME() async throws {
    let transport = RecordingTransport(response: upstreamLanguageResponse())

    _ = try await upstreamLanguageModel(transport: transport).generate(LanguageModelRequest(messages: [
        AIMessage(role: .user, content: [
            .file(mimeType: "image", data: Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])),
            .text("Describe this image")
        ])
    ]))

    let input = try #require(try await sentInput(transport))
    #expect(input.contentType == "image/png")
}

@Test func prodiaLanguageUpstreamTopLevelOnlyImageWithUndetectableBytesKeepsDefaultContentType() async throws {
    let transport = RecordingTransport(response: upstreamLanguageResponse())

    _ = try await upstreamLanguageModel(transport: transport).generate(LanguageModelRequest(messages: [
        AIMessage(role: .user, content: [
            .file(mimeType: "image", data: Data([0x00, 0x01, 0x02])),
            .text("Describe this image")
        ])
    ]))

    let input = try #require(try await sentInput(transport))
    #expect(input.contentType == "image/png")
}

@Test func prodiaLanguageUpstreamIncludesSystemMessageInPrompt() async throws {
    let transport = RecordingTransport(response: upstreamLanguageResponse())

    _ = try await upstreamLanguageModel(transport: transport).generate(LanguageModelRequest(messages: [
        .system("You are an art critic."),
        .user("Describe this.")
    ]))

    let request = try #require(await transport.requests().first)
    #expect(request.method == "POST")
    // Upstream prepends the system message with a newline separator.
    #expect(try await sentJob(transport)["config"]?["prompt"]?.stringValue == "You are an art critic.\nDescribe this.")
}

@Test func prodiaLanguageUpstreamSendsIncludeMessagesTrueInConfig() async throws {
    let transport = RecordingTransport(response: upstreamLanguageResponse())

    _ = try await upstreamLanguageModel(transport: transport).generate(LanguageModelRequest(messages: [.user("Hello")]))

    #expect(try await sentJob(transport)["config"]?["include_messages"] == .bool(true))
}

@Test func prodiaLanguageUpstreamReturnsTextContentFromMessageTxtResponsePart() async throws {
    let result = try await upstreamLanguageModel(transport: RecordingTransport(response: upstreamLanguageResponse()))
        .generate(LanguageModelRequest(messages: [.user(upstreamLanguagePrompt)]))

    let textParts = result.content.compactMap { part -> String? in
        if case let .text(text, _) = part { return text }
        return nil
    }
    #expect(textParts == ["This is a beautiful landscape."])
}

@Test func prodiaLanguageUpstreamReturnsImageContentFromImagePngResponsePart() async throws {
    let result = try await upstreamLanguageModel(transport: RecordingTransport(response: upstreamLanguageResponse()))
        .generate(LanguageModelRequest(messages: [.user(upstreamLanguagePrompt)]))

    let fileParts = result.content.compactMap { part -> AIStreamFile? in
        if case let .file(file) = part { return file }
        return nil
    }
    #expect(fileParts.count == 1)
    #expect(fileParts.first?.mediaType == "image/png")
    #expect(fileParts.first?.data.map { String(decoding: $0, as: UTF8.self) } == "test-image-bytes")
    #expect(result.files.count == 1)
}

@Test func prodiaLanguageUpstreamReturnsFinishReasonAsStop() async throws {
    let result = try await upstreamLanguageModel(transport: RecordingTransport(response: upstreamLanguageResponse()))
        .generate(LanguageModelRequest(messages: [.user(upstreamLanguagePrompt)]))

    #expect(result.finishReason == "stop")
}

@Test func prodiaLanguageUpstreamReturnsProviderMetadata() async throws {
    let result = try await upstreamLanguageModel(transport: RecordingTransport(response: upstreamLanguageResponse()))
        .generate(LanguageModelRequest(messages: [.user(upstreamLanguagePrompt)]))

    #expect(result.providerMetadata["prodia"] == .object([
        "jobId": "job-lang-123",
        "seed": 7,
        "elapsed": 1.5,
        "iterationsPerSecond": 20.0,
        "createdAt": "2025-01-01T00:00:00Z",
        "updatedAt": "2025-01-01T00:00:03Z",
        "dollars": 0.01
    ]))
}

@Test func prodiaLanguageUpstreamEmitsWarningsForUnsupportedLLMFeatures() async throws {
    let result = try await upstreamLanguageModel(transport: RecordingTransport(response: upstreamLanguageResponse()))
        .generate(LanguageModelRequest(
            messages: [.user(upstreamLanguagePrompt)],
            temperature: 0.5,
            topP: 0.9,
            topK: 40,
            presencePenalty: 0.1,
            frequencyPenalty: 0.2,
            seed: 42,
            maxOutputTokens: 1000,
            stopSequences: ["stop"],
            responseFormat: .json(),
            reasoning: "medium",
            tools: ["test": .object(["type": "function", "inputSchema": .object([:])])],
            toolChoice: .object(["type": "auto"])
        ))

    let features = result.warnings.filter { $0.type == "unsupported" }.compactMap(\.feature)
    for feature in [
        "temperature", "topP", "topK", "seed", "maxOutputTokens", "stopSequences",
        "presencePenalty", "frequencyPenalty", "tools", "toolChoice", "responseFormat", "reasoning"
    ] {
        #expect(features.contains(feature), "missing \(feature)")
    }
}

@Test func prodiaLanguageUpstreamPassesAspectRatioFromProviderOptions() async throws {
    let transport = RecordingTransport(response: upstreamLanguageResponse())

    _ = try await upstreamLanguageModel(transport: transport).generate(LanguageModelRequest(
        messages: [.user(upstreamLanguagePrompt)],
        providerOptions: ["prodia": .object(["aspectRatio": "16:9"])]
    ))

    #expect(try await sentJob(transport)["config"]?["aspect_ratio"]?.stringValue == "16:9")
}

@Test func prodiaLanguageUpstreamMergesProviderAndRequestHeaders() async throws {
    let transport = RecordingTransport(response: upstreamLanguageResponse())
    let model = try upstreamLanguageModel(transport: transport, headers: [
        "Custom-Provider-Header": "provider-value",
        "Authorization": "Bearer test-key"
    ])

    _ = try await model.generate(LanguageModelRequest(
        messages: [.user(upstreamLanguagePrompt)],
        headers: ["Custom-Request-Header": "request-value"]
    ))

    let request = try #require(await transport.requests().first)
    #expect(prodiaHeader(request, "custom-provider-header") == "provider-value")
    #expect(prodiaHeader(request, "custom-request-header") == "request-value")
    #expect(prodiaHeader(request, "authorization") == "Bearer test-key")
}

@Test func prodiaLanguageUpstreamIncludesTimestampAndModelIDInResponse() async throws {
    // Upstream injects `_internal.currentDate`; Swift has no clock seam.
    let before = Date()
    let result = try await upstreamLanguageModel(transport: RecordingTransport(response: upstreamLanguageResponse()))
        .generate(LanguageModelRequest(messages: [.user(upstreamLanguagePrompt)]))
    let after = Date()

    let timestamp = try #require(result.responseMetadata.timestamp)
    #expect(timestamp >= before && timestamp <= after)
    #expect(result.responseMetadata.modelID == upstreamLanguageModelID)
    #expect(result.responseMetadata.headers["content-type"] == "multipart/form-data; boundary=test-boundary-12345")
}

@Test func prodiaLanguageUpstreamHandlesAPIErrors() async throws {
    let transport = RecordingTransport(response: AIHTTPResponse(
        statusCode: 400,
        headers: [:],
        body: Data(#"{"message":"Bad request","detail":"Missing input image"}"#.utf8)
    ))

    await #expect(throws: AIError.apiCall(provider: "prodia.language", statusCode: 400, body: "Missing input image")) {
        _ = try await upstreamLanguageModel(transport: transport).generate(LanguageModelRequest(messages: [.user(upstreamLanguagePrompt)]))
    }
}

@Test func prodiaLanguageUpstreamHandlesResponseWithTextOnly() async throws {
    let result = try await upstreamLanguageModel(transport: RecordingTransport(response: upstreamLanguageResponse(
        textContent: "Just a text response",
        imageContent: nil
    ))).generate(LanguageModelRequest(messages: [.user(upstreamLanguagePrompt)]))

    #expect(result.content == [.text("Just a text response")])
}

// describe('doStream')

@Test func prodiaLanguageUpstreamWrapsDoGenerateResultIntoStreamParts() async throws {
    let model = try upstreamLanguageModel(transport: RecordingTransport(response: upstreamLanguageResponse(
        textContent: "Stream test response",
        imageContent: "stream-image-bytes"
    )))

    var parts: [LanguageStreamPart] = []
    for try await part in model.stream(LanguageModelRequest(messages: [.user(upstreamLanguagePrompt)])) {
        parts.append(part)
    }

    try #require(parts.count == 7)
    guard case .streamStart = parts[0] else { Issue.record("expected stream-start, got \(parts[0])"); return }
    guard case .responseMetadata = parts[1] else { Issue.record("expected response-metadata, got \(parts[1])"); return }
    guard case .textStart = parts[2] else { Issue.record("expected text-start, got \(parts[2])"); return }
    guard case let .textDeltaPart(_, delta, _) = parts[3] else { Issue.record("expected text-delta, got \(parts[3])"); return }
    #expect(delta == "Stream test response")
    guard case .textEnd = parts[4] else { Issue.record("expected text-end, got \(parts[4])"); return }
    guard case let .file(file) = parts[5] else { Issue.record("expected file, got \(parts[5])"); return }
    #expect(file.mediaType == "image/png")
    guard case let .finishMetadata(reason, _, _) = parts[6] else { Issue.record("expected finish, got \(parts[6])"); return }
    #expect(reason == "stop")
}
