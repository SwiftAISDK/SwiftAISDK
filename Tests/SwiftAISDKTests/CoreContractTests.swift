@testable import SwiftAIUI
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

@Test func coreUtilityHelpersMirrorAISDKSmallHelpers() async throws {
    #expect(try cosineSimilarity([1.0, 0.0], [0.0, 1.0]) == 0)
    #expect(abs(try cosineSimilarity([1.0, 1.0], [1.0, 1.0]) - 1) < 0.000_001)
    #expect(try cosineSimilarity([0.0, 0.0], [1.0, 1.0]) == 0)
    #expect(try cosineSimilarity([] as [Double], [] as [Double]) == 0)

    do {
        _ = try cosineSimilarity([1.0], [1.0, 2.0])
        Issue.record("Expected mismatched vector failure.")
    } catch let error as AIError {
        if case let .invalidArgument(argument, message) = error {
            #expect(argument == "vector1,vector2")
            #expect(message.contains("same length"))
        } else {
            Issue.record("Expected invalid argument error.")
        }
    }

    let generator = createIdGenerator(prefix: "msg", separator: "_", size: 8, alphabet: "a")
    let emptyPrefixGenerator = createIdGenerator(prefix: "", separator: "_", size: 4, alphabet: "b")
    let unprefixedGenerator = createIdGenerator(size: 4, alphabet: "c")
    #expect(generator() == "msg_aaaaaaaa")
    #expect(emptyPrefixGenerator() == "_bbbb")
    #expect(unprefixedGenerator() == "cccc")
    #expect(generateId().count == 16)

    var chunks: [String] = []
    for try await chunk in simulateReadableStream(
        chunks: ["a", "b"],
        initialDelayNanoseconds: nil,
        chunkDelayNanoseconds: nil
    ) {
        chunks.append(chunk)
    }
    #expect(chunks == ["a", "b"])

    let languageStream = simulateReadableStream(
        chunks: [
            LanguageStreamPart.textDelta("Hello "),
            LanguageStreamPart.textDelta("world"),
            LanguageStreamPart.finish(reason: "stop", usage: nil)
        ],
        initialDelayNanoseconds: nil,
        chunkDelayNanoseconds: nil
    )
    var smoothed: [LanguageStreamPart] = []
    for try await part in smoothStream(languageStream, delayNanoseconds: nil, chunking: .word) {
        smoothed.append(part)
    }
    #expect(smoothed == [
        .textStart(id: "legacy-text-0"),
        .textDeltaPart(id: "legacy-text-0", delta: "Hello "),
        .textDeltaPart(id: "legacy-text-0", delta: "world"),
        .textEnd(id: "legacy-text-0"),
        .finishMetadata(reason: "stop", usage: nil, providerMetadata: [:])
    ])
}

@Test func typedCoreErrorsExposeUsefulDiagnostics() throws {
    let apiError = AIAPICallError(
        provider: "mock",
        url: "https://api.example.test/v1",
        requestBody: ["prompt": "hello"],
        statusCode: 503,
        responseHeaders: ["Retry-After": "1"],
        responseBody: "try later"
    )
    #expect(apiError.isRetryable)
    #expect(apiError.description.contains("HTTP 503"))
    #expect(apiError.requestBody?["prompt"]?.stringValue == "hello")

    do {
        _ = try parseJSON(
            #"{"count":"many"}"#,
            schema: [
                "type": "object",
                "properties": ["count": ["type": "integer"]],
                "required": ["count"]
            ]
        )
        Issue.record("Expected type validation error.")
    } catch let error as AITypeValidationError {
        #expect(error.path == "$.count")
        #expect(error.message.contains("expected integer"))
    }

    let noOutput = AINoOutputError(provider: "mock", structuredOutputKind: .object)
    #expect(noOutput.description.contains("mock"))
    #expect(noOutput.description.contains("object"))

    let noContent = AINoOutputError(kind: .content)
    #expect(noContent.description == "No content was generated.")

    let tooManyEmbeddings = AITooManyEmbeddingValuesForCallError(
        provider: "mock",
        modelID: "embed",
        maxEmbeddingsPerCall: 1,
        values: ["a", "b"]
    )
    #expect(tooManyEmbeddings.description.contains("2 values were provided"))
}

@Test func resultTypesCarrySharedWarningsAndMetadataWithoutBreakingDefaults() {
    let response = AIResponseMetadata(id: "resp-1", modelID: "model-1", headers: ["x-request-id": "req-1"])
    let request = AIRequestMetadata(body: .object(["model": .string("model-1")]), headers: ["x-test": "1"])
    let providerMetadata: [String: JSONValue] = ["provider": .object(["detail": .string("kept")])]
    let warning = AIWarning(type: "unsupported", feature: "seed")

    let text = TextGenerationResult(
        text: "hello",
        rawValue: .object([:]),
        requestMetadata: request,
        responseMetadata: response
    )
    #expect(text.requestMetadata == request)
    #expect(text.responseMetadata == response)
    #expect(text.warnings.isEmpty)

    let embedding = EmbeddingResult(
        embeddings: [[0.1]],
        rawValue: .object([:]),
        warnings: [warning],
        providerMetadata: providerMetadata,
        requestMetadata: request,
        responseMetadata: response
    )
    #expect(embedding.warnings == [warning])
    #expect(embedding.providerMetadata == providerMetadata)
    #expect(embedding.requestMetadata == request)
    #expect(embedding.responseMetadata == response)

    let image = ImageGenerationResult(
        urls: ["https://example.com/image.png"],
        rawValue: .object([:]),
        warnings: [warning],
        usage: TokenUsage(inputTokens: 2),
        providerMetadata: providerMetadata,
        requestMetadata: request,
        responseMetadata: response
    )
    #expect(image.usage?.inputTokens == 2)
    #expect(image.providerMetadata == providerMetadata)
    #expect(image.requestMetadata == request)

    let transcription = TranscriptionResult(
        text: "hello",
        rawValue: .object([:]),
        segments: [TranscriptionSegment(text: "hello", startSecond: 0, endSecond: 1.2)],
        language: "en",
        durationInSeconds: 1.2,
        warnings: [warning],
        providerMetadata: providerMetadata,
        requestMetadata: request,
        responseMetadata: response
    )
    #expect(transcription.segments.first?.endSecond == 1.2)
    #expect(transcription.language == "en")
    #expect(transcription.requestMetadata == request)

    let speech = SpeechResult(audio: Data("audio".utf8), warnings: [warning], providerMetadata: providerMetadata, requestMetadata: request, responseMetadata: response)
    #expect(speech.warnings == [warning])
    #expect(speech.requestMetadata == request)

    let video = VideoGenerationResult(urls: [], rawValue: .object([:]), warnings: [warning], providerMetadata: providerMetadata, requestMetadata: request, responseMetadata: response)
    #expect(video.providerMetadata == providerMetadata)
    #expect(video.requestMetadata == request)

    let reranking = RerankingResult(results: [], rawValue: .object([:]), warnings: [warning], providerMetadata: providerMetadata, requestMetadata: request, responseMetadata: response)
    #expect(reranking.requestMetadata == request)
    #expect(reranking.responseMetadata == response)

    let file = FileUploadResult(providerReference: ["file": "file-1"], rawValue: .object([:]), warnings: [warning], providerMetadata: providerMetadata, requestMetadata: request, responseMetadata: response)
    #expect(file.providerMetadata == providerMetadata)
    #expect(file.warnings == [warning])
    #expect(file.requestMetadata == request)

    let skill = SkillUploadResult(providerReference: ["skill": "skill-1"], providerMetadata: providerMetadata, requestMetadata: request, responseMetadata: response, warnings: [warning], rawValue: .object([:]))
    #expect(skill.providerMetadata == providerMetadata)
    #expect(skill.requestMetadata == request)
    #expect(skill.responseMetadata == response)
    #expect(skill.warnings == [warning])
}
