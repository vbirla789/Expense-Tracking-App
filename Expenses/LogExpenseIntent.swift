import AppIntents

/// Category as an App Intent enum → Shortcuts shows this as a native picker
/// (your "categorize popup"), and Siri/automations can pass it directly.
enum ExpenseCategory: String, AppEnum {
    case food = "Food & Dining"
    case groceries = "Groceries"
    case transport = "Transport"
    case shopping = "Shopping"
    case bills = "Bills & Utilities"
    case entertainment = "Entertainment"
    case health = "Health"
    case rent = "Rent"
    case travel = "Travel"
    case transfers = "Transfers"
    case income = "Income"
    case other = "Other"

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Category" }

    static var caseDisplayRepresentations: [ExpenseCategory: DisplayRepresentation] {
        [
            .food: "Food & Dining",
            .groceries: "Groceries",
            .transport: "Transport",
            .shopping: "Shopping",
            .bills: "Bills & Utilities",
            .entertainment: "Entertainment",
            .health: "Health",
            .rent: "Rent",
            .travel: "Travel",
            .transfers: "Transfers",
            .income: "Income",
            .other: "Other"
        ]
    }
}

/// The Shortcut automation can run this with no UI to log a transaction.
/// If Category is left unset, Shortcuts will prompt you to pick one — the popup.
struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Expense"
    static var description = IntentDescription("Add a transaction to your expense tracker.")
    static var openAppWhenRun = false

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Merchant", default: "")
    var merchant: String

    @Parameter(title: "Category")
    var category: ExpenseCategory

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) at \(\.$merchant) as \(\.$category)")
    }

    func perform() async throws -> some IntentResult {
        try await ExpenseAPI.add(amount: amount, merchant: merchant,
                                 category: category.rawValue, source: "shortcut", raw: "")
        return .result()
    }
}

/// Surfaces the intent in the Shortcuts app and to Siri automatically.
struct ExpensesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: ["Log expense in \(.applicationName)"],
            shortTitle: "Log Expense",
            systemImageName: "indianrupeesign.circle"
        )
    }
}
