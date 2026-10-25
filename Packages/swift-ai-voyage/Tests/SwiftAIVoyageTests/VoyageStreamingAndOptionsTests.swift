@testable import SwiftAIVoyage
import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Testing
import SwiftAI

@Test func voyageEmbeddingAndRerankingUseNativeEndpoints() async throws {
    let embeddingTransport = RecordingTransport(response: jsonResponse("""
    {"model":"voyage-3","data":[{"index":1,"embedding":[0.3,0.4]},{"index":0,"embedding":[0.1,0.2]}],"usage":{"total_tokens":9}}
    """))
    let embeddingProvider = try AIProviders.voyage(configuration: VoyageProviderSettings(apiKey: "voyage-key", transport: embeddingTransport))
    let embeddingModel = try embeddingProvider.embeddingModel("voyage-3")

    let embedding = try await embeddingModel.embed(EmbeddingRequest(values: ["a", "b"], dimensions: 256, extraBody: ["inputType": "query", "truncation": true, "outputDtype": "float"]))

    #expect(embedding.embeddings == [[0.1, 0.2], [0.3, 0.4]])
    #expect(embedding.usage?.totalTokens == 9)
    let embeddingRequest = try #require(await embeddingTransport.requests().first)
    #expect(embeddingRequest.url.absoluteString == "https://api.voyageai.com/v1/embeddings")
    #expect(embeddingRequest.headers["authorization"] == "Bearer voyage-key")
    #expect(embeddingRequest.headers["user-agent"] == "ai-sdk-voyage/2.0.68")
    let embeddingBody = try decodeJSONBody(try #require(embeddingRequest.body))
    #expect(embeddingBody["input"]?[0]?.stringValue == "a")
    #expect(embeddingBody["input_type"]?.stringValue == "query")
    #expect(embeddingBody["truncation"]?.boolValue == true)
    #expect(embeddingBody["output_dimension"]?.intValue == 256)
    #expect(embeddingBody["output_dtype"]?.stringValue == "float")

    let rerankTransport = RecordingTransport(response: jsonResponse(#"{"data":[{"index":0,"relevance_score":0.7},{"index":1,"relevance_score":0.2}],"usage":{"total_tokens":5}}"#))
    let rerankProvider = try AIProviders.voyage(configuration: VoyageProviderSettings(apiKey: "voyage-key", transport: rerankTransport))
    let rerankModel = try rerankProvider.rerankingModel("rerank-2.5")

    let reranking = try await rerankModel.rerank(RerankingRequest(query: "q", documents: ["a", "b"], topK: 2, extraBody: ["returnDocuments": true, "truncation": true]))

    #expect(reranking.results.map(\.score) == [0.7, 0.2])
    let rerankRequest = try #require(await rerankTransport.requests().first)
    #expect(rerankRequest.url.absoluteString == "https://api.voyageai.com/v1/rerank")
    #expect(rerankRequest.headers["user-agent"] == "ai-sdk-voyage/2.0.68")
    let rerankBody = try decodeJSONBody(try #require(rerankRequest.body))
    #expect(rerankBody["top_k"]?.intValue == 2)
    #expect(rerankBody["return_documents"]?.boolValue == true)
    #expect(rerankBody["returnDocuments"] == nil)
    #expect(rerankBody["truncation"]?.boolValue == true)
}

@Test func voyageEmbeddingAndRerankingAcceptNullishUsageLikeUpstreamV4() async throws {
    let embeddingTransport = RecordingTransport(response: jsonResponse("""
    {"model":"voyage-3.5","data":[{"index":1,"embedding":[0.3,0.4]},{"index":0,"embedding":[0.1,0.2]}],"usage":null}
    """))
    let embeddingProvider = try AIProviders.voyage(configuration: VoyageProviderSettings(apiKey: "voyage-key", transport: embeddingTransport))
    let embedding = try await embeddingProvider.embeddingModel("voyage-3.5").embed(EmbeddingRequest(values: ["a", "b"]))

    #expect(embedding.embeddings == [[0.1, 0.2], [0.3, 0.4]])
    #expect(embedding.usage?.totalTokens == 0)

    let rerankTransport = RecordingTransport(response: jsonResponse(#"{"data":[{"index":1,"relevance_score":0.57},{"index":0,"relevance_score":0.25}]}"#))
    let rerankProvider = try AIProviders.voyage(configuration: VoyageProviderSettings(apiKey: "voyage-key", transport: rerankTransport))
    let reranking = try await rerankProvider.rerankingModel("rerank-2.5").rerank(RerankingRequest(query: "q", documents: ["a", "b"], topK: 2))

    #expect(reranking.results.map(\.index) == [1, 0])
    #expect(reranking.results.map(\.score) == [0.57, 0.25])
}