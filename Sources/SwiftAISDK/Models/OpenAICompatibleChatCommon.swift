import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAI
func openAICompatibleChatTools(from tools: [String: JSONValue], normalizeSchemas: Bool, warnings: inout [AIWarning]) throws -> [JSONValue] {
    try SwiftAIOpenAICompatible.openAICompatibleChatTools(from: tools, normalizeSchema: normalizeSchemas ? normalizeOpenAIJSONSchema : nil, warnings: &warnings)
}
