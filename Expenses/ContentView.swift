import SwiftUI

struct ContentView: View {
    @StateObject private var store = Store()
    @State private var showAdd = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if Settings.isConfigured {
                    DashboardView(store: store)
                } else {
                    ContentUnavailableView {
                        Label("Not connected", systemImage: "link")
                    } description: {
                        Text("Add your Google Apps Script URL and secret to load your transactions.")
                    } actions: {
                        Button("Open Settings") { showSettings = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Expenses")
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showAdd = true } label: { Image(systemName: "plus.circle.fill") }
                        .disabled(!Settings.isConfigured)
                }
            }
            .sheet(isPresented: $showAdd) { AddExpenseView(store: store) }
            .sheet(isPresented: $showSettings) {
                SettingsView { Task { await store.load() } }
            }
            .task { if Settings.isConfigured { await store.load() } }
            .refreshable { await store.load() }
        }
    }
}

// MARK: - Per-category icon + colour

struct CategoryStyle {
    let icon: String
    let color: Color

    static func of(_ name: String) -> CategoryStyle {
        switch name {
        case "Food & Dining":     return .init(icon: "fork.knife", color: .orange)
        case "Groceries":         return .init(icon: "cart.fill", color: .green)
        case "Transport":         return .init(icon: "car.fill", color: .blue)
        case "Shopping":          return .init(icon: "bag.fill", color: .pink)
        case "Bills & Utilities": return .init(icon: "bolt.fill", color: .yellow)
        case "Entertainment":     return .init(icon: "tv.fill", color: .purple)
        case "Health":            return .init(icon: "cross.case.fill", color: .red)
        case "Rent":              return .init(icon: "house.fill", color: .brown)
        case "Travel":            return .init(icon: "airplane", color: .teal)
        case "Transfers":         return .init(icon: "arrow.left.arrow.right", color: .indigo)
        case "Income":            return .init(icon: "arrow.down.circle.fill", color: .green)
        case "Other":             return .init(icon: "ellipsis.circle.fill", color: .gray)
        default:                  return .init(icon: "questionmark.circle.fill", color: .gray)
        }
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @ObservedObject var store: Store

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let error = store.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                HeroSummary(month: store.monthSpend,
                            allTime: store.allTimeSpend,
                            count: store.transactions.count)

                if !store.categoryBreakdown.isEmpty {
                    CategoryBreakdownCard(items: store.categoryBreakdown)
                }

                RecentCard(store: store)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct HeroSummary: View {
    let month: Double
    let allTime: Double
    let count: Int

    private var monthName: String {
        Date().formatted(.dateTime.month(.wide))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Spent in \(monthName)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))

            Text(inr(month))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                Label(inr(allTime), systemImage: "sum")
                Label("\(count) transactions", systemImage: "list.bullet")
            }
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

struct CategoryBreakdownCard: View {
    let items: [(name: String, amount: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("By category")
                .font(.headline)

            let maxAmount = items.first?.amount ?? 1
            ForEach(items, id: \.name) { item in
                let style = CategoryStyle.of(item.name)
                HStack(spacing: 12) {
                    iconBubble(style)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(item.name).font(.subheadline)
                            Spacer()
                            Text(inr(item.amount)).font(.subheadline.weight(.semibold))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.systemGray5))
                                Capsule().fill(style.color)
                                    .frame(width: geo.size.width * CGFloat(maxAmount > 0 ? item.amount / maxAmount : 0))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .cardStyle()
    }
}

struct RecentCard: View {
    @ObservedObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent")
                .font(.headline)

            if store.transactions.isEmpty {
                Text(store.isLoading ? "Loading…" : "No transactions yet. They'll appear here as your Shortcut logs them.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            } else {
                ForEach(Array(store.transactions.prefix(50).enumerated()), id: \.element.id) { idx, tx in
                    if idx > 0 { Divider().padding(.leading, 52) }
                    TransactionRow(tx: tx, store: store)
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
                Text(tx.merchant.isEmpty ? "(no merchant)" : tx.merchant)
                    .font(.subheadline.weight(.medium))
                Menu {
                    ForEach(allCategories, id: \.self) { c in
                        Button {
                            Task { await store.recategorize(tx, to: c) }
                        } label: {
                            Label(c, systemImage: CategoryStyle.of(c).icon)
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(tx.category)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text((tx.category == "Income" ? "+" : "") + inr(tx.amount))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tx.category == "Income" ? Color.green : Color.primary)
                Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 9)
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
    store.transactions = [
        Transaction(id: "1", timestamp: "2026-06-25T09:00:00Z", amount: 450,
                    merchant: "Swiggy", category: "Food & Dining", source: "sms", raw: ""),
        Transaction(id: "2", timestamp: "2026-06-25T08:00:00Z", amount: 1200,
                    merchant: "BigBasket", category: "Groceries", source: "sms", raw: ""),
        Transaction(id: "3", timestamp: "2026-06-24T19:00:00Z", amount: 89,
                    merchant: "Uber", category: "Transport", source: "apple pay", raw: ""),
        Transaction(id: "4", timestamp: "2026-06-23T13:00:00Z", amount: 2500,
                    merchant: "Amazon", category: "Shopping", source: "sms", raw: "")
    ]
    return NavigationStack { DashboardView(store: store) }
}
