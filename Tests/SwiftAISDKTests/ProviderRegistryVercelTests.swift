@testable import SwiftAIXAI
@testable import SwiftAIGateway
@testable import SwiftAIAzure
@testable import SwiftAIQuiverAI
@testable import SwiftAIKlingAI
@testable import SwiftAIProdia
@testable import SwiftAIFireworks
@testable import SwiftAIDeepInfra
@testable import SwiftAIBaseten
@testable import SwiftAIMoonshotAI
@testable import SwiftAITogetherAI
@testable import SwiftAIFal
@testable import SwiftAIReplicate
@testable import SwiftAILuma
@testable import SwiftAIBlackForestLabs
@testable import SwiftAIByteDance
@testable import SwiftAIZAI
@testable import SwiftAIVercel
@testable import SwiftAIHuggingFace
@testable import SwiftAITypeSafeAI
@testable import SwiftAIMiniMax
@testable import SwiftAIElevenLabs
@testable import SwiftAICartesia
@testable import SwiftAIRevAI
@testable import SwiftAIGladia
@testable import SwiftAIAssemblyAI
@testable import SwiftAIAlibaba
@testable import SwiftAIDeepSeek
@testable import SwiftAIPerplexity
@testable import SwiftAILMNT
@testable import SwiftAIHume
@testable import SwiftAIDeepgram
@testable import SwiftAIMistral
@testable import SwiftAIGroq
@testable import SwiftAIVoyage
@testable import SwiftAICohere
@testable import SwiftAICerebras
@testable import SwiftAIAnthropicAWS
@testable import SwiftAIAmazonBedrock
@testable import SwiftAIGoogle
@testable import SwiftAIGoogleVertex
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

@Test func providerRegistryConstructsDiscoveredProvidersWithExplicitKeys() throws {
    let transport = RecordingTransport(response: jsonResponse("{}"))
    let settings = ProviderSettings(apiKey: "key", transport: transport)

    _ = try AIProviders.anthropicAWS(settings: AnthropicAWSProviderSettings(region: "us-east-1", workspaceID: "workspace", apiKey: "key", transport: transport))
    _ = try AIProviders.googleVertexMaaS(project: "project", settings: settings)
    _ = try AIProviders.googleVertexXAI(project: "project", settings: settings)
    _ = try AIProviders.googleVertexAnthropic(project: "project", settings: settings)
    _ = try AIProviders.mistral(settings: settings)
    _ = try AIProviders.miniMax(settings: MiniMaxProviderSettings(apiKey: "key", transport: transport))
    _ = try AIProviders.xAI(settings: settings)
    _ = try AIProviders.deepSeek(settings: settings)
    _ = try AIProviders.togetherAI(settings: settings)
    _ = try AIProviders.cohere(settings: settings)
    _ = try AIProviders.groq(settings: settings)
    _ = try AIProviders.perplexity(settings: settings)
    _ = try AIProviders.fireworks(settings: settings)
    _ = try AIProviders.amazonBedrock(settings: AmazonBedrockProviderSettings(region: "us-east-1", accessKeyID: "access", secretAccessKey: "secret", transport: transport))
    _ = try AIProviders.bedrockMantle(settings: AmazonBedrockProviderSettings(region: "us-east-1", accessKeyID: "access", secretAccessKey: "secret", transport: transport))
    _ = try AIProviders.googleVertex(settings: GoogleVertexProviderSettings(apiKey: "vertex-key", transport: transport))
    _ = try AIProviders.deepInfra(settings: settings)
    _ = try AIProviders.baseten(settings: settings)
    _ = try AIProviders.cerebras(settings: settings)
    _ = try AIProviders.cartesia(settings: CartesiaProviderSettings(apiKey: "key", environment: [:], transport: transport))
    _ = try AIProviders.vercel(settings: settings)
    _ = try AIProviders.alibaba(settings: settings)
    _ = try AIProviders.moonshotAI(settings: settings)
    _ = try AIProviders.huggingFace(settings: settings)
    _ = try AIProviders.replicate(settings: settings)
    _ = try AIProviders.fal(settings: settings)
    _ = try AIProviders.deepgram(settings: settings)
    _ = try AIProviders.assemblyAI(settings: settings)
    _ = try AIProviders.elevenLabs(settings: settings)
    _ = try AIProviders.revAI(settings: settings)
    _ = try AIProviders.gladia(settings: settings)
    _ = try AIProviders.hume(settings: settings)
    _ = try AIProviders.lmnt(settings: settings)
    _ = try AIProviders.blackForestLabs(settings: settings)
    _ = try AIProviders.prodia(settings: settings)
    _ = try AIProviders.luma(settings: settings)
    _ = try AIProviders.klingAI(settings: settings)
    _ = try AIProviders.byteDance(settings: settings)
    _ = try AIProviders.voyage(settings: settings)
    _ = try AIProviders.quiverAI(settings: settings)
    _ = try AIProviders.azure(resourceName: "resource", settings: settings)
    _ = try AIProviders.gateway(settings: settings)
    _ = try AIProviders.openResponses(name: "open-responses", url: "https://example.com/responses", settings: settings)
    _ = AIProviders.typeSafeAI(settings: settings)
    _ = AIProviders.zai(settings: settings)
}

@Test func providerRegistryExposesCanonicalFactoryNames() throws {
    let transport = RecordingTransport(response: jsonResponse("{}"))
    let settings = ProviderSettings(apiKey: "key", transport: transport)

    #expect(try AIProviders.openAI(settings: settings).providerID == "openai")
    #expect(try AIProviders.anthropicAWS(settings: AnthropicAWSProviderSettings(region: "us-east-1", workspaceID: "workspace", apiKey: "key", transport: transport)).providerID == "anthropic-aws")
    #expect(try AIProviders.openAICompatible(name: "compat", baseURL: "https://api.example.com", apiKey: "key", transport: transport).providerID == "compat")
    #expect(try AIProviders.xAI(settings: settings).providerID == "xai")
    #expect(try AIProviders.deepSeek(settings: settings).providerID == "deepseek")
    #expect(try AIProviders.togetherAI(settings: settings).providerID == "togetherai")
    #expect(try AIProviders.deepInfra(settings: settings).providerID == "deepinfra")
    #expect(try AIProviders.moonshotAI(settings: settings).providerID == "moonshotai")
    #expect(try AIProviders.miniMax(settings: MiniMaxProviderSettings(apiKey: "key", transport: transport)).providerID == "minimax")
    #expect(try AIProviders.huggingFace(settings: settings).providerID == "huggingface")
    #expect(try AIProviders.assemblyAI(settings: settings).providerID == "assemblyai")
    #expect(try AIProviders.elevenLabs(settings: settings).providerID == "elevenlabs")
    #expect(try AIProviders.revAI(settings: settings).providerID == "revai")
    #expect(try AIProviders.klingAI(settings: settings).providerID == "klingai")
    #expect(try AIProviders.byteDance(settings: settings).providerID == "bytedance")
    #expect(try AIProviders.quiverAI(settings: settings).providerID == "quiverai")
    #expect(try AIProviders.cartesia(settings: CartesiaProviderSettings(apiKey: "key", environment: [:], transport: transport)).providerID == "cartesia")
    #expect(try AIProviders.azure(resourceName: "resource", settings: settings).providerID == "azure")
    #expect(AIProviders.typeSafeAI(settings: settings).providerID == "typesafe")
    #expect(AIProviders.zai(settings: settings).providerID == "zai")
}

@Test func providerFactoryAliasesMirrorUpstreamNames() throws {
    let provider = try AIProviders.gateway(settings: ProviderSettings(apiKey: "gateway-key", transport: RecordingTransport(response: jsonResponse("{}"))))

    let language = try provider("openai/gpt-4.1-mini")
    let chat = try provider.chat("openai/gpt-4.1-mini")
    let embedding = try provider.embedding("openai/text-embedding-3-small")
    let textEmbeddingModel = try provider.textEmbeddingModel("openai/text-embedding-3-small")
    let textEmbedding = try provider.textEmbedding("openai/text-embedding-3-small")
    let image = try provider.image("openai/gpt-image-1")
    let transcription = try provider.transcription("openai/gpt-4o-transcribe")
    let speech = try provider.speech("openai/gpt-4o-mini-tts")
    let video = try provider.video("fal/minimax/hailuo-02/standard/text-to-video")
    let reranking = try provider.reranking("cohere/rerank-v3.5")

    #expect(language.providerID == "gateway")
    #expect(language.modelID == "openai/gpt-4.1-mini")
    #expect(chat.providerID == "gateway")
    #expect(embedding.providerID == "gateway")
    #expect(textEmbeddingModel.providerID == "gateway")
    #expect(textEmbedding.providerID == "gateway")
    #expect(image.providerID == "gateway")
    #expect(transcription.providerID == "gateway")
    #expect(speech.providerID == "gateway")
    #expect(video.providerID == "gateway")
    #expect(reranking.providerID == "gateway")
}
