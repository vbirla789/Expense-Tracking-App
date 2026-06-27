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
            transactions = fetched
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

    func add(amount: Double, merchant: String, category: String) async {
        do {
            try await ExpenseAPI.add(amount: amount, merchant: merchant,
                                     category: category, source: "manual", raw: "")
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

    func edit(_ tx: Transaction, amount: Double, category: String) async {
        do {
            try await ExpenseAPI.update(id: tx.id, amount: amount, category: category)
            if let i = transactions.firstIndex(where: { $0.id == tx.id }) {
                transactions[i].amount = amount
                transactions[i].category = category
            }
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

    /// (category, total) for the current month, biggest first.
    var categoryBreakdown: [(name: String, amount: Double)] {
        breakdown(monthOnly: true)
    }

    // MARK: - Scoped queries (monthOnly == true → this month, false → all time)

    /// Total spend for the chosen scope.
    func total(monthOnly: Bool) -> Double {
        spend.filter { !monthOnly || isThisMonth($0.date) }.reduce(0) { $0 + $1.amount }
    }

    /// (category, total) for the chosen scope, biggest first.
    func breakdown(monthOnly: Bool) -> [(name: String, amount: Double)] {
        var dict: [String: Double] = [:]
        for t in spend where (!monthOnly || isThisMonth(t.date)) {
            dict[t.category, default: 0] += t.amount
        }
        return dict.sorted { $0.value > $1.value }.map { (name: $0.key, amount: $0.value) }
    }

    /// All transactions in one category, for the drill-down filter view.
    func transactions(in category: String, monthOnly: Bool) -> [Transaction] {
        transactions.filter { $0.category == category && (!monthOnly || isThisMonth($0.date)) }
    }

    /// Transactions for the current scope, optionally filtered to one category
    /// (category == nil means "All"). Used by the inline filter pills.
    func filtered(monthOnly: Bool, category: String?) -> [Transaction] {
        transactions.filter { tx in
            (!monthOnly || isThisMonth(tx.date)) && (category == nil || tx.category == category)
        }
    }
}
