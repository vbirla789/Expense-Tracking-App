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
                CaptureSheet(store: store, initialAmount: capture.amount, editing: capture.editing)
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
        case "Cab":                   return .init(icon: "car.fill", color: .blue)
        case "Sutta", "Ciggs":        return .init(icon: "smoke.fill", color: .gray)
        case "Groceries":             return .init(icon: "cart.fill", color: .green)
        case "Outing":                return .init(icon: "party.popper.fill", color: .purple)
        case "Rent":                  return .init(icon: "house.fill", color: .brown)
        case "Others", "Other":       return .init(icon: "ellipsis.circle.fill", color: .gray)
        case "Food", "Food & Dining": return .init(icon: "fork.knife", color: .orange)
        case "Shopping":              return .init(icon: "bag.fill", color: .pink)
        case "Income":                return .init(icon: "arrow.down.circle.fill", color: .green)
        case "Uncategorized":         return .init(icon: "questionmark.circle.fill", color: .gray)
        default:                      return .init(icon: "tag.fill", color: stableColor(name))
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

    private var visibleTransactions: [Transaction] {
        store.filtered(monthOnly: monthOnly, category: selectedCategory)
    }

    private var filteredTotal: Double {
        visibleTransactions.reduce(0) { $0 + ($1.category == "Income" ? 0 : $1.effectiveAmount) }
    }

    var body: some View {
        List {
            Section {
                if let error = store.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.red)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                HeroSummary(total: store.total(monthOnly: monthOnly),
                            monthOnly: monthOnly,
                            count: store.filtered(monthOnly: monthOnly, category: nil).count)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                Picker("Scope", selection: $monthOnly) {
                    Text("This month").tag(true)
                    Text("All time").tag(false)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                CategoryFilterBar(categories: quickPickCategories, selected: $selectedCategory)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                if visibleTransactions.isEmpty {
                    Text(store.isLoading ? "Loading…" : "No transactions here yet.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(visibleTransactions.prefix(100))) { tx in
                        TransactionRow(tx: tx)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { await store.delete(tx) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    CaptureCoordinator.shared.beginEdit(tx)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            } header: {
                HStack {
                    Text(selectedCategory ?? "All transactions")
                    Spacer()
                    if selectedCategory != nil {
                        Text(inr(filteredTotal))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .animation(.snappy, value: monthOnly)
        .animation(.snappy, value: selectedCategory)
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
                .contentTransition(.numericText())

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

struct TransactionRow: View {
    let tx: Transaction

    var body: some View {
        let style = CategoryStyle.of(tx.category)
        HStack(spacing: 12) {
            iconBubble(style)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(tx.category)
                        .font(.subheadline.weight(.medium))
                    if tx.isSplit {
                        Text("Split")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text((tx.category == "Income" ? "+" : "") + inr(tx.effectiveAmount))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tx.category == "Income" ? Color.green : Color.primary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
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

    /// Frosted-glass panel with a subtle edge highlight (glassmorphism).
    func glassCard(cornerRadius: CGFloat) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            )
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
