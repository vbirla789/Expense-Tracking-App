import SwiftUI

/// Bottom sheet for adding a new expense (amount pre-filled from a transaction)
/// or editing an existing one.
struct CaptureSheet: View {
    @ObservedObject var store: Store
    var initialAmount: Double?
    var editing: Transaction?
    @Environment(\.dismiss) private var dismiss

    @State private var amount = ""
    @State private var selected = ""
    @State private var custom = ""
    @State private var saving = false
    @State private var formHeight: CGFloat = 460
    @State private var isSplit = false
    @State private var splitPeople: [String] = []
    @State private var showContacts = false

    private var amountValue: Double? { Double(amount) }

    private var isSplitting: Bool { isSplit && !splitPeople.isEmpty }

    /// Your share = bill ÷ (the people you picked + you).
    private var shareAmount: Double? {
        guard let amt = amountValue else { return nil }
        return isSplitting ? amt / Double(splitPeople.count + 1) : amt
    }

    private var chosenCategory: String {
        let c = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        return c.isEmpty ? selected : c
    }

    private var canSave: Bool {
        (amountValue ?? 0) > 0 && !chosenCategory.isEmpty && !saving
    }

    private var isEditing: Bool { editing != nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        amountField
                        pillGrid
                        customField
                        splitSection
                    }
                    .padding()
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: SheetHeightKey.self, value: geo.size.height)
                        }
                    )
                }
                .scrollContentBackground(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                saveBar
            }
            .navigationTitle(isEditing ? "Edit expense" : "New expense")
            .navigationBarTitleDisplayMode(.inline)
            .onPreferenceChange(SheetHeightKey.self) { formHeight = $0 }
        }
        .presentationDetents([.height(formHeight + 148)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .onAppear(perform: prefill)
        .sheet(isPresented: $showContacts) {
            ContactPicker { names in
                if !names.isEmpty { splitPeople = names }
                showContacts = false
            }
            .ignoresSafeArea()
        }
    }

    private func prefill() {
        if let tx = editing {
            amount = trimmed(tx.amount)
            if quickPickCategories.contains(tx.category) {
                selected = tx.category
            } else {
                custom = tx.category
            }
        } else if let a = initialAmount, a > 0 {
            amount = trimmed(a)
        }
    }

    // MARK: - Pieces

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isSplitting ? "Total bill" : "Amount")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text("₹").font(.largeTitle).foregroundStyle(.secondary)
                TextField("0", text: $amount)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
            }
            .padding()
            .glassCard(cornerRadius: 18)
        }
    }

    private var pillGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                ForEach(quickPickCategories, id: \.self) { cat in
                    pill(cat)
                }
            }
        }
    }

    private func pill(_ cat: String) -> some View {
        let style = CategoryStyle.of(cat)
        let isOn = selected == cat && custom.isEmpty
        return Button {
            withAnimation(.snappy) { selected = cat; custom = "" }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: style.icon).font(.subheadline)
                Text(cat)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isOn ? style.color : style.color.opacity(0.15))
            .foregroundStyle(isOn ? Color.white : style.color)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var customField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Or type your own")
                .font(.caption).foregroundStyle(.secondary)
            TextField("e.g. Doctor, Gift…", text: $custom)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding()
                .glassCard(cornerRadius: 14)
                .onChange(of: custom) { _, value in
                    if !value.isEmpty { selected = "" }
                }
        }
    }

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isSplit.animation()) {
                HStack(spacing: 10) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Split with group").font(.subheadline.weight(.medium))
                        Text("Counts only your share").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .tint(Color.accentColor)

            if isSplit {
                Button { showContacts = true } label: {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                        Text(splitPeople.isEmpty ? "Add people" : "Split between you + \(splitPeople.count)")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                if !splitPeople.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(splitPeople, id: \.self) { name in
                                Text(name)
                                    .font(.caption)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    if let share = shareAmount {
                        HStack {
                            Text("Your share").foregroundStyle(.secondary)
                            Spacer()
                            Text(inr(share)).fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    private var saveBar: some View {
        Button(action: save) {
            Text(saving ? "Saving…" : (isEditing ? "Save changes" : "Save expense"))
                .font(.headline)
                .foregroundStyle(canSave ? Color.white : Color.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)                       // CTA height: 52pt
                .background(
                    canSave ? Color.accentColor : Color(.systemGray5),   // solid grey when disabled
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)                            // 24pt from the bottom
        .background(progressiveBlur)
    }

    /// Variable "progressive" blur — frosted at the bottom, fading to clear
    /// upward, like the bottom bars in Apple Music / Maps.
    private var progressiveBlur: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.6), location: 0.3),
                        .init(color: .black, location: 0.7)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .ignoresSafeArea()
    }

    private func save() {
        guard let finalAmount = shareAmount else { return }
        let note = isSplitting ? "split|" + splitPeople.joined(separator: ", ") : (editing?.raw ?? "")
        saving = true
        Task {
            if let tx = editing {
                await store.edit(tx, amount: finalAmount, category: chosenCategory, note: note)
            } else {
                await store.add(amount: finalAmount, merchant: "", category: chosenCategory, note: note)
            }
            dismiss()
        }
    }

    private func trimmed(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(d)
    }
}

/// Reports the natural height of the form content so the sheet can size to fit.
private struct SheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 460
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    CaptureSheet(store: Store(), initialAmount: 250, editing: nil)
}
