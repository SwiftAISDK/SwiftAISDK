import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public struct GMICloudProviderSettings: Sendable {
    public var apiKey: String?
    public var baseURL: String?
    public var headers: [String: String]
    public var queryParams: [String: String]
    public var environment: [String: String]?
    public var transport: any AITransport
    public var supportsStructuredOutputs: Bool
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public init(apiKey: String? = nil, baseURL: String? = nil, headers: [String: String] = [:],
                queryParams: [String: String] = [:], environment: [String: String]? = nil,
                transport: any AITransport = URLSessionTransport.shared,
                supportsStructuredOutputs: Bool = false,
                transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil) {
        self.apiKey = apiKey; self.baseURL = baseURL; self.headers = headers
        self.queryParams = queryParams; self.environment = environment; self.transport = transport
        self.supportsStructuredOutputs = supportsStructuredOutputs
        self.transformRequestBody = transformRequestBody
    }
    func environmentValue(_ names: [String]) -> String? {
        if let environment { return names.lazy.compactMap { environment[$0] }.first }
        return SwiftAITransport.environmentValue(names)
    }
}
