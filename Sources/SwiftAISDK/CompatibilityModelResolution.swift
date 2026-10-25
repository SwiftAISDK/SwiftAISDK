import SwiftAIProvider

func compatibilityResolveDecisionModel(_ reference: AIDecisionModelReference) throws -> any AIDecisionModelV4 {
    switch reference {
    case .model(let model): return model
    case .modelID(let id): return try AIDefaultProvider.resolveDecisionModel(id)
    }
}

func compatibilityResolveEvaluationModel(_ reference: AIEvaluationModelReference) throws -> any AIEvaluationModelV4 {
    switch reference {
    case .model(let model): return model
    case .modelID(let id): return try AIDefaultProvider.resolveEvaluationModel(id)
    }
}
