import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAI


private final class AIDefaultProviderStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var provider: (any AIProvider)?

    func set(_ provider: (any AIProvider)?) {
        lock.lock()
        self.provider = provider
        lock.unlock()
    }

    func get() -> (any AIProvider)? {
        lock.lock()
        defer { lock.unlock() }
        return provider
    }
}

public enum AIDefaultProvider {
    private static let storage = AIDefaultProviderStorage()

    public static func set(_ provider: (any AIProvider)?) {
        storage.set(provider)
    }

    public static func clear() {
        storage.set(nil)
    }

    public static func current() -> (any AIProvider)? {
        storage.get()
    }

    public static func resolved() throws -> any AIProvider {
        if let provider = storage.get() {
            return provider
        }
        return try AIProviders.gateway()
    }

    public static func resolveEvaluationModel(_ modelID: String) throws -> any AIEvaluationModelV4 {
        let provider = try resolved()
        guard let evaluationProvider = provider as? any AIEvaluationProvider else {
            throw AIEvaluationModelResolutionError.defaultProviderUnsupported(modelID: modelID)
        }
        return try validateEvaluationModelVersion(evaluationProvider.evaluationModel(modelID))
    }

    public static func resolveDecisionModel(_ modelID: String) throws -> any AIDecisionModelV4 {
        let provider = try resolved()
        guard let decisionProvider = provider as? any AIDecisionProvider else {
            throw AIDecisionModelResolutionError.defaultProviderUnsupported(modelID: modelID)
        }
        return try validateDecisionModelVersion(decisionProvider.decisionModel(modelID))
    }

    public static func withProvider<Result>(
        _ provider: any AIProvider,
        operation: () throws -> Result
    ) rethrows -> Result {
        let previous = storage.get()
        storage.set(provider)
        defer { storage.set(previous) }
        return try operation()
    }

    public static func withProvider<Result>(
        _ provider: any AIProvider,
        operation: () async throws -> Result
    ) async rethrows -> Result {
        let previous = storage.get()
        storage.set(provider)
        defer { storage.set(previous) }
        return try await operation()
    }
}