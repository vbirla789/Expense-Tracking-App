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

    /// The "Or type your own" field only appears when Others is selected.
    private var showCustom: Bool { selected == "Others" }

    private var chosenCategory: String {
        if selected == "Others" {
            let c = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            return c.isEmpty ? "Others" : c
        }
        return selected
    }

    private var canSave: Bool {
        (amountValue ?? 0) > 0 && !selected.isEmpty && !saving
    }

    private var isEditing: Bool { editing != nil }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    amountField
                    pillGrid
                    if showCustom { customField }
                    splitSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 26)
                .padding(.bottom, 8)
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
        .presentationDetents([.height(formHeight + 110)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .onAppear(perform: prefill)
        .onChange(of: isSplit) { _, on in
            if on && splitPeople.isEmpty { showContacts = true }
        }
        .onPreferenceChange(SheetHeightKey.self) { formHeight = $0 }
        .sheet(isPresented: $showContacts) {
            ContactPicker { names in
                if !names.isEmpty { splitPeople = names }
                showContacts = false
                if splitPeople.isEmpty { isSplit = false }
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
                selected = "Others"
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
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        let isOn = selected == cat
        return Button {
            selected = cat
            if cat != "Others" { custom = "" }
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
            Text("Name this category")
                .font(.caption).foregroundStyle(.secondary)
            TextField("e.g. Doctor, Gift…", text: $custom)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

            if isSplit && !splitPeople.isEmpty {
                Button { showContacts = true } label: {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                        Text("Split between you + \(splitPeople.count)")
                        Spacer()
                        Image(systemName: "pencil").font(.caption2).foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

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

    private var saveBar: some View {
        Button(action: save) {
            Text(saving ? "Saving…" : (isEditing ? "Save changes" : "Save expense"))
                .font(.headline)
                .foregroundStyle(canSave ? Color.white : Color.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    canSave ? Color.accentColor : Color(.systemGray5),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(progressiveBlur)
    }

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
