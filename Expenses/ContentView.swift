import SwiftUI

struct ContentView: View {
    @StateObject private var store = Store()
    @StateObject private var capture = CaptureCoordinator.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if !Settings.isConfigured {
                    ContentUnavailableView {
                        Label("Not connected", systemImage: "link")
                    } description: {
                        Text("Add your Google Apps Script URL and secret to load your transactions.")
                    } actions: {
                        Button("Open Settings") { showSettings = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else if !store.hasLoaded {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading your expenses…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    DashboardView(store: store)
                }
            }
            .navigationTitle("Expenses")
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { capture.begin(amount: nil) } label: { Image(systemName: "plus.circle.fill") }
                        .disabled(!Settings.isConfigured)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView { Task { await store.load() } }
            }
            .sheet(isPresented: $capture.isPresenting) {
                CaptureSheet(store: store, initialAmount: capture.amount)
            }
            .task {
                if Settings.isConfigured { await store.load() }
                capture.consumePending()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { capture.consumePending() }
            }
            .refreshable { await store.load() }
        }
    }
}

// MARK: - Per-category icon + colour (handles custom categories too)

struct CategoryStyle {
    let icon: String
    let color: Color

    static func of(_ name: String) -> CategoryStyle {
        switch name {
        case "Ciggs":         return .init(icon: "smoke.fill", color: .gray)
        case "Groceries":     return .init(icon: "cart.fill", color: .green)
        case "Rent":          return .init(icon: "house.fill", color: .brown)
        case "Cab":           return .init(icon: "car.fill", color: .blue)
        case "Food", "Food & Dining": return .init(icon: "fork.knife", color: .orange)
        case "Shopping":      return .init(icon: "bag.fill", color: .pink)
        case "Bills":         return .init(icon: "bolt.fill", color: .yellow)
        case "Health":        return .init(icon: "cross.case.fill", color: .red)
        case "Entertainment": return .init(icon: "tv.fill", color: .purple)
        case "Travel":        return .init(icon: "airplane", color: .teal)
        case "Transport":     return .init(icon: "bus.fill", color: .blue)
        case "Transfers":     return .init(icon: "arrow.left.arrow.right", color: .indigo)
        case "Income":        return .init(icon: "arrow.down.circle.fill", color: .green)
        case "Other":         return .init(icon: "ellipsis.circle.fill", color: .gray)
        case "Uncategorized": return .init(icon: "questionmark.circle.fill", color: .gray)
        default:              return .init(icon: "tag.fill", color: stableColor(name))
        }
    }

    private static func stableColor(_ s: String) -> Color {
        let palette: [Color] = [.blue, .green, .orange, .pink, .purple, .red, .teal, .indigo, .mint, .cyan]
        let sum = s.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @ObservedObject var store: Store
    @State private var monthOnly = true
    @State private var selectedCategory: String?   // nil = All

    private var categories: [String] {
        store.breakdown(monthOnly: monthOnly).map { $0.name }
    }

    private var visibleTransactions: [Transaction] {
        store.filtered(monthOnly: monthOnly, category: selectedCategory)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let error = store.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                HeroSummary(total: store.total(monthOnly: monthOnly),
                            monthOnly: monthOnly,
                            count: store.filtered(monthOnly: monthOnly, category: nil).count)

                Picker("Scope", selection: $monthOnly) {
                    Text("This month").tag(true)
                    Text("All time").tag(false)
                }
                .pickerStyle(.segmented)

                CategoryFilterBar(categories: categories, selected: $selectedCategory)

                TransactionListCard(store: store,
                                    transactions: visibleTransactions,
                                    category: selectedCategory)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        // If the selected category disappears (scope change), reset to All.
        .onChange(of: monthOnly) { _, _ in
            if let sel = selectedCategory, !categories.contains(sel) { selectedCategory = nil }
        }
    }
}

struct HeroSummary: View {
    let total: Double
    let monthOnly: Bool
    let count: Int

    private var label: String {
        monthOnly ? "Spent in \(Date().formatted(.dateTime.month(.wide)))" : "Spent all time"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))

            Text(inr(total))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Label("\(count) transactions", systemImage: "list.bullet")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 6)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.65)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.accentColor.opacity(0.3), radius: 12, y: 6)
    }
}

// MARK: - Horizontal filter pills (District-style)

struct CategoryFilterBar: View {
    let categories: [String]
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", icon: "square.grid.2x2", color: .accentColor, isOn: selected == nil) {
                    selected = nil
                }
                ForEach(categories, id: \.self) { c in
                    let style = CategoryStyle.of(c)
                    chip(title: c, icon: style.icon, color: style.color, isOn: selected == c) {
                        selected = (selected == c) ? nil : c
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private func chip(title: String, icon: String, color: Color, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption2)
                Text(title).font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isOn ? color : color.opacity(0.15))
            .foregroundStyle(isOn ? Color.white : color)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Transactions

struct TransactionListCard: View {
    @ObservedObject var store: Store
    let transactions: [Transaction]
    let category: String?

    private var total: Double {
        transactions.reduce(0) { $0 + ($1.category == "Income" ? 0 : $1.amount) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(category ?? "All transactions")
                    .font(.headline)
                Spacer()
                if category != nil {
                    Text(inr(total))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 6)

            if transactions.isEmpty {
                Text(store.isLoading ? "Loading…" : "No transactions here yet.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(transactions.prefix(100).enumerated()), id: \.element.id) { idx, tx in
                        if idx > 0 { Divider().padding(.leading, 52) }
                        TransactionRow(tx: tx, store: store)
                    }
                }
            }
        }
        .cardStyle()
    }
}

struct TransactionRow: View {
    let tx: Transaction
    @ObservedObject var store: Store

    var body: some View {
        let style = CategoryStyle.of(tx.category)
        HStack(spacing: 12) {
            iconBubble(style)

            VStack(alignment: .leading, spacing: 3) {
                Text(tx.category)
                    .font(.subheadline.weight(.medium))
                Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text((tx.category == "Income" ? "+" : "") + inr(tx.amount))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tx.category == "Income" ? Color.green : Color.primary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu {
            ForEach(allCategories, id: \.self) { c in
                Button {
                    Task { await store.recategorize(tx, to: c) }
                } label: {
                    Label(c, systemImage: CategoryStyle.of(c).icon)
                }
            }
        }
    }
}

// MARK: - Shared helpers

@ViewBuilder
func iconBubble(_ style: CategoryStyle) -> some View {
    ZStack {
        Circle().fill(style.color.opacity(0.18)).frame(width: 40, height: 40)
        Image(systemName: style.icon)
            .font(.system(size: 16))
            .foregroundStyle(style.color)
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview("Dashboard") {
    let store = Store()
    store.hasLoaded = true
    store.transactions = [
        Transaction(id: "1", timestamp: "2026-06-25T09:00:00Z", amount: 450,
                    merchant: "Swiggy", category: "Food", source: "sms", raw: ""),
        Transaction(id: "2", timestamp: "2026-06-25T08:00:00Z", amount: 1200,
                    merchant: "BigBasket", category: "Groceries", source: "sms", raw: ""),
        Transaction(id: "3", timestamp: "2026-06-24T19:00:00Z", amount: 89,
                    merchant: "Uber", category: "Cab", source: "apple pay", raw: ""),
        Transaction(id: "4", timestamp: "2026-06-23T13:00:00Z", amount: 300,
                    merchant: "Pan shop", category: "Ciggs", source: "sms", raw: "")
    ]
    return NavigationStack { DashboardView(store: store) }
}
