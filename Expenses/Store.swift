import Foundation
import Combine

/// Observable state for the dashboard. Wraps ExpenseAPI and computes summaries.
@MainActor
final class Store: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            transactions = try await ExpenseAPI.fetchAll().sorted { $0.date > $1.date }
        } catch {
            errorMessage = error.localizedDescription
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
            try await ExpenseAPI.update(id: tx.id, category: category)
            if let i = transactions.firstIndex(where: { $0.id == tx.id }) {
                transactions[i].category = category
            }
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
        var dict: [String: Double] = [:]
        for t in spend where isThisMonth(t.date) {
            dict[t.category, default: 0] += t.amount
        }
        return dict.sorted { $0.value > $1.value }.map { (name: $0.key, amount: $0.value) }
    }
}
