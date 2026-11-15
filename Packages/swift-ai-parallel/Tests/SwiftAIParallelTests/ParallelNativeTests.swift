import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
import SwiftAIParallel

@Suite("Parallel Swift integration supplements")
struct ParallelNativeTests {
    @Test func typedOptionsMetadataAndCatalog() async throws {
        #expect(ParallelDecisionModelOptions(includeExcerpts: false).providerOptions == ["parallel": ["includeExcerpts": false]])
        #expect(ParallelDecisionModelOptions().providerOptions == ["parallel": [:]])
        #expect(parallelDecisionModelIDs == ["fast"])
        #expect(parallelSupportedQuestionTypes == [.boolean, .choice, .score])
        #expect(getParallelDecisionModelEntry("fast").providerOptions?[.decision]?["includeExcerpts"] == .supported)
        #expect(getParallelDecisionModelEntry("future").providerOptions?[.decision]?["includeExcerpts"] == .unknown)
        #expect(getParallelDecisionModelEntry("future").capabilities.decision?.questionTypes.box == .unsupported)
        #expect(parallelProviderOptions[.decision]?["includeExcerpts"]?.description == "Include evidence excerpts in citations. Defaults to true.")
        let (_, model, provider) = try parallelSetup()
        let result = try await model.doDecide(parallelOptions())
        let metadata = try JSONDecoder().decode(ParallelDecisionProviderMetadata.self,
            from: JSONEncoder().encode(result.providerMetadata["parallel"]!))
        #expect(metadata.citations.count == 3)
        #expect(metadata.citations[2].title == nil)
        #expect(metadata.decisionID == "decisions_1234567890abcdef1234567890abcdef")
        #expect(provider.supportedCapabilities == [.decision])
        #expect(model.specificationVersion == "v4")
        #expect(try AIProviders.parallel(configuration: .init(apiKey: "test-key")).decision("fast").modelID == "fast")
    }

    @Test func headerOverridesPreserveCallPrecedenceAndVersionSuffix() async throws {
        let transport = try ParallelRecordingTransport()
        let model = try createParallel(configuration: .init(apiKey: "original", headers: [
            "X-API-KEY": "provider-key", "User-Agent": "custom-client", "x-level": "provider"
        ], transport: transport)).decision("fast")
        var options = parallelOptions(); options.headers = ["X-API-KEY": "call-key", "x-level": "call"]
        _ = try await model.doDecide(options)
        let request = try #require(await transport.requests().first)
        #expect(request.headers["x-api-key"] == "call-key")
        #expect(request.headers["x-level"] == "call")
        #expect(request.headers["user-agent"] == "custom-client ai-sdk-parallel/3.0.9")
    }

    @Test func missingCredentialsAndAbortedCallsPerformNoIO() async throws {
        let transport = try ParallelRecordingTransport()
        let model = try createParallel(configuration: .init(environment: [:], transport: transport)).decision("fast")
        await #expect(throws: AIError.missingAPIKey(provider: "parallel", environmentVariables: ["PARALLEL_API_KEY"])) {
            try await model.doDecide(parallelOptions())
        }
        let controller = AIAbortController(); controller.abort(reason: "cancelled")
        var options = parallelOptions(); options.abortSignal = controller.signal
        await #expect(throws: AIAbortError(reason: "cancelled")) { try await model.doDecide(options) }
        #expect(await transport.requests().isEmpty)
    }

    @Test func asyncCredentialsResolvePerRequest() async throws {
        actor Keys { var count = 0; func next() -> String { count += 1; return "key-\(count)" } }
        let keys = Keys(), transport = try ParallelRecordingTransport()
        let model = try createParallel(configuration: .init(apiKeyProvider: { await keys.next() }, transport: transport)).decision("fast")
        _ = try await model.doDecide(parallelOptions())
        _ = try await model.doDecide(parallelOptions())
        let requests = await transport.requests()
        #expect(requests.map { $0.headers["x-api-key"] } == ["key-1", "key-2"])
    }

    @Test func validatesEntireResponseSchemaAndPreservesUnknownRawFields() async throws {
        let invalid: [JSONValue] = [
            replacingParallelFixture("usage", with: ["input_tokens": -1, "output_tokens": 0]),
            replacingParallelFixture("usage", with: ["input_tokens": 1.5, "output_tokens": 0]),
            replacingParallelFixture("usage", with: ["input_tokens": 10, "output_tokens": 1]),
            replacingParallelFixture("mode", with: .null),
            replacingParallelFixture("decision_id", with: 123),
            replacingParallelFixture("citations", with: [["url": "url", "title": 5, "excerpts": []]]),
            replacingParallelAnswer("availability", with: ["type": "choice", "choice": "available", "probabilities": ["available": -0.1]]),
            replacingParallelAnswer("fit", with: ["type": "score", "score": 1, "legend": ["0": 1], "probabilities": [:]])
        ]
        for body in invalid {
            let (_, model, _) = try parallelSetup(body: body)
            await #expect(throws: AIError.self) { try await model.doDecide(parallelOptions()) }
        }
        let raw = replacingParallelFixture("future", with: "retained")
        let result = try await parallelSetup(body: raw).model.doDecide(parallelOptions())
        #expect(result.response?.body?["future"] == "retained")
    }
}
