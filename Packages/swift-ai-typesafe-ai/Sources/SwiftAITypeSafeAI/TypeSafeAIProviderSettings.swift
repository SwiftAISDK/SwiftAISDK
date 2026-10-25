import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public struct TypeSafeAIProviderSettings: Sendable {
    public var apiKey: String?
    public var baseURL: String?
    public var headers: [String: String]
    public var environment: [String: String]?
    public var transport: any AITransport
    public init(apiKey: String? = nil, baseURL: String? = nil, headers: [String: String] = [:],
                environment: [String: String]? = nil, transport: any AITransport = URLSessionTransport.shared) {
        self.apiKey = apiKey; self.baseURL = baseURL; self.headers = headers
        self.environment = environment; self.transport = transport
    }
}
