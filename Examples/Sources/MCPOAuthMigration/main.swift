import Foundation
import SwiftAISDK

@main
struct MCPOAuthMigrationExample {
    static func main() async throws {
        for authentication in MigrationAuthentication.allCases {
            let provider = MigrationOAuthProvider(authentication: authentication)
            let transport = OfflineOAuthTransport(authentication: authentication)
            let started = try await MCPOAuth.auth(
                provider: provider,
                serverURL: OfflineOAuth.serverURL,
                transport: transport
            )
            try requireMigration(started == .redirect, "Expected authorization to start with a redirect.")
            guard let authorizationURL = await provider.authorizationURL else {
                throw MigrationCheckFailure(description: "Expected a recorded authorization URL.")
            }
            let query = URLComponents(url: authorizationURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let callbackState = query.first { $0.name == "state" }?.value
            try requireMigration(authorizationURL.host == "auth.example.com" && authorizationURL.path == "/authorize",
                                 "Expected the trusted authorization endpoint.")
            try requireMigration(query.first { $0.name == "code_challenge_method" }?.value == "S256",
                                 "Expected the S256 PKCE method.")
            try requireMigration(callbackState != nil, "Expected a state parameter for callback validation.")
            try requireMigration(!authorizationURL.absoluteString.contains(OfflineOAuth.clientSecret), "Authorization URL contained a secret.")
            try requireMigration(!authorizationURL.absoluteString.contains(OfflineOAuth.assertion), "Authorization URL contained an assertion.")

            // Simulate the browser callback. A real app passes the callback's code, state and optional iss.
            let completed = try await MCPOAuth.auth(
                provider: provider,
                serverURL: OfflineOAuth.serverURL,
                authorizationCode: OfflineOAuth.code,
                callbackState: callbackState,
                callbackIssuer: OfflineOAuth.issuer,
                transport: transport
            )
            try requireMigration(completed == .authorized, "Expected a completed code exchange.")
            let tokens = try await provider.tokens()
            try requireMigration(tokens?.accessToken == OfflineOAuth.accessToken, "Expected stored mock tokens.")
            try requireMigration(tokens?.issuer == OfflineOAuth.issuer
                                 && tokens?.authorizationServerURL == OfflineOAuth.binding.authorizationServerURL
                                 && tokens?.tokenEndpoint == OfflineOAuth.tokenURL,
                                 "Expected saved tokens to retain the validated binding.")
            try await transport.verifyComplete()
            print("Verified offline: \(authentication.rawValue).")
        }
        print("MCP_OAUTH_MIGRATION_OFFLINE_OK")
    }
}
