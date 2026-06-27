import Foundation

enum APIError: LocalizedError {
    case notConfigured
    case badURL
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Add your Apps Script URL and secret in Settings first."
        case .badURL:        return "The Web App URL looks invalid."
        case .server(let m): return m
        }
    }
}

/// All network calls to the Google Apps Script web app live here so both the
/// SwiftUI store and the App Intent can reuse them.
enum ExpenseAPI {

    static func fetchAll() async throws -> [Transaction] {
        guard Settings.isConfigured else { throw APIError.notConfigured }
        guard var comps = URLComponents(string: Settings.endpoint) else { throw APIError.badURL }
        comps.queryItems = [
            URLQueryItem(name: "token", value: Settings.token),
            URLQueryItem(name: "action", value: "data")
        ]
        guard let url = comps.url else { throw APIError.badURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        let resp = try JSONDecoder().decode(DataResponse.self, from: data)
        guard resp.ok else { throw APIError.server(resp.error ?? "Request failed") }
        return resp.transactions ?? []
    }

    static func add(amount: Double, merchant: String, category: String,
                    source: String, raw: String) async throws {
        try await post([
            "token": Settings.token, "action": "add",
            "amount": amount, "merchant": merchant, "category": category,
            "source": source, "raw": raw
        ])
    }

    static func update(id: String, category: String) async throws {
        try await post([
            "token": Settings.token, "action": "update",
            "id": id, "category": category
        ])
    }

    private static func post(_ body: [String: Any]) async throws {
        guard Settings.isConfigured else { throw APIError.notConfigured }
        guard let url = URL(string: Settings.endpoint) else { throw APIError.badURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let ok = obj["ok"] as? Bool, !ok {
            throw APIError.server(obj["error"] as? String ?? "Request failed")
        }
    }
}
