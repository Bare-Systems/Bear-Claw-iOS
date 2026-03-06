import Foundation
import Combine

final class AppSettingsStore: ObservableObject {
    @Published var apiBaseURL: String {
        didSet { save() }
    }

    @Published var authToken: String {
        didSet { save() }
    }

    private enum Keys {
        static let apiBaseURL = "bearclaw.apiBaseURL"
        static let authToken = "bearclaw.authToken"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.apiBaseURL = defaults.string(forKey: Keys.apiBaseURL) ?? ""
        self.authToken = defaults.string(forKey: Keys.authToken) ?? ""
    }

    var isConfigured: Bool {
        let url = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return !url.isEmpty
    }

    func makeClient() -> BearClawClientProtocol {
        let normalizedBaseURL = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = URL(string: normalizedBaseURL), !normalizedBaseURL.isEmpty else {
            return PreviewClient()
        }

        let token = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        return BearClawClient(
            baseURL: baseURL,
            authTokenProvider: { token.isEmpty ? nil : token }
        )
    }

    private func save() {
        defaults.set(apiBaseURL, forKey: Keys.apiBaseURL)
        defaults.set(authToken, forKey: Keys.authToken)
    }
}
