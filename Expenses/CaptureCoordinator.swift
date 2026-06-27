import Foundation
import Combine

private let pendingAmountKey = "pendingCaptureAmount"
private let pendingFlagKey = "hasPendingCapture"

/// Coordinates showing the capture bottom sheet — both for the manual "+" button
/// and for the Shortcut automation (which stashes an amount, then opens the app).
@MainActor
final class CaptureCoordinator: ObservableObject {
    static let shared = CaptureCoordinator()

    @Published var isPresenting = false
    @Published var amount: Double?
    @Published var editing: Transaction?

    /// Show the sheet now (amount nil = blank manual entry).
    func begin(amount: Double?) {
        self.editing = nil
        self.amount = amount
        self.isPresenting = true
    }

    /// Show the sheet pre-filled to edit an existing transaction.
    func beginEdit(_ tx: Transaction) {
        self.editing = tx
        self.amount = tx.amount
        self.isPresenting = true
    }

    /// Called when the app becomes active — if the Shortcut left a pending
    /// amount, open the sheet pre-filled with it.
    func consumePending() {
        guard UserDefaults.standard.bool(forKey: pendingFlagKey) else { return }
        UserDefaults.standard.set(false, forKey: pendingFlagKey)
        begin(amount: UserDefaults.standard.double(forKey: pendingAmountKey))
    }

    /// Called from the App Intent (possibly another process) — just records the
    /// amount; the app picks it up via consumePending() when it comes to front.
    nonisolated static func stash(_ amount: Double) {
        UserDefaults.standard.set(amount, forKey: pendingAmountKey)
        UserDefaults.standard.set(true, forKey: pendingFlagKey)
    }
}
