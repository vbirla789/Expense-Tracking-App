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
                    LoadingSkeleton()
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
        case "Sutta", "Ciggs":        return .init(icon: "smoke.fill", color: .teal)
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
    @State private var monthAnchor = Date()        // which month is shown (when monthOnly)
    @State private var selectedCategory: String?   // nil = All

    /// nil = all time, else the calendar month to show.
    private var scopeMonth: Date? { monthOnly ? monthAnchor : nil }

    private var visibleTransactions: [Transaction] {
        store.filtered(month: scopeMonth, category: selectedCategory)
    }

    private var filteredTotal: Double {
        visibleTransactions.reduce(0) { $0 + ($1.category == "Income" ? 0 : $1.effectiveAmount) }
    }

    private var monthLabel: String {
        let cal = Calendar.current
        let sameYear = cal.isDate(monthAnchor, equalTo: Date(), toGranularity: .year)
        return monthAnchor.formatted(sameYear ? .dateTime.month(.wide)
                                              : .dateTime.month(.abbreviated).year())
    }

    private var heroTitle: String {
        monthOnly ? "Spent in \(monthLabel)" : "Spent all time"
    }

    private var canGoBack: Bool {
        guard let earliest = store.earliestDate else { return false }
        return Calendar.current.compare(monthAnchor, to: earliest, toGranularity: .month) == .orderedDescending
    }

    private var canGoForward: Bool {
        !Calendar.current.isDate(monthAnchor, equalTo: Date(), toGranularity: .month)
    }

    private func stepMonth(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = d
        }
    }

    var body: some View {
        List {
            Section {
                // One row so the 16pt gaps are exact (List adds quirky
                // spacing between separate rows).
                VStack(spacing: 16) {
                    if let error = store.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Picker("Scope", selection: $monthOnly) {
                        Text("Monthly").tag(true)
                        Text("All time").tag(false)
                    }
                    .pickerStyle(.segmented)

                    HeroSummary(title: heroTitle,
                                total: store.total(month: scopeMonth),
                                count: store.filtered(month: scopeMonth, category: nil).count,
                                showsMonthNav: monthOnly,
                                canGoBack: canGoBack,
                                canGoForward: canGoForward,
                                onStep: stepMonth)

                    CategoryFilterBar(categories: quickPickCategories, selected: $selectedCategory)
                }
                // Solid page-coloured backgrounds at BOTH the content and the
                // row layer: iOS 26 renders a subtle glass platter on list
                // cells that Color.clear leaves visible (rounded band on
                // device); an opaque same-as-page fill covers it at whichever
                // layer it lives.
                .background(Color(.systemGroupedBackground))
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color(.systemGroupedBackground))
                .listRowSeparator(.hidden)
            }

            Section {
                HStack {
                    Text(selectedCategory ?? "All transactions")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if selectedCategory != nil {
                        Text(inr(filteredTotal))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)

                if visibleTransactions.isEmpty {
                    EmptyTransactions(category: selectedCategory,
                                      monthLabel: monthOnly ? monthLabel : nil)
                        .listRowSeparator(.hidden)
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
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(12)   // filters → transactions card (internal gap)
        .scrollContentBackground(.hidden)
        .noScrollEdgeEffect()     // the platter may belong to the List's own scroller
        .background(Color(.systemGroupedBackground))
        .animation(.snappy, value: monthOnly)
        .animation(.snappy, value: monthAnchor)
        .animation(.snappy, value: selectedCategory)
    }
}

struct HeroSummary: View {
    let title: String
    let total: Double
    let count: Int
    var showsMonthNav = false
    var canGoBack = false
    var canGoForward = false
    var onStep: (Int) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                // Always in the layout so the card height never changes;
                // just faded out (and untappable) in all-time mode.
                HStack(spacing: 8) {
                    navButton("chevron.left", enabled: canGoBack) { onStep(-1) }
                    navButton("chevron.right", enabled: canGoForward) { onStep(1) }
                }
                .opacity(showsMonthNav ? 1 : 0)
                .allowsHitTesting(showsMonthNav)
            }

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
        // (no shadow: inside a List row it gets clipped to a rectangle and
        // shows as a broken band around the card)
    }

    private func navButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.white.opacity(enabled ? 0.22 : 0.10), in: Circle())
                .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.borderless)   // isolate taps inside the List row
        .disabled(!enabled)
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
        }
        // iOS 26 draws a rounded glass "lens" platter over horizontal
        // scrollers in lists — hide it (visible as a band behind the pills).
        .noScrollEdgeEffect()
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
                Text(relativeDay(tx.date))
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

// MARK: - Empty state

struct EmptyTransactions: View {
    let category: String?
    let monthLabel: String?   // nil = all time

    private var icon: String {
        category.map { CategoryStyle.of($0).icon } ?? "tray"
    }
    private var title: String {
        if let c = category { return "No \(c) yet" }
        if let m = monthLabel { return "Nothing spent in \(m)" }
        return "No transactions yet"
    }
    private var subtitle: String {
        category != nil
            ? "Try a different category or time range."
            : "Tap + to log your first expense."
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

// MARK: - Loading skeleton

struct LoadingSkeleton: View {
    var body: some View {
        List {
            Section {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(height: 128)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            Section {
                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(.tertiarySystemGroupedBackground))
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.tertiarySystemGroupedBackground))
                                .frame(width: 110, height: 11)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.tertiarySystemGroupedBackground))
                                .frame(width: 60, height: 9)
                        }
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.tertiarySystemGroupedBackground))
                            .frame(width: 48, height: 11)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(14)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .modifier(Pulse())
    }
}

/// Gentle opacity pulse for placeholder content while data loads.
struct Pulse: ViewModifier {
    @State private var dim = false
    func body(content: Content) -> some View {
        content
            .opacity(dim ? 0.5 : 1)
            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: dim)
            .onAppear { dim = true }
    }
}

// MARK: - Shared helpers

/// "Today" / "Yesterday" / weekday (within a week) / abbreviated date.
func relativeDay(_ date: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(date) { return "Today" }
    if cal.isDateInYesterday(date) { return "Yesterday" }
    let days = cal.dateComponents([.day],
                                  from: cal.startOfDay(for: date),
                                  to: cal.startOfDay(for: Date())).day ?? 0
    if days > 0 && days < 7 { return date.formatted(.dateTime.weekday(.wide)) }
    return date.formatted(date: .abbreviated, time: .omitted)
}

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
    /// Hide the iOS 26 scroll-edge glass platter; no-op on earlier iOS.
    @ViewBuilder
    func noScrollEdgeEffect() -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectHidden(true, for: .all)
        } else {
            self
        }
    }

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
