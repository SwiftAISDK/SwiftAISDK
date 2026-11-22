@testable import SwiftAIVoyage
import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Testing

// Translated from packages/voyage/src/voyage-embedding-model.test.ts,
// reranking/voyage-reranking-model.test.ts and voyage-provider.test.ts.
// Fixtures are copied verbatim from __fixtures__.

private let voyageEmbeddingFixture = """
{
  "object": "list",
  "data": [
    {
      "object": "embedding",
      "embedding": [0.000344163, -0.022529466, 0.010127448, 0.063431956, 0.016145896],
      "index": 0,
      "text": null
    },
    {
      "object": "embedding",
      "embedding": [0.018987041, -0.029901529, -0.005134966, 0.082804598, -0.008740067],
      "index": 1,
      "text": null
    }
  ],
  "model": "voyage-3.5",
  "usage": {
    "total_tokens": 12
  }
}
"""

private let voyageRerankingFixture = """
{
  "object": "list",
  "data": [
    {
      "relevance_score": 0.5703125,
      "index": 1
    },
    {
      "relevance_score": 0.255859375,
      "index": 0
    }
  ],
  "model": "rerank-2.5",
  "usage": {
    "total_tokens": 12
  }
}
"""

private let testValues = ["sunny day at the beach", "rainy day in the city"]

private func voyageProvider(_ transport: RecordingTransport, headers: [String: String] = [:]) throws -> VoyageProvider {
    try AIProviders.voyage(configuration: VoyageProviderSettings(apiKey: "test-api-key", headers: headers, transport: transport))
}

private func requestBody(_ transport: RecordingTransport) async throws -> JSONValue {
    try decodeJSONBody(try #require(await transport.requests().first?.body))
}

@Suite("Voyage doEmbed (upstream)")
struct VoyageUpstreamEmbeddingTests {
    @Test(arguments: [
        (nil, nil, nil),
        (256, nil, 256),
        (nil, 512, 512),
        (256, 512, 512)
    ] as [(Int?, Int?, Int?)])
    func mapsDimensionsWithProviderOverride(dimensions: Int?, providerDimensions: Int?, expected: Int?) async throws {
        let transport = RecordingTransport(response: jsonResponse(voyageEmbeddingFixture))
        var voyage: [String: JSONValue] = [:]
        if let providerDimensions { voyage["outputDimension"] = .number(Double(providerDimensions)) }
        _ = try await voyageProvider(transport).embeddingModel("voyage-3.5").embed(EmbeddingRequest(
            values: testValues,
            dimensions: dimensions,
            providerOptions: ["voyage": .object(voyage)]
        ))
        let body = try await requestBody(transport)
        #expect(body["output_dimension"]?.intValue == expected)
    }

    @Test func extractsEmbedding() async throws {
        let transport = RecordingTransport(response: jsonResponse(voyageEmbeddingFixture))
        let result = try await voyageProvider(transport).embeddingModel("voyage-3.5").embed(EmbeddingRequest(values: testValues))
        #expect(result.embeddings == [
            [0.000344163, -0.022529466, 0.010127448, 0.063431956, 0.016145896],
            [0.018987041, -0.029901529, -0.005134966, 0.082804598, -0.008740067]
        ])
    }

    @Test func exposesTheRawResponse() async throws {
        let transport = RecordingTransport(response: jsonResponse(voyageEmbeddingFixture, headers: ["test-header": "test-value"]))
        let result = try await voyageProvider(transport).embeddingModel("voyage-3.5").embed(EmbeddingRequest(values: testValues))
        #expect(result.responseMetadata.headers["content-type"] == "application/json")
        #expect(result.responseMetadata.headers["test-header"] == "test-value")
        #expect(result.rawValue == (try decodeJSONBody(Data(voyageEmbeddingFixture.utf8))))
    }

    @Test func extractsUsage() async throws {
        let transport = RecordingTransport(response: jsonResponse(voyageEmbeddingFixture))
        let result = try await voyageProvider(transport).embeddingModel("voyage-3.5").embed(EmbeddingRequest(values: testValues))
        #expect(result.usage?.totalTokens == 12)
    }

    @Test func passesTheModelAndTheValues() async throws {
        let transport = RecordingTransport(response: jsonResponse(voyageEmbeddingFixture))
        _ = try await voyageProvider(transport).embeddingModel("voyage-3.5").embed(EmbeddingRequest(values: testValues))
        #expect(try await requestBody(transport) == .object([
            "input": .array(testValues.map(JSONValue.string)),
            "model": .string("voyage-3.5")
        ]))
    }

    @Test func passesTheInputTypeSetting() async throws {
        let transport = RecordingTransport(response: jsonResponse(voyageEmbeddingFixture))
        _ = try await voyageProvider(transport).embeddingModel("voyage-3.5").embed(EmbeddingRequest(
            values: testValues,
            providerOptions: ["voyage": .object(["inputType": .string("document")])]
        ))
        #expect(try await requestBody(transport) == .object([
            "input": .array(testValues.map(JSONValue.string)),
            "input_type": .string("document"),
            "model": .string("voyage-3.5")
        ]))
    }

    @Test func passesTheOutputDimensionSetting() async throws {
        let transport = RecordingTransport(response: jsonResponse(voyageEmbeddingFixture))
        _ = try await voyageProvider(transport).embeddingModel("voyage-3.5").embed(EmbeddingRequest(
            values: testValues,
            providerOptions: ["voyage": .object(["outputDimension": .number(256)])]
        ))
        #expect(try await requestBody(transport) == .object([
            "input": .array(testValues.map(JSONValue.string)),
            "model": .string("voyage-3.5"),
            "output_dimension": .number(256)
        ]))
    }

    @Test func passesHeaders() async throws {
        let transport = RecordingTransport(response: jsonResponse(voyageEmbeddingFixture))
        _ = try await voyageProvider(transport, headers: ["Custom-Provider-Header": "provider-header-value"])
            .embeddingModel("voyage-3.5")
            .embed(EmbeddingRequest(values: testValues, headers: ["Custom-Request-Header": "request-header-value"]))

        let headers = normalizeHeaders(try #require(await transport.requests().first).headers)
        #expect(headers["authorization"] == "Bearer test-api-key")
        #expect(headers["content-type"] == "application/json")
        #expect(headers["custom-provider-header"] == "provider-header-value")
        #expect(headers["custom-request-header"] == "request-header-value")
        #expect(headers["user-agent"]?.contains("ai-sdk-voyage/2.0.85") == true)
    }

    @Test func usesDetailAsTheErrorMessage() async throws {
        // voyage-error.ts: `errorToMessage: data => data.detail`.
        let body = #"{"detail":"Invalid model voyage-0"}"#
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 400, headers: ["content-type": "application/json"], body: Data(body.utf8)))
        do {
            _ = try await voyageProvider(transport).embeddingModel("voyage-0").embed(EmbeddingRequest(values: testValues))
            Issue.record("Expected an API call error")
        } catch let AIError.apiCall(error) {
            #expect(error.message == "Invalid model voyage-0")
            #expect(error.responseBody == body)
            #expect(error.statusCode == 400)
            #expect(error.isRetryable == false)
        }
    }
}

@Suite("Voyage doRerank (upstream)")
struct VoyageUpstreamRerankingTests {
    private func rerank(objects: Bool) async throws -> (RerankingResult, RecordingTransport) {
        let transport = RecordingTransport(response: jsonResponse(voyageRerankingFixture))
        let model = try voyageProvider(transport).rerankingModel("rerank-2.5")
        let request = objects
            ? RerankingRequest(
                query: "rainy day",
                documents: [["example": .string("sunny day at the beach")], ["example": .string("rainy day in the city")]],
                topK: 2
            )
            : RerankingRequest(query: "rainy day", documents: testValues, topK: 2)
        return (try await model.rerank(request), transport)
    }

    @Test func objectDocumentsSendStringifiedJSONDocuments() async throws {
        let (_, transport) = try await rerank(objects: true)
        #expect(try await requestBody(transport) == .object([
            "documents": .array([
                .string(#"{"example":"sunny day at the beach"}"#),
                .string(#"{"example":"rainy day in the city"}"#)
            ]),
            "model": .string("rerank-2.5"),
            "query": .string("rainy day"),
            "top_k": .number(2)
        ]))
    }

    @Test func objectDocumentsStringifyWithoutEscapingSlashes() async throws {
        // JSON.stringify never escapes `/`; Foundation does by default.
        let transport = RecordingTransport(response: jsonResponse(voyageRerankingFixture))
        _ = try await voyageProvider(transport).rerankingModel("rerank-2.5").rerank(RerankingRequest(
            query: "q",
            documents: [["url": .string("https://example.com/a/b")]]
        ))
        let body = try await requestBody(transport)
        #expect(body["documents"]?[0]?.stringValue == #"{"url":"https://example.com/a/b"}"#)
    }

    @Test(arguments: [true, false])
    func sendsRequestWithTheCorrectHeaders(objects: Bool) async throws {
        let (_, transport) = try await rerank(objects: objects)
        let headers = normalizeHeaders(try #require(await transport.requests().first).headers)
        #expect(headers["authorization"] == "Bearer test-api-key")
        #expect(headers["content-type"] == "application/json")
    }

    @Test func objectDocumentsReturnResultWithWarnings() async throws {
        let (result, _) = try await rerank(objects: true)
        #expect(result.warnings == [
            AIWarning(type: "compatibility", feature: "object documents", message: "Object documents are converted to strings.")
        ])
    }

    @Test func textDocumentsSendTextDocuments() async throws {
        let (_, transport) = try await rerank(objects: false)
        #expect(try await requestBody(transport) == .object([
            "documents": .array(testValues.map(JSONValue.string)),
            "model": .string("rerank-2.5"),
            "query": .string("rainy day"),
            "top_k": .number(2)
        ]))
    }

    @Test func textDocumentsReturnResultWithoutWarnings() async throws {
        let (result, _) = try await rerank(objects: false)
        #expect(result.warnings == [])
    }

    @Test(arguments: [true, false])
    func returnsResultWithTheCorrectRanking(objects: Bool) async throws {
        let (result, _) = try await rerank(objects: objects)
        #expect(result.results.map(\.index) == [1, 0])
        #expect(result.results.map(\.score) == [0.5703125, 0.255859375])
    }

    @Test(arguments: [true, false])
    func returnsResultWithTheCorrectResponseBody(objects: Bool) async throws {
        let (result, _) = try await rerank(objects: objects)
        #expect(result.rawValue == (try decodeJSONBody(Data(voyageRerankingFixture.utf8))))
        #expect(result.responseMetadata.headers["content-type"] == "application/json")
    }
}

@Suite("VoyageProvider (upstream)")
struct VoyageUpstreamProviderTests {
    @Test func createsEmbeddingModelWithCorrectProviderAndModelID() throws {
        let model = try voyageProvider(RecordingTransport(response: jsonResponse("{}"))).embeddingModel("voyage-3.5")
        #expect(model.modelID == "voyage-3.5")
        #expect(model.providerID == "voyage.embedding")
    }

    @Test func createsRerankingModelWithCorrectProviderAndModelID() throws {
        let model = try voyageProvider(RecordingTransport(response: jsonResponse("{}"))).rerankingModel("rerank-2.5")
        #expect(model.modelID == "rerank-2.5")
        #expect(model.providerID == "voyage.reranking")
    }

    @Test func throwsForLanguageAndImageModels() throws {
        let provider = try voyageProvider(RecordingTransport(response: jsonResponse("{}")))
        #expect(throws: AIError.unsupportedModel(provider: "voyage", capability: .language, modelID: "some-model")) {
            _ = try provider.languageModel("some-model")
        }
        #expect(throws: AIError.unsupportedModel(provider: "voyage", capability: .image, modelID: "some-model")) {
            _ = try provider.imageModel("some-model")
        }
    }
}
