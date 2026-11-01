import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public struct TypeSafeAIProviderSettings: Sendable {
    public var apiKey: String?
    /// Supplies a fresh API key immediately before each authenticated request.
    public var apiKeyProvider: (@Sendable () async throws -> String)?
    public var baseURL: String?
    public var headers: [String: String]
    public var environment: [String: String]?
    public var transport: any AITransport
    public init(apiKey: String? = nil, apiKeyProvider: (@Sendable () async throws -> String)? = nil, baseURL: String? = nil, headers: [String: String] = [:],
                environment: [String: String]? = nil, transport: any AITransport = URLSessionTransport.shared) {
        self.apiKey = apiKey; self.apiKeyProvider = apiKeyProvider; self.baseURL = baseURL; self.headers = headers
        self.environment = environment; self.transport = transport
    }
}
