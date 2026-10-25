@testable import SwiftAIFal
@testable import SwiftAIAnthropic
@testable import SwiftAIOpenAICompatible
@testable import SwiftAIOpenAI
@testable import SwiftAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
private typealias AI = SwiftAISDK.AI
private typealias AIProviders = SwiftAISDK.AIProviders
private typealias AICustomProvider = SwiftAISDK.AICustomProvider
import Foundation
import Testing
@testable import SwiftAISDK

@Test func openResponsesProviderPreservesFileNamesAndRichToolResultContentLikeUpstream() async throws {
    let transport = RecordingTransport(response: jsonResponse(#"{"id":"resp-1","status":"completed","output_text":"ok"}"#))
    let provider = try AIProviders.openResponses(
        name: "open-responses",
        url: "https://open.example.test/responses",
        settings: ProviderSettings(apiKey: "open-key", transport: transport)
    )
    let model = try provider.languageModel("local-model")
    let pdf = Data("pdf".utf8)
    let imageBytes = Data([0x89, 0x50, 0x4E, 0x47])

    let result = try await model.generate(LanguageModelRequest(messages: [
        AIMessage(role: .user, content: [
            .text("Use files."),
            .file(mimeType: "application/pdf", data: pdf, filename: "brief.pdf"),
            .data(mimeType: "application/pdf", data: pdf),
            .file(mimeType: "image/png", data: imageBytes, filename: "ignored-image-name.png")
        ]),
        AIMessage(role: .assistant, content: [
            .toolCall(AIToolCall(id: "call-1", name: "lookup", arguments: #"{"query":"docs"}"#))
        ]),
        .toolResponses(toolResults: [
            AIToolResult(
                toolCallID: "call-1",
                toolName: "lookup",
                result: ["raw": "fallback"],
                modelOutput: [
                    "type": "content",
                    "value": [
                        ["type": "text", "text": "found"],
                        ["type": "image-data", "mediaType": "image/png", "data": "base64-image"],
                        ["type": "image-url", "url": "https://example.com/plot.png"],
                        ["type": "file-data", "mediaType": "application/pdf", "filename": "result.pdf", "data": "base64-pdf"],
                        [
                            "type": "file",
                            "mediaType": "image/png",
                            "filename": "canonical-image.png",
                            "data": ["type": "data", "data": "base64-canonical-image"]
                        ],
                        [
                            "type": "file",
                            "mediaType": "image/png",
                            "data": ["type": "url", "url": "https://example.com/canonical-image.png"]
                        ],
                        [
                            "type": "file",
                            "mediaType": "application/pdf",
                            "filename": "canonical.pdf",
                            "data": ["type": "data", "data": "base64-canonical-pdf"]
                        ],
                        [
                            "type": "file",
                            "mediaType": "application/pdf",
                            "filename": "referenced.pdf",
                            "data": [
                                "type": "reference",
                                "reference": ["open-responses": "file_canonical_pdf"]
                            ]
                        ],
                        [
                            "type": "file",
                            "mediaType": "text/plain",
                            "filename": "inline.txt",
                            "data": ["type": "text", "text": "inline text"]
                        ],
                        ["type": "video-data", "data": "unsupported"]
                    ]
                ]
            )
        ])
    ]))

    #expect(result.text == "ok")
    #expect(result.warnings == [AIWarning(type: "other", message: "unsupported tool content part type: video-data")])
    let body = try decodeJSONBody(try #require((await transport.requests()).first?.body))
    let firstContent = try #require(body["input"]?[0]?["content"]?.arrayValue)
    #expect(firstContent[1]["type"]?.stringValue == "input_file")
    #expect(firstContent[1]["filename"]?.stringValue == "brief.pdf")
    #expect(firstContent[1]["file_data"]?.stringValue == "data:application/pdf;base64,\(pdf.base64EncodedString())")
    #expect(firstContent[2]["type"]?.stringValue == "input_file")
    #expect(firstContent[2]["filename"]?.stringValue == "data")
    #expect(firstContent[3]["type"]?.stringValue == "input_image")
    #expect(firstContent[3]["image_url"]?.stringValue == "data:image/png;base64,\(imageBytes.base64EncodedString())")

    #expect(body["input"]?[1]?["type"]?.stringValue == "function_call")
    #expect(body["input"]?[1]?["call_id"]?.stringValue == "call-1")
    let toolOutput = try #require(body["input"]?[2]?["output"]?.arrayValue)
    #expect(toolOutput.map { $0["type"]?.stringValue } == [
        "input_text",
        "input_image",
        "input_image",
        "input_file",
        "input_image",
        "input_image",
        "input_file",
        "input_file",
        "input_file"
    ])
    #expect(toolOutput[0]["text"]?.stringValue == "found")
    #expect(toolOutput[1]["image_url"]?.stringValue == "data:image/png;base64,base64-image")
    #expect(toolOutput[2]["image_url"]?.stringValue == "https://example.com/plot.png")
    #expect(toolOutput[3]["filename"]?.stringValue == "result.pdf")
    #expect(toolOutput[3]["file_data"]?.stringValue == "data:application/pdf;base64,base64-pdf")
    #expect(toolOutput[4]["image_url"]?.stringValue == "data:image/png;base64,base64-canonical-image")
    #expect(toolOutput[5]["image_url"]?.stringValue == "https://example.com/canonical-image.png")
    #expect(toolOutput[6]["filename"]?.stringValue == "canonical.pdf")
    #expect(toolOutput[6]["file_data"]?.stringValue == "data:application/pdf;base64,base64-canonical-pdf")
    #expect(toolOutput[7]["filename"] == nil)
    #expect(toolOutput[7]["file_id"]?.stringValue == "file_canonical_pdf")
    #expect(toolOutput[8]["filename"]?.stringValue == "inline.txt")
    #expect(toolOutput[8]["file_data"]?.stringValue == "data:text/plain;base64,\(Data("inline text".utf8).base64EncodedString())")
}

@Test func openResponsesProviderUsesUpstreamExecutionDeniedDefaultMessage() async throws {
    let transport = RecordingTransport(response: jsonResponse(#"{"id":"resp-1","status":"completed","output_text":"ok"}"#))
    let provider = try AIProviders.openResponses(
        name: "open-responses",
        url: "https://open.example.test/responses",
        settings: ProviderSettings(apiKey: "open-key", transport: transport)
    )
    let model = try provider.languageModel("local-model")

    _ = try await model.generate(LanguageModelRequest(messages: [
        AIMessage(role: .assistant, content: [
            .toolCall(AIToolCall(id: "call-1", name: "lookup", arguments: "{}"))
        ]),
        .toolResponses(toolResults: [
            AIToolResult(
                toolCallID: "call-1",
                toolName: "lookup",
                result: ["type": "execution-denied"]
            )
        ])
    ]))

    let body = try decodeJSONBody(try #require((await transport.requests()).first?.body))
    #expect(body["input"]?[1]?["type"]?.stringValue == "function_call_output")
    #expect(body["input"]?[1]?["output"]?.stringValue == "Tool call execution denied.")
}

@Test func openResponsesProviderMapsFinishReasonsLikeUpstream() async throws {
    let transport = RecordingTransport(responses: [
        jsonResponse(#"{"id":"resp-tool","status":"completed","output":[{"type":"function_call","id":"fc_1","call_id":"call_1","name":"lookup","arguments":"{\"query\":\"weather\"}"}],"usage":{"input_tokens":1,"output_tokens":2,"total_tokens":3}}"#),
        jsonResponse(#"{"id":"resp-length","status":"incomplete","incomplete_details":{"reason":"max_output_tokens"},"output":[{"type":"function_call","id":"fc_2","call_id":"call_2","name":"lookup","arguments":"{}"}],"usage":{"input_tokens":1,"output_tokens":2,"total_tokens":3}}"#),
        jsonResponse(#"{"id":"resp-filter","status":"incomplete","incomplete_details":{"reason":"content_filter"},"output":[{"type":"message","content":[{"text":"blocked"}]}],"usage":{"input_tokens":1,"output_tokens":2,"total_tokens":3}}"#)
    ])
    let provider = try AIProviders.openResponses(
        name: "open-responses",
        url: "https://open.example.test/responses",
        settings: ProviderSettings(apiKey: "open-key", transport: transport)
    )
    let model = try provider.languageModel("local-model")

    let toolResult = try await model.generate(LanguageModelRequest(messages: [.user("Use a tool.")]))
    let lengthResult = try await model.generate(LanguageModelRequest(messages: [.user("Use a tool.")]))
    let filterResult = try await model.generate(LanguageModelRequest(messages: [.user("Say something.")]))

    #expect(toolResult.text == "")
    #expect(toolResult.toolCalls.first?.id == "call_1")
    #expect(toolResult.finishReason == "tool-calls")
    #expect(lengthResult.finishReason == "length")
    #expect(filterResult.finishReason == "content-filter")
}
@Test func openResponsesProviderStreamsFinishReasonsLikeUpstream() async throws {
    let toolTransport = RecordingTransport(response: sseResponse("""
    data: {"type":"response.output_item.added","output_index":0,"item":{"type":"function_call","id":"fc_1","call_id":"call_1","name":"lookup","arguments":""}}

    data: {"type":"response.function_call_arguments.delta","item_id":"fc_1","output_index":0,"delta":"{}"}

    data: {"type":"response.output_item.done","output_index":0,"item":{"type":"function_call","id":"fc_1","call_id":"call_1","name":"lookup","arguments":"{}"}}

    data: {"type":"response.completed","response":{"status":"completed","usage":{"input_tokens":1,"output_tokens":2,"total_tokens":3}}}

    """))
    let toolProvider = try AIProviders.openResponses(
        name: "open-responses",
        url: "https://open.example.test/responses",
        settings: ProviderSettings(apiKey: "open-key", transport: toolTransport)
    )
    let toolModel = try toolProvider.languageModel("local-model")

    var toolCall: AIToolCall?
    var toolFinishReason: String?
    for try await part in toolModel.stream(LanguageModelRequest(messages: [.user("Use a tool.")])) {
        switch part {
        case let .toolCall(call):
            toolCall = call
        case let .finishMetadata(reason, _, _):
            toolFinishReason = reason
        default:
            break
        }
    }

    #expect(toolCall?.id == "call_1")
    #expect(toolFinishReason == "tool-calls")

    let failedTransport = RecordingTransport(response: sseResponse("""
    data: {"type":"response.failed","response":{"status":"failed","error":{"code":"server_error","message":"Nope"},"usage":{"input_tokens":1,"output_tokens":0,"total_tokens":1}}}

    """))
    let failedProvider = try AIProviders.openResponses(
        name: "open-responses",
        url: "https://open.example.test/responses",
        settings: ProviderSettings(apiKey: "open-key", transport: failedTransport)
    )
    let failedModel = try failedProvider.languageModel("local-model")

    var failedFinishReason: String?
    var failedTotalTokens: Int?
    for try await part in failedModel.stream(LanguageModelRequest(messages: [.user("Fail.")])) {
        if case let .finishMetadata(reason, usage, _) = part {
            failedFinishReason = reason
            failedTotalTokens = usage?.totalTokens
        }
    }

    #expect(failedFinishReason == "error")
    #expect(failedTotalTokens == 1)
}
