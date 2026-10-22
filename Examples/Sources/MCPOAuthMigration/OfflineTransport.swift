import Foundation
import SwiftAISDK

// This transport handles every request locally and has no network fallback.
actor OfflineOAuthTransport: AITransport {
    private let authentication: MigrationAuthentication
    private var discoveryCount = 0
    private var tokenCount = 0
    private var unexpectedRequestCount = 0

    init(authentication: MigrationAuthentication) { self.authentication = authentication }

    func send(_ request: AIHTTPRequest) async throws -> AIHTTPResponse {
        switch (request.method, request.url.absoluteString) {
        case ("GET", "https://resource.example.com/.well-known/oauth-protected-resource/mcp"):
            discoveryCount += 1
            return try response([
                "resource": .string(OfflineOAuth.serverURL.absoluteString),
                "authorization_servers": [.string(OfflineOAuth.issuer)]
            ])
        case ("GET", "https://auth.example.com/.well-known/oauth-authorization-server"):
            discoveryCount += 1
            return try response([
                "issuer": .string(OfflineOAuth.issuer),
                "authorization_endpoint": "https://auth.example.com/authorize",
                "token_endpoint": .string(OfflineOAuth.tokenURL.absoluteString),
                "response_types_supported": ["code"],
                "code_challenge_methods_supported": ["S256"],
                "grant_types_supported": ["authorization_code"],
                "token_endpoint_auth_methods_supported": [
                    .string(authentication == .clientSecret ? "client_secret_post" : "private_key_jwt")
                ]
            ])
        case ("POST", OfflineOAuth.tokenURL.absoluteString):
            try requireMigration(!request.followRedirects, "Token requests must not follow redirects.")
            let parameters = try formParameters(request)
            try requireMigration(parameters["grant_type"] == "authorization_code", "Expected a code exchange.")
            try requireMigration(parameters["code"] == OfflineOAuth.code, "Expected the offline callback code.")
            try requireMigration(parameters["code_verifier"]?.isEmpty == false, "Expected a saved PKCE verifier.")
            try requireMigration(parameters["client_id"] == OfflineOAuth.clientID, "Unexpected client identity.")
            try requireMigration(parameters["redirect_uri"] == OfflineOAuth.redirectURL.absoluteString, "Unexpected callback URI.")
            try requireMigration(parameters["resource"] == OfflineOAuth.serverURL.absoluteString, "Unexpected resource audience.")
            switch authentication {
            case .clientSecret:
                try requireMigration(parameters["client_secret"] == OfflineOAuth.clientSecret, "Missing mock client authentication.")
                try requireMigration(parameters["client_assertion"] == nil, "Unexpected custom authentication.")
            case .customAssertion:
                try requireMigration(parameters["client_secret"] == nil, "Custom authentication must not add a client secret.")
                try requireMigration(parameters["client_assertion"] == OfflineOAuth.assertion, "Missing mock custom authentication.")
                try requireMigration(parameters["client_assertion_type"] == "urn:ietf:params:oauth:client-assertion-type:jwt-bearer", "Unexpected assertion type.")
            }
            tokenCount += 1
            return try response(["access_token": .string(OfflineOAuth.accessToken), "token_type": "Bearer"])
        default:
            unexpectedRequestCount += 1
            // Keep error text free of URLs, request bodies, tokens, and secrets.
            throw MigrationCheckFailure(description: "The offline fixture received an unexpected request.")
        }
    }

    func verifyComplete() throws {
        // Discovery can catch transport errors while trying fallback URLs; make those failures observable here.
        try requireMigration(unexpectedRequestCount == 0, "Discovery attempted an unexpected offline route.")
        try requireMigration(discoveryCount == 4 && tokenCount == 1, "Expected two discovery rounds and one token exchange.")
    }

    private func response(_ body: JSONValue) throws -> AIHTTPResponse {
        AIHTTPResponse(statusCode: 200, headers: ["Content-Type": "application/json"], body: try JSONEncoder().encode(body))
    }

    private func formParameters(_ request: AIHTTPRequest) throws -> [String: String] {
        guard let body = request.body, let text = String(data: body, encoding: .utf8) else {
            throw MigrationCheckFailure(description: "Expected an encoded form body.")
        }
        var components = URLComponents()
        components.percentEncodedQuery = text
        var result: [String: String] = [:]
        for item in components.queryItems ?? [] {
            try requireMigration(result[item.name] == nil, "Unexpected duplicate form parameter.")
            result[item.name] = item.value ?? ""
        }
        return result
    }
}
