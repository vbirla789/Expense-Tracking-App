import Foundation

/// One transaction row, mirroring the columns in the Google Sheet.
struct Transaction: Identifiable, Codable, Hashable {
    let id: String
    let timestamp: String
    var amount: Double        // mutable so we can edit in place
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

/// The category set — used for both the capture-sheet pills and the filter pills.
/// Order matters: shown left-to-right exactly like this.
let quickPickCategories = ["Cab", "Sutta", "Groceries", "Outing", "Rent", "Others"]

/// Alias kept for any remaining references.
let allCategories = quickPickCategories

/// Rows whose category equals this are treated as deleted and hidden everywhere.
/// Lets "delete" work via the (already-deployed) category-update action — no redeploy needed.
let deletedCategory = "__deleted__"

/// Format a rupee amount with no decimals, e.g. ₹4,239.
func inr(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "INR"
    f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
}
