import Foundation

/// One transaction row, mirroring the columns in the Google Sheet.
struct Transaction: Identifiable, Codable, Hashable {
    let id: String
    let timestamp: String
    let amount: Double
    let merchant: String
    var category: String      // mutable so we can re-categorize in place
    let source: String
    let raw: String

    var date: Date { Transaction.parseDate(timestamp) }

    /// Apps Script sends ISO8601, sometimes with fractional seconds — handle both.
    static func parseDate(_ s: String) -> Date {
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFrac.date(from: s) { return d }
        let plain = ISO8601DateFormatter()
        if let d = plain.date(from: s) { return d }
        return Date()
    }
}

/// Shape of the GET response from the Apps Script web app.
struct DataResponse: Codable {
    let ok: Bool
    let transactions: [Transaction]?
    let error: String?
}

/// Quick-pick category pills shown in the capture sheet. Edit freely.
let quickPickCategories = [
    "Ciggs", "Groceries", "Rent", "Cab", "Food",
    "Shopping", "Bills", "Health", "Entertainment", "Travel"
]

/// Full category list for the re-categorize menu (pills + a few extras).
let allCategories = quickPickCategories + ["Transport", "Transfers", "Income", "Other", "Uncategorized"]

/// Format a rupee amount with no decimals, e.g. ₹4,239.
func inr(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "INR"
    f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
}
