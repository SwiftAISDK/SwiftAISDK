import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Testing
import SwiftAI
@testable import SwiftAIAnthropicAWS


@Test func anthropicAWSUsesWorkspaceAndAPIKeyHeaders() async throws {
    let transport = RecordingTransport(response: jsonResponse("""
    {"content":[{"type":"text","text":"aws claude"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":2}}
    """))
    let provider = try AIProviders.anthropicAWS(configuration: AnthropicAWSProviderSettings(
        region: "us-west-2",
        workspaceID: "wrkspc_test",
        apiKey: "aws-api-key",
        transport: transport
    ))
    let model = try provider.languageModel("claude-sonnet-4-6")

    #expect(model.providerID == "anthropic-aws.messages")
    let result = try await model.generate(LanguageModelRequest(messages: [.user("Hello")]))

    #expect(result.text == "aws claude")
    let request = try #require(await transport.requests().first)
    #expect(request.url.absoluteString == "https://aws-external-anthropic.us-west-2.api.aws/v1/messages")
    #expect(request.headers["x-api-key"] == "aws-api-key")
    #expect(request.headers["anthropic-workspace-id"] == "wrkspc_test")
    #expect(request.headers["anthropic-version"] == "2023-06-01")
    #expect(request.headers["user-agent"] == "ai-sdk-anthropic-aws/2.0.81")
    let body = try decodeJSONBody(try #require(request.body))
    #expect(body["model"]?.stringValue == "claude-sonnet-4-6")
    #expect(body["messages"]?[0]?["content"]?[0]?["text"]?.stringValue == "Hello")
}
@Test func anthropicAWSAppendsVersionedUserAgentToCustomHeader() async throws {
    let transport = RecordingTransport(response: jsonResponse("""
    {"content":[{"type":"text","text":"aws custom"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}
    """))
    let provider = try AIProviders.anthropicAWS(configuration: AnthropicAWSProviderSettings(
        region: "us-west-2",
        workspaceID: "wrkspc_test",
        apiKey: "aws-api-key",
        headers: ["User-Agent": "CustomApp/1.0"],
        transport: transport
    ))
    let model = try provider.languageModel("claude-sonnet-4-6")

    _ = try await model.generate(LanguageModelRequest(messages: [.user("Hello")]))

    let request = try #require(await transport.requests().first)
    #expect(request.headers["x-api-key"] == "aws-api-key")
    #expect(request.headers["user-agent"] == "CustomApp/1.0 ai-sdk-anthropic-aws/2.0.81")
}
@Test func anthropicAWSAPIKeyOverridesCustomXAPIKeyLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse("""
    {"content":[{"type":"text","text":"aws auth"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}
    """))
    let provider = try AIProviders.anthropicAWS(configuration: AnthropicAWSProviderSettings(
        region: "us-west-2",
        workspaceID: "wrkspc_test",
        apiKey: "aws-api-key",
        headers: ["x-api-key": "custom-key"],
        transport: transport
    ))
    let model = try provider.chat("claude-sonnet-4-6")

    _ = try await model.generate(LanguageModelRequest(messages: [.user("Hello")]))

    let request = try #require(await transport.requests().first)
    #expect(request.headers["x-api-key"] == "aws-api-key")
}
@Test func anthropicAWSSignsMessagesWithSigV4() async throws {
    let fixedDate = DateComponents(
        calendar: Calendar(identifier: .gregorian),
        timeZone: TimeZone(secondsFromGMT: 0),
        year: 2024,
        month: 3,
        day: 15,
        hour: 0,
        minute: 0,
        second: 0
    ).date!
    let transport = RecordingTransport(response: jsonResponse("""
    {"content":[{"type":"text","text":"signed"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}
    """))
    let provider = try AIProviders.anthropicAWS(configuration: AnthropicAWSProviderSettings(
        region: "us-west-2",
        workspaceID: "wrkspc_test",
        accessKeyID: "AKIDEXAMPLE",
        secretAccessKey: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
        transport: transport,
        date: { fixedDate }
    ))
    let model = try provider.languageModel("claude-sonnet-4-6")

    let result = try await model.generate(LanguageModelRequest(messages: [.user("Hello")]))

    #expect(result.text == "signed")
    let request = try #require(await transport.requests().first)
    #expect(request.url.absoluteString == "https://aws-external-anthropic.us-west-2.api.aws/v1/messages")
    #expect(request.headers["x-amz-date"] == "20240315T000000Z")
    #expect(request.headers["x-amz-content-sha256"] != nil)
    #expect(request.headers["authorization"]?.contains("Credential=AKIDEXAMPLE/20240315/us-west-2/aws-external-anthropic/aws4_request") == true)
    #expect(request.headers["anthropic-workspace-id"] == "wrkspc_test")
    #expect(request.headers["user-agent"] == "ai-sdk-anthropic-aws/2.0.81")
}

@Test func anthropicAWSSigV4WrapperPreservesStreamingTransportCapability() async throws {
    let fixedDate = DateComponents(
        calendar: Calendar(identifier: .gregorian),
        timeZone: TimeZone(secondsFromGMT: 0),
        year: 2024,
        month: 3,
        day: 15,
        hour: 0,
        minute: 0,
        second: 0
    ).date!
    let transport = RecordingTransport(response: sseResponse("""
    data: {"type":"message_start","message":{"id":"msg-stream","usage":{"input_tokens":1,"output_tokens":0}}}

    data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

    data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"signed stream"}}

    data: {"type":"content_block_stop","index":0}

    data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":2}}

    data: {"type":"message_stop"}

    """))
    let provider = try AIProviders.anthropicAWS(configuration: AnthropicAWSProviderSettings(
        region: "us-west-2",
        workspaceID: "wrkspc_test",
        accessKeyID: "AKIDEXAMPLE",
        secretAccessKey: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
        transport: transport,
        date: { fixedDate }
    ))
    let model = try provider.languageModel("claude-sonnet-4-6")

    var text = ""
    for try await part in model.stream(LanguageModelRequest(messages: [.user("Hello")])) {
        if case let .textDeltaPart(_, delta, _) = part {
            text += delta
        }
    }

    #expect(text == "signed stream")
    #expect(await transport.sendRequests().isEmpty)
    let request = try #require(await transport.streamRequests().first)
    #expect(request.headers["x-amz-date"] == "20240315T000000Z")
    #expect(request.headers["authorization"]?.contains("Credential=AKIDEXAMPLE/20240315/us-west-2/aws-external-anthropic/aws4_request") == true)
}
@Test func anthropicAWSSupportsDynamicCredentialProviderLikeUpstream() async throws {
    let fixedDate = DateComponents(
        calendar: Calendar(identifier: .gregorian),
        timeZone: TimeZone(secondsFromGMT: 0),
        year: 2024,
        month: 3,
        day: 15,
        hour: 0,
        minute: 0,
        second: 0
    ).date!
    let transport = RecordingTransport(response: jsonResponse("""
    {"content":[{"type":"text","text":"dynamic"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}
    """))
    let provider = try AIProviders.anthropicAWS(configuration: AnthropicAWSProviderSettings(
        region: "us-west-2",
        workspaceID: "wrkspc_test",
        credentialProvider: {
            AnthropicAWSCredentials(
                accessKeyID: "DYNAMICACCESS",
                secretAccessKey: "dynamicSecret",
                sessionToken: "dynamic-session"
            )
        },
        transport: transport,
        date: { fixedDate }
    ))
    let model = try provider.languageModel("claude-sonnet-4-6")

    _ = try await model.generate(LanguageModelRequest(messages: [.user("Hello")]))

    let request = try #require(await transport.requests().first)
    #expect(request.headers["authorization"]?.contains("Credential=DYNAMICACCESS/20240315/us-west-2/aws-external-anthropic/aws4_request") == true)
    #expect(request.headers["x-amz-security-token"] == "dynamic-session")
}
@Test func anthropicAWSRejectsUnsupportedModelFamiliesLikeUpstream() throws {
    let provider = try AIProviders.anthropicAWS(configuration: AnthropicAWSProviderSettings(
        region: "us-west-2",
        workspaceID: "wrkspc_test",
        apiKey: "aws-api-key",
        transport: RecordingTransport(response: jsonResponse("{}"))
    ))

    #expect(throws: AIError.unsupportedModel(provider: "anthropic-aws", capability: .embedding, modelID: "embed")) {
        _ = try provider.embeddingModel("embed")
    }
    #expect(throws: AIError.unsupportedModel(provider: "anthropic-aws", capability: .embedding, modelID: "embed")) {
        _ = try provider.textEmbeddingModel("embed")
    }
    #expect(throws: AIError.unsupportedModel(provider: "anthropic-aws", capability: .image, modelID: "image")) {
        _ = try provider.imageModel("image")
    }
}
@Test func anthropicAWSRequestUsesAWSProviderReferenceKeyForUploadedFiles() async throws {
    let transport = RecordingTransport(response: jsonResponse("""
    {"content":[{"type":"text","text":"aws"}],"stop_reason":"end_turn","usage":{"input_tokens":2,"output_tokens":1}}
    """))
    let provider = try AIProviders.anthropicAWS(configuration: AnthropicAWSProviderSettings(
        region: "us-west-2",
        workspaceID: "wrkspc_test",
        apiKey: "aws-api-key",
        transport: transport
    ))
    let model = try provider.languageModel("claude-sonnet-4-6")

    _ = try await model.generate(LanguageModelRequest(messages: [
        AIMessage(role: .user, content: [
            .providerReference(mimeType: "application/pdf", reference: ["anthropic-aws": "file_aws"])
        ])
    ]))

    let request = try #require(await transport.requests().first)
    #expect(request.headers["anthropic-beta"]?.contains("files-api-2025-04-14") == true)
    let body = try decodeJSONBody(try #require(request.body))
    #expect(body["messages"]?[0]?["content"]?[0]?["type"]?.stringValue == "document")
    #expect(body["messages"]?[0]?["content"]?[0]?["source"]?["type"]?.stringValue == "file")
    #expect(body["messages"]?[0]?["content"]?[0]?["source"]?["file_id"]?.stringValue == "file_aws")
}

@Test func anthropicAWSFilesAndSkillsUseUpstreamProviderIDs() async throws {
    let transport = RecordingTransport(responses: [
        jsonResponse("""
        {"id":"file_aws","type":"file","filename":"data.pdf","mime_type":"application/pdf","size_bytes":10}
        """),
        jsonResponse("""
        {"id":"skill_aws","display_title":"AWS Skill","latest_version":"v1","source":"custom"}
        """),
        jsonResponse("""
        {"type":"skill_version","skill_id":"skill_aws","name":"aws-skill","description":"AWS hosted skill"}
        """)
    ])
    let provider = try AIProviders.anthropicAWS(configuration: AnthropicAWSProviderSettings(
        region: "us-west-2",
        workspaceID: "wrkspc_test",
        apiKey: "aws-api-key",
        transport: transport
    ))

    let files = provider.files()
    #expect(files.providerID == "anthropic-aws.messages")
    let file = try await files.uploadFile(FileUploadRequest(data: Data([1, 2, 3]), mediaType: "application/pdf", filename: "data.pdf"))
    #expect(file.providerReference["anthropic-aws"] == "file_aws")

    let skills = provider.skills()
    #expect(skills.providerID == "anthropic-aws.skills")
    let skill = try await skills.uploadSkill(SkillUploadRequest(
        files: [
            SkillUploadFile(path: "index.ts", data: Data("console.log('hi')".utf8), mediaType: "text/typescript")
        ],
        displayTitle: "AWS Skill"
    ))
    #expect(skill.providerReference["anthropic-aws"] == "skill_aws")
    #expect(skill.providerMetadata["anthropic-aws"]?["source"]?.stringValue == "custom")

    let requests = await transport.requests()
    #expect(requests.count == 3)
    #expect(requests[0].url.absoluteString == "https://aws-external-anthropic.us-west-2.api.aws/v1/files")
    #expect(requests[0].headers["x-api-key"] == "aws-api-key")
    #expect(requests[0].headers["anthropic-beta"] == "files-api-2025-04-14")
    #expect(requests[0].headers["user-agent"] == "ai-sdk-anthropic-aws/2.0.81")
    #expect(requests[1].url.absoluteString == "https://aws-external-anthropic.us-west-2.api.aws/v1/skills")
    #expect(requests[1].headers["anthropic-beta"] == "skills-2025-10-02")
    #expect(requests[1].headers["user-agent"] == "ai-sdk-anthropic-aws/2.0.81")
    #expect(requests[2].url.absoluteString == "https://aws-external-anthropic.us-west-2.api.aws/v1/skills/skill_aws/versions/v1")
    #expect(requests[2].headers["user-agent"] == "ai-sdk-anthropic-aws/2.0.81")
}