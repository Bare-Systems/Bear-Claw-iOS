import Foundation
import Combine
import Security

protocol AuthTokenStore {
    func readToken() -> String?
    func writeToken(_ token: String?)
}

final class InMemoryAuthTokenStore: AuthTokenStore {
    private var token: String?

    func readToken() -> String? {
        token
    }

    func writeToken(_ token: String?) {
        self.token = token
    }
}

final class KeychainAuthTokenStore: AuthTokenStore {
    private let service = "com.baresystems.bearclaw"
    private let account = "bearclaw.authToken"

    func readToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func writeToken(_ token: String?) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        if let token, let data = token.data(using: .utf8), !token.isEmpty {
            let attrsToUpdate: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attrsToUpdate as CFDictionary)
            if updateStatus == errSecItemNotFound {
                var addQuery = baseQuery
                addQuery[kSecValueData as String] = data
                _ = SecItemAdd(addQuery as CFDictionary, nil)
            }
            return
        }

        _ = SecItemDelete(baseQuery as CFDictionary)
    }
}

final class AppSettingsStore: ObservableObject {
    @Published var apiBaseURL: String {
        didSet { save() }
    }

    @Published var authToken: String {
        didSet { save() }
    }

    @Published var pinnedCertFingerprint: String {
        didSet { save() }
    }

    private enum Keys {
        static let apiBaseURL = "bearclaw.apiBaseURL"
        static let pinnedCertFingerprint = "bearclaw.pinnedCertFingerprint"
    }

    private let defaults: UserDefaults
    private let tokenStore: AuthTokenStore

    init(defaults: UserDefaults = .standard, tokenStore: AuthTokenStore = KeychainAuthTokenStore()) {
        self.defaults = defaults
        self.tokenStore = tokenStore
        self.apiBaseURL = defaults.string(forKey: Keys.apiBaseURL) ?? ""
        self.authToken = tokenStore.readToken() ?? ""
        self.pinnedCertFingerprint = defaults.string(forKey: Keys.pinnedCertFingerprint) ?? ""
    }

    var isConfigured: Bool {
        validatedBaseURL != nil
    }

    func makeClient() -> BearClawClientProtocol {
        guard let baseURL = validatedBaseURL else {
            return PreviewClient()
        }

        let token = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        return BearClawClient(
            baseURL: baseURL,
            session: makeSession(),
            authTokenProvider: { token.isEmpty ? nil : token }
        )
    }

    private func save() {
        defaults.set(apiBaseURL, forKey: Keys.apiBaseURL)
        defaults.set(pinnedCertFingerprint, forKey: Keys.pinnedCertFingerprint)
        let trimmed = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        tokenStore.writeToken(trimmed.isEmpty ? nil : trimmed)
    }

    func applyPairingPayload(_ rawPayload: String) throws {
        let payload = try parseTardiPairingPayload(rawPayload)
        apiBaseURL = payload.endpoint
        authToken = payload.bearerToken
        pinnedCertFingerprint = payload.certSHA256
    }

    func reset() {
        apiBaseURL = ""
        authToken = ""
        pinnedCertFingerprint = ""
    }

    private var validatedBaseURL: URL? {
        let normalized = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: normalized), !normalized.isEmpty else {
            return nil
        }
        return isAllowedGatewayURL(url) ? url : nil
    }

    private func isAllowedGatewayURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "https" { return true }
        guard scheme == "http" else { return false }

        guard let host = url.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        let delegate = PinnedCertificateDelegate(pinnedFingerprint: pinnedCertFingerprint)
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }
}
