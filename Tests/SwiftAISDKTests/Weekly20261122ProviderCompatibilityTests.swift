import Foundation
import SwiftAIProvider
import SwiftAITransport
import Testing
@testable import SwiftAISDK

@Suite struct Weekly20261122ProviderCompatibilityTests {
    @Test func liquidDecisionFactoryAndCapabilityWorkThroughTheUmbrella() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"answers":{"refund":{"type":"noul","noul":0.9}}}"#))
        let provider = SwiftAISDK.AIProviders.liquid(configuration: .init(apiKey: "test-key", environment: [:], transport: transport))
        #expect(AIProviderCapabilities.row(providerID: provider.providerID)?.supportedCapabilities == [.decision])
        let result = try await SwiftAISDK.AI.experimentalDecide(model: .model(provider.decisionModel("d1.2")),
            state: .text("Refund me."), questions: ["refund": .boolean(instructions: "Refund request?")])
        #expect(result.answers == ["refund": .boolean(probability: 0.9)])
        let requests = await transport.requests()
        #expect(requests.count == 1)
        #expect(requests.first?.url.absoluteString == "https://api.liquid.ai/decisions/v1/systemone")
        #expect(requests.first?.headers["authorization"] == "Bearer test-key")
    }

    @Test(arguments: [false, true])
    func assemblyAISpeechWorksOnBothFactories(useLegacyFactory: Bool) async throws {
        let transport = RecordingTransport(response: .init(statusCode: 200,
            headers: ["content-type": "audio/mpeg"], body: Data([1, 2, 3])))
        let provider: any AIProvider
        if useLegacyFactory {
            provider = try SwiftAISDK.AIProviders.assemblyAI(settings: .init(apiKey: "test-key", transport: transport))
        } else {
            provider = try SwiftAISDK.AIProviders.assemblyAI(configuration: .init(apiKey: "test-key", transport: transport))
        }
        #expect(AIProviderCapabilities.row(providerID: provider.providerID)?.supportedCapabilities == [.transcription, .speech])
        #expect(provider.supportedCapabilities == [.transcription, .speech])
        let result = try await provider.speechModel("assemblyai-tts-1").speak(.init(text: "Hello, world!"))
        #expect(result.audio == Data([1, 2, 3]))
        let request = try #require(await transport.requests().first)
        #expect(request.url.absoluteString == "https://tts.us.assemblyai.com/v1/speech")
        #expect(request.headers["authorization"] == "test-key")
        #expect(request.headers["user-agent"]?.contains("ai-sdk-assemblyai/3.0.85") == true)
        #expect(try decodeJSONBody(#require(request.body)) == [
            "model_id": "assemblyai-tts-1", "text": "Hello, world!", "encoding": "mp3", "stream": false
        ])
    }

    @Test(arguments: [false, true])
    func gatewayExtractionResolvesStringIDsThroughTheDefaultProvider(useAlias: Bool) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"answers":{"vendor":{"type":"text","value":"Acme"}},"usage":{"inputTokens":10,"outputTokens":2},"warnings":[]}"#))
        let provider = try SwiftAISDK.AIProviders.gateway(settings: .init(apiKey: "test-key", baseURL: "https://gateway.example", transport: transport))
        let result = try await AIDefaultProvider.withProvider(provider) {
            let fields = ["vendor": AIExtractionField(type: .text)]
            if useAlias {
                let custom = SwiftAISDK.AIProviders.customProvider(extractionModels: ["invoices": "scaledown/extract-1"])
                let model = try custom.extractionModel("invoices")
                return try await SwiftAISDK.AI.experimentalExtract(model: model, state: .text("Invoice from Acme."),
                    fields: fields, telemetry: .disabled)
            }
            return try await SwiftAISDK.AI.experimentalExtract(model: "scaledown/extract-1", state: .text("Invoice from Acme."),
                fields: fields, telemetry: .disabled)
        }
        #expect(result.answers["vendor"]?.value == "Acme")
        #expect(result.usage.totalTokens == 12)
        let requests = await transport.requests()
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.url.absoluteString == "https://gateway.example/extraction-model")
        #expect(request.headers["authorization"] == "Bearer test-key")
        #expect(request.headers["ai-model-id"] == "scaledown/extract-1")
        #expect(request.headers["ai-extraction-model-specification-version"] == "4")
        #expect(try decodeJSONBody(#require(request.body)) == [
            "stateParts": [["type": "text", "text": "Invoice from Acme."]],
            "fields": ["vendor": ["type": "text"]]
        ])
    }

    @Test func circularExtractionAliasesFailWithoutRecursiveResolution() {
        let custom = SwiftAISDK.AIProviders.customProvider(extractionModels: ["loop": "loop"])
        AIDefaultProvider.withProvider(custom) { () -> Void in
            #expect(throws: AIError.invalidArgument(argument: "model", message: "Circular extraction model alias: loop")) {
                _ = try AIDefaultProvider.resolveExtractionModel("loop")
            }
        }
    }

    @Test func typedBatchOutputIsAvailableThroughTheUmbrella() async throws {
        let provider = WeeklyTypedBatchProvider()
        let schema: JSONValue = ["type": "object", "properties": ["text": ["type": "string"]], "required": ["text"]]
        let output = Output.object(schema: schema, as: WeeklyBatchOutput.self)
        let started = try await SwiftAISDK.AI.startBatch(provider: provider, requests: [
            .text(.init(id: "request-1", modelID: "test-model", request: .init(messages: [.user("translate")])))
        ], output: output)
        #expect(await provider.responseFormat == .json(schema: schema))

        let results = try SwiftAISDK.AI.getBatchResults(provider: provider, batch: started.batch.reference, output: output)
        var iterator = results.makeAsyncIterator()
        let result = try #require(try await iterator.next())
        guard case let .text(.succeeded(id, value)) = result else {
            Issue.record("Expected one successful text item")
            return
        }
        #expect(id == "request-1")
        #expect(value.generation.text == #"{"text":"hello"}"#)
        #expect(value.output == WeeklyBatchOutput(text: "hello"))
        #expect(value.outputError == nil)
        #expect(try await iterator.next() == nil)
    }
}

private struct WeeklyBatchOutput: Codable, Sendable, Equatable {
    let text: String
}

private actor WeeklyTypedBatchProvider: AIBatchProvider {
    nonisolated let providerID = "test-provider"
    private(set) var responseFormat: AIResponseFormat?

    func startBatch(_ options: AIBatchStartOptions<AIBatchRequest>) async throws -> AIBatchStartResult {
        if case let .text(text)? = options.requests.first {
            responseFormat = text.request.responseFormat
        }
        return .init(batchID: "batch-123", status: .init(status: .pending))
    }

    func getBatchStatus(_ options: AIBatchOperationOptions) async throws -> AIBatchStatus {
        .init(status: .completed)
    }

    func getBatchResults(_ options: AIBatchOperationOptions) async throws -> AsyncThrowingStream<AIBatchV4ItemResult, Error> {
        let text = #"{"text":"hello"}"#
        return AsyncThrowingStream { continuation in
            continuation.yield(.text(.succeeded(id: "request-1", result: .init(text: text,
                content: [.text(text)], finishReason: "stop", rawValue: [:]))))
            continuation.finish()
        }
    }
}
