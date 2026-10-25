import SwiftAI

#if canImport(SwiftAISDK)
#error("The core consumer must not see the aggregate SDK")
#endif

struct EchoModel: LanguageModel {
    let providerID = "local"
    let modelID = "echo"
    func generate(_ request: LanguageModelRequest) async throws -> TextGenerationResult {
        try request.abortSignal?.throwIfAborted()
        return TextGenerationResult(text: request.messages.last?.combinedText ?? "", finishReason: "stop", rawValue: [:])
    }
}

@main struct CoreConsumer {
    static func main() async throws {
        let registry = createProviderRegistry([
            "local": AICustomProvider(languageModels: ["echo": EchoModel()], decisionModels: [:])
        ])
        let model = try registry.languageModel("local:echo")
        let result = try await AI.generateText(model: model, request: .init(messages: [.user("core-only")]), retryPolicy: .none)
        precondition(result.text == "core-only")
        precondition(result.responseMessages.count == 1)
        var text = ""
        for try await part in AI.streamText(model: model, request: .init(messages: [.user("stream-only")]), retryPolicy: .none) {
            if case let .textDeltaPart(_, delta, _) = part { text += delta }
        }
        precondition(text == "stream-only")
        let tool = AITool(name: "echo", parameters: ["type": "object"]) { $0 }
        let echoed = try await tool.execute(["value": "tool-only"])
        precondition(echoed == ["value": "tool-only"])
        let controller = AIAbortController()
        controller.abort(reason: "consumer cancelled")
        do {
            _ = try await AI.generateText(model: model, request: .init(messages: [.user("abort")], abortSignal: controller.signal), retryPolicy: .none)
            fatalError("Aborted generation succeeded")
        } catch is AIAbortError {}
        print("CORE CONSUMER VERIFIED: custom model, registry, generation, canonical stream, tool and abort")
    }
}
