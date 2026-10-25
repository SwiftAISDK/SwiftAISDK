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

@Test func perplexityLanguageStreamsParseErrorsAsErrorPartsLikeUpstream() async throws {
    let transport = RecordingTransport(response: sseResponse("""
    data: not-json

    data: [DONE]

    """))
    let provider = try AIProviders.perplexity(settings: ProviderSettings(apiKey: "pplx-key", transport: transport))
    let model = try provider.languageModel("sonar")

    var errors: [String] = []
    var finishReason: String?
    for try await part in model.stream(LanguageModelRequest(messages: [.user("Hi")])) {
        switch part {
        case let .error(message, _):
            errors.append(message)
        case let .finishMetadata(reason, _, _):
            finishReason = reason
        default:
            break
        }
    }

    #expect(errors.count == 1)
    #expect(finishReason == "error")
}
