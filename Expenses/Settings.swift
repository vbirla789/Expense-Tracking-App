import Foundation

/// Persists the Apps Script endpoint + secret in UserDefaults.
/// Shared by the UI and by the App Intent (both run in the app's process).
enum Settings {
    private static let urlKey = "endpointURL"
    private static let tokenKey = "secretToken"

    static var endpoint: String {
        get { UserDefaults.standard.string(forKey: urlKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: urlKey) }
    }

    static var token: String {
        get { UserDefaults.standard.string(forKey: tokenKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
    }

    static var isConfigured: Bool { !endpoint.isEmpty && !token.isEmpty }
}
