//
//  GoogleHealthAuth.swift
//  Pulse
//
//  v1.1 Phase 6a — Google Health API OAuth 2.0 (PKCE) + Keychain plumbing.
//
//  iOS-only: ASWebAuthenticationSession is unavailable on watchOS.
//  watchOS access pattern is deferred to Phase 6b (likely WatchConnectivity
//  push of token, or iOS-side fetch with WC handoff of normalised data).
//

import Foundation

#if os(iOS)

import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
final class GoogleHealthAuth: NSObject, ObservableObject {

    static let shared = GoogleHealthAuth()

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    @Published private(set) var connectionState: ConnectionState = .disconnected

    private var clientID: String {
        (Bundle.main.object(forInfoDictionaryKey: "GoogleHealthOAuthClientID") as? String) ?? ""
    }

    private let redirectURI = "pulse-health://google-health/callback"

    // Google Health API v4 restricted scopes (developers.google.com/health)
    // "activity_and_fitness" covers steps, activity, calories, exercise.
    // "health_metrics_and_measurements" covers heart rate, SpO2, sleep.
    // Both require privacy review approval before production use.
    private let scopes: [String] = [
        "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly",
        "https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly",
    ]

    private let authEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    private let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!

    private static let keychainAccessToken  = "google-health.access-token"
    private static let keychainRefreshToken = "google-health.refresh-token"
    private static let keychainExpiresAt    = "google-health.expires-at"

    private struct Tokens {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
    }

    private var cachedTokens: Tokens?
    private var activeSession: ASWebAuthenticationSession?

    override init() {
        super.init()
        loadCachedTokensFromKeychain()
        if cachedTokens != nil {
            connectionState = .connected
        }
    }

    // MARK: - Public API

    func connect() async {
        guard !clientID.isEmpty else {
            connectionState = .error(String(localized: "Google Health OAuth client not configured"))
            return
        }
        connectionState = .connecting
        do {
            let verifier = Self.generatePKCEVerifier()
            let challenge = Self.pkceChallenge(for: verifier)
            let state = Self.generateState()

            let authURL = buildAuthorizationURL(challenge: challenge, state: state)
            let callbackURL = try await presentWebAuth(authURL: authURL)
            let code = try parseCallback(url: callbackURL, expectedState: state)
            let tokens = try await exchangeCodeForTokens(code: code, verifier: verifier)
            persistTokens(tokens)
            connectionState = .connected
        } catch GoogleHealthAuthError.cancelled {
            connectionState = .disconnected
        } catch let error as GoogleHealthAuthError {
            connectionState = .error(error.localizedDescription)
        } catch {
            connectionState = .error(error.localizedDescription)
        }
    }

    func disconnect() {
        KeychainHelper.delete(forKey: Self.keychainAccessToken)
        KeychainHelper.delete(forKey: Self.keychainRefreshToken)
        KeychainHelper.delete(forKey: Self.keychainExpiresAt)
        cachedTokens = nil
        connectionState = .disconnected
    }

    /// Non-expired access token, refreshing via stored refresh token on demand.
    func currentAccessToken() async throws -> String {
        if let tokens = cachedTokens, tokens.expiresAt > Date().addingTimeInterval(60) {
            return tokens.accessToken
        }
        let refreshToken: String
        if let cached = cachedTokens?.refreshToken, !cached.isEmpty {
            refreshToken = cached
        } else if let stored = KeychainHelper.load(forKey: Self.keychainRefreshToken) {
            refreshToken = stored
        } else {
            throw GoogleHealthAuthError.notConnected
        }
        let tokens = try await refreshAccessToken(refreshToken: refreshToken)
        persistTokens(tokens)
        return tokens.accessToken
    }

    // MARK: - Keychain

    private func loadCachedTokensFromKeychain() {
        guard
            let access = KeychainHelper.load(forKey: Self.keychainAccessToken),
            let refresh = KeychainHelper.load(forKey: Self.keychainRefreshToken),
            let expiryString = KeychainHelper.load(forKey: Self.keychainExpiresAt),
            let expiryDouble = Double(expiryString)
        else {
            return
        }
        cachedTokens = Tokens(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: Date(timeIntervalSince1970: expiryDouble)
        )
    }

    private func persistTokens(_ tokens: Tokens) {
        KeychainHelper.save(tokens.accessToken, forKey: Self.keychainAccessToken)
        KeychainHelper.save(tokens.refreshToken, forKey: Self.keychainRefreshToken)
        KeychainHelper.save(
            String(tokens.expiresAt.timeIntervalSince1970),
            forKey: Self.keychainExpiresAt
        )
        cachedTokens = tokens
    }

    // MARK: - Authorization URL

    private func buildAuthorizationURL(challenge: String, state: String) -> URL {
        var comps = URLComponents(url: authEndpoint, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        return comps.url!
    }

    // MARK: - Web auth session

    private func presentWebAuth(authURL: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "pulse-health"
            ) { callbackURL, error in
                if let authError = error as? ASWebAuthenticationSessionError,
                   authError.code == .canceledLogin {
                    continuation.resume(throwing: GoogleHealthAuthError.cancelled)
                } else if let error {
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: GoogleHealthAuthError.unknown)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.activeSession = session
            session.start()
        }
    }

    private func parseCallback(url: URL, expectedState: String) throws -> String {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems else {
            throw GoogleHealthAuthError.malformedCallback
        }
        if let oauthError = items.first(where: { $0.name == "error" })?.value {
            throw GoogleHealthAuthError.oauthError(oauthError)
        }
        guard let state = items.first(where: { $0.name == "state" })?.value,
              state == expectedState else {
            throw GoogleHealthAuthError.stateMismatch
        }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw GoogleHealthAuthError.malformedCallback
        }
        return code
    }

    // MARK: - Token exchange

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Int
        let token_type: String?
    }

    private func exchangeCodeForTokens(code: String, verifier: String) async throws -> Tokens {
        let body = [
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ]
        let response = try await postFormEncoded(body: body)
        return Tokens(
            accessToken: response.access_token,
            refreshToken: response.refresh_token ?? "",
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expires_in))
        )
    }

    private func refreshAccessToken(refreshToken: String) async throws -> Tokens {
        let body = [
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ]
        let response = try await postFormEncoded(body: body)
        // Google typically omits refresh_token on refresh — reuse the existing one.
        return Tokens(
            accessToken: response.access_token,
            refreshToken: response.refresh_token ?? refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expires_in))
        )
    }

    private func postFormEncoded(body: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode(body).data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GoogleHealthAuthError.tokenExchangeFailed("invalid response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            throw GoogleHealthAuthError.tokenExchangeFailed("HTTP \(http.statusCode): \(bodyText)")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    // MARK: - PKCE + state helpers

    private static func generatePKCEVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func pkceChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func generateState() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func formEncode(_ params: [String: String]) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return params
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
    }
}

extension GoogleHealthAuth: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState == .foregroundActive })
            return scene?.windows.first(where: \.isKeyWindow)
                ?? scene?.windows.first
                ?? ASPresentationAnchor()
        }
    }
}

enum GoogleHealthAuthError: LocalizedError, Equatable {
    case notConnected
    case cancelled
    case stateMismatch
    case malformedCallback
    case oauthError(String)
    case tokenExchangeFailed(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return String(localized: "Google Health not connected")
        case .cancelled:
            return String(localized: "Sign-in cancelled")
        case .stateMismatch:
            return String(localized: "OAuth state mismatch — possible CSRF")
        case .malformedCallback:
            return String(localized: "Malformed OAuth callback")
        case .oauthError(let detail):
            return String(format: String(localized: "OAuth error: %@"), detail)
        case .tokenExchangeFailed(let detail):
            return String(format: String(localized: "Token exchange failed: %@"), detail)
        case .unknown:
            return String(localized: "Unknown sign-in error")
        }
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

#endif
