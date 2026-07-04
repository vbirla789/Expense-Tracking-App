import Foundation
import Combine

/// Observable state for the dashboard. Wraps ExpenseAPI and computes summaries.
@MainActor
final class Store: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var hasLoaded = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        do {
            let fetched = try await ExpenseAPI.fetchAll().sorted { $0.date > $1.date }
            transactions = fetched.filter { $0.category != deletedCategory }
            errorMessage = nil
            hasLoaded = true
        } catch is CancellationError {
            // Ignore — a newer load cancelled this one; not a real error.
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Same: cancelled request, not a failure to surface.
        } catch {
            errorMessage = error.localizedDescription
            hasLoaded = true
        }
        isLoading = false
    }

    func add(amount: Double, merchant: String, category: String, note: String = "") async {
        do {
            try await ExpenseAPI.add(amount: amount, merchant: merchant,
                                     category: category, source: "manual", raw: note)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recategorize(_ tx: Transaction, to category: String) async {
        do {
            try await ExpenseAPI.update(id: tx.id, amount: nil, category: category)
            if let i = transactions.firstIndex(where: { $0.id == tx.id }) {
                transactions[i].category = category
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func edit(_ tx: Transaction, amount: Double, category: String, note: String) async {
        do {
            // Add a corrected row (preserving the original date), then hide the old one.
            // Works with the deployed backend without needing an amount-update action.
            try await ExpenseAPI.add(amount: amount, merchant: tx.merchant,
                                     category: category, source: tx.source,
                                     raw: note, timestamp: tx.timestamp)
            try await ExpenseAPI.delete(id: tx.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ tx: Transaction) async {
        do {
            try await ExpenseAPI.delete(id: tx.id)
            transactions.removeAll { $0.id == tx.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Summaries (spend excludes Income)

    private func isThisMonth(_ d: Date) -> Bool {
        Calendar.current.isDate(d, equalTo: Date(), toGranularity: .month)
    }

    private var spend: [Transaction] { transactions.filter { $0.category != "Income" } }

    var monthSpend: Double {
        spend.filter { isThisMonth($0.date) }.reduce(0) { $0 + $1.amount }
    }

    var allTimeSpend: Double {
        spend.reduce(0) { $0 + $1.amount }
    }

    // MARK: - Scoped queries (month == nil → all time, else that calendar month)

    private func isIn(_ d: Date, month: Date) -> Bool {
        Calendar.current.isDate(d, equalTo: month, toGranularity: .month)
    }

    /// Date of the oldest transaction — lower bound for month navigation.
    var earliestDate: Date? { transactions.map(\.date).min() }

    /// Total spend for the chosen scope (splits count only your share).
    func total(month: Date?) -> Double {
        spend.filter { tx in
            if let month { return isIn(tx.date, month: month) }
            return true
        }
        .reduce(0) { $0 + $1.effectiveAmount }
    }

    /// Transactions for the current scope, optionally filtered to one category
    /// (category == nil means "All"). "Others" is a catch-all for any category
    /// that isn't one of the main pills (so custom categories land there too).
    func filtered(month: Date?, category: String?) -> [Transaction] {
        let mains: Set<String> = ["Cab", "Sutta", "Groceries", "Outing", "Rent", "Income"]
        return transactions.filter { tx in
            if let month, !isIn(tx.date, month: month) { return false }
            guard let category else { return true }            // All
            if category == "Others" { return !mains.contains(tx.category) }
            return tx.category == category
        }
    }
}
