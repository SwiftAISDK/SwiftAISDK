import SwiftAI
import SwiftAIProvider



/// Source-compatible factory retained from SwiftAISDK 1.7.0.
public func customProvider(
    providerID: String = "custom",
    languageModels: [String: any LanguageModel] = [:],
    embeddingModels: [String: any EmbeddingModel] = [:],
    imageModels: [String: any ImageModel] = [:],
    transcriptionModels: [String: any TranscriptionModel] = [:],
    speechModels: [String: any SpeechModel] = [:],
    videoModels: [String: any VideoModel] = [:],
    rerankingModels: [String: any RerankingModel] = [:],
    files: (any AIFileClient)? = nil,
    skills: (any AISkillsClient)? = nil,
    fallbackProvider: (any AIProvider)? = nil
) -> AICustomProvider {
    customProvider(
        providerID: providerID,
        languageModels: languageModels,
        embeddingModels: embeddingModels,
        imageModels: imageModels,
        transcriptionModels: transcriptionModels,
        speechModels: speechModels,
        videoModels: videoModels,
        rerankingModels: rerankingModels,
        evaluationModels: [String: AIEvaluationModelReference](),
        files: files,
        skills: skills,
        fallbackProvider: fallbackProvider
    )
}


public func customProvider(
    providerID: String = "custom",
    languageModels: [String: any LanguageModel] = [:],
    embeddingModels: [String: any EmbeddingModel] = [:],
    imageModels: [String: any ImageModel] = [:],
    transcriptionModels: [String: any TranscriptionModel] = [:],
    speechModels: [String: any SpeechModel] = [:],
    videoModels: [String: any VideoModel] = [:],
    rerankingModels: [String: any RerankingModel] = [:],
    evaluationModels: [String: AIEvaluationModelReference] = [:],
    files: (any AIFileClient)? = nil,
    skills: (any AISkillsClient)? = nil,
    fallbackProvider: (any AIProvider)? = nil
) -> AICustomProvider {
    AICustomProvider(
        providerID: providerID,
        languageModels: languageModels,
        embeddingModels: embeddingModels,
        imageModels: imageModels,
        transcriptionModels: transcriptionModels,
        speechModels: speechModels,
        videoModels: videoModels,
        rerankingModels: rerankingModels,
        evaluationModels: evaluationModels,
        files: files,
        skills: skills,
        fallbackProvider: fallbackProvider
    )
}


public func customProvider(
    providerID: String = "custom",
    languageModels: [String: any LanguageModel] = [:],
    embeddingModels: [String: any EmbeddingModel] = [:],
    imageModels: [String: any ImageModel] = [:],
    transcriptionModels: [String: any TranscriptionModel] = [:],
    speechModels: [String: any SpeechModel] = [:],
    videoModels: [String: any VideoModel] = [:],
    rerankingModels: [String: any RerankingModel] = [:],
    evaluationModels: [String: any AIEvaluationModelV4],
    files: (any AIFileClient)? = nil,
    skills: (any AISkillsClient)? = nil,
    fallbackProvider: (any AIProvider)? = nil
) -> AICustomProvider {
    AICustomProvider(
        providerID: providerID,
        languageModels: languageModels,
        embeddingModels: embeddingModels,
        imageModels: imageModels,
        transcriptionModels: transcriptionModels,
        speechModels: speechModels,
        videoModels: videoModels,
        rerankingModels: rerankingModels,
        evaluationModels: evaluationModels,
        files: files,
        skills: skills,
        fallbackProvider: fallbackProvider
    )
}



public func customProvider(
    providerID: String = "custom",
    languageModels: [String: any LanguageModel] = [:],
    decisionModels: [String: AIDecisionModelReference],
    fallbackProvider: (any AIProvider)? = nil
) -> AICustomProvider {
    AICustomProvider(providerID: providerID, languageModels: languageModels, decisionModels: decisionModels, fallbackProvider: fallbackProvider)
}
