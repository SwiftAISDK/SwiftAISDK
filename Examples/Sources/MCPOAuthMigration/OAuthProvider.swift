import Foundation
import SwiftAISDK

enum MigrationAuthentication: String, CaseIterable, Sendable {
    case clientSecret = "issuer-bound client secret"
    case customAssertion = "stored-binding custom authentication"
}

// All values are inert fixtures. This example never reads credentials or opens a network connection.
enum OfflineOAuth {
    static let issuer = "https://auth.example.com"
    static let serverURL = URL(string: "https://resource.example.com/mcp")!
    static let tokenURL = URL(string: "https://auth.example.com/token")!
    static let redirectURL = URL(string: "http://localhost:3000/callback")!
    static let clientID = "offline-example-client"
    static let clientSecret = "offline-dummy-secret"
    static let assertion = "offline-dummy-assertion-not-a-signed-jwt"
    static let code = "offline-dummy-code"
    static let accessToken = "offline-dummy-access-token"
    static let binding = MCPOAuthAuthorizationServerInformation(
        authorizationServerURL: URL(string: issuer)!,
        tokenEndpoint: tokenURL,
        issuer: issuer
    )
}

struct MigrationCheckFailure: Error, CustomStringConvertible {
    let description: String
}

func requireMigration(_ condition: Bool, _ message: String) throws {
    guard condition else { throw MigrationCheckFailure(description: message) }
}

// In an application, persist these values in the account's secure store across the browser round trip.
actor MigrationOAuthProvider: MCPOAuthClientProvider {
    nonisolated let redirectURL = OfflineOAuth.redirectURL
    nonisolated let clientMetadata = MCPOAuthClientMetadata(redirectURIs: [OfflineOAuth.redirectURL])
    // Swift cannot detect an override of authenticateTokenRequest. Declare the capability explicitly.
    nonisolated let usesCustomClientAuthentication: Bool

    private var client: MCPOAuthClientInformation?
    private var serverInformation: MCPOAuthAuthorizationServerInformation?
    private var currentTokens: MCPOAuthTokens?
    private var verifier: String?
    private var expectedState: String?
    private(set) var authorizationURL: URL?

    init(authentication: MigrationAuthentication) {
        usesCustomClientAuthentication = authentication == .customAssertion
        if authentication == .clientSecret {
            // Obtain the issuer from the existing credential registration or trusted app configuration.
            client = MCPOAuthClientInformation(
                clientID: OfflineOAuth.clientID,
                clientSecret: OfflineOAuth.clientSecret,
                issuer: OfflineOAuth.issuer
            )
        } else {
            client = MCPOAuthClientInformation(clientID: OfflineOAuth.clientID)
            // Alternative: restore a binding established with these credentials previously.
            serverInformation = OfflineOAuth.binding
        }
    }

    func clientInformation() async throws -> MCPOAuthClientInformation? { client }
    func saveClientInformation(_ information: MCPOAuthClientInformation) async throws { client = information }
    func authorizationServerInformation() async throws -> MCPOAuthAuthorizationServerInformation? { serverInformation }
    func saveAuthorizationServerInformation(_ information: MCPOAuthAuthorizationServerInformation) async throws {
        serverInformation = information
    }
    func tokens() async throws -> MCPOAuthTokens? { currentTokens }
    func saveTokens(_ tokens: MCPOAuthTokens) async throws { currentTokens = tokens }
    func state() async throws -> String? { UUID().uuidString }
    func saveState(_ state: String) async throws { expectedState = state }
    func storedState() async throws -> String? { expectedState }
    func saveCodeVerifier(_ codeVerifier: String) async throws { verifier = codeVerifier }
    func codeVerifier() async throws -> String {
        guard let verifier else { throw MigrationCheckFailure(description: "Start authorization before handling a callback.") }
        return verifier
    }
    func redirectToAuthorization(_ authorizationURL: URL) async throws {
        // A real app opens its authorization session here; this offline example only records the URL.
        self.authorizationURL = authorizationURL
    }

    func invalidateCredentials(_ scope: MCPOAuthCredentialScope) async {
        invalidate(scope)
    }

    func invalidateCredentials(_ scope: MCPOAuthCredentialScope, context: MCPOAuthCredentialInvalidationContext?) async {
        // Keep comparison and deletion in one actor operation so an older refresh cannot erase newer tokens.
        if let context, currentTokens != context.tokens { return }
        invalidate(scope)
    }

    private func invalidate(_ scope: MCPOAuthCredentialScope) {
        if scope == .tokens || scope == .all { currentTokens = nil }
        if scope == .client || scope == .all { client = nil }
        if scope == .verifier || scope == .all { verifier = nil }
        if scope == .all {
            serverInformation = nil
            expectedState = nil
            authorizationURL = nil
        }
    }

    func authenticateTokenRequest(_ request: MCPOAuthClientAuthenticationRequest) async throws -> MCPOAuthClientAuthenticationRequest? {
        guard usesCustomClientAuthentication else { return nil }
        try requireMigration(request.authorizationServerURL == OfflineOAuth.binding.authorizationServerURL,
                             "Custom authentication received an unexpected authorization server.")
        try requireMigration(request.tokenURL == OfflineOAuth.tokenURL,
                             "Custom authentication received an unexpected token endpoint.")
        var authenticated = request
        authenticated.parameters.append(URLQueryItem(name: "client_id", value: OfflineOAuth.clientID))
        authenticated.parameters.append(URLQueryItem(name: "client_assertion_type", value: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"))
        // In a real confidential client, create a signed assertion for the already validated token endpoint.
        authenticated.parameters.append(URLQueryItem(name: "client_assertion", value: OfflineOAuth.assertion))
        return authenticated
    }
}
