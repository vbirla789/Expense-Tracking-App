import SwiftUI

/// Bottom sheet for adding a new expense (amount pre-filled from a transaction)
/// or editing an existing one. Sizes itself to its content.
struct CaptureSheet: View {
    @ObservedObject var store: Store
    var initialAmount: Double?
    var editing: Transaction?
    @Environment(\.dismiss) private var dismiss

    @State private var amount = ""
    @State private var selected = ""
    @State private var custom = ""
    @State private var saving = false
    @State private var formHeight: CGFloat = 620
    @State private var isSplit = false
    @State private var splitPeople: [String] = []
    @State private var showContacts = false
    /// Amount normally arrives pre-filled, so the keypad stays hidden until
    /// the amount card is tapped.
    @State private var showKeypad = false

    private var amountValue: Double? { Double(amount) }
    private var isSplitting: Bool { isSplit && !splitPeople.isEmpty }

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
        ScrollView {
            VStack(spacing: 14) {
                amountCard
                pillGrid
                if showCustom {
                    customField
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                splitSection
                if showKeypad {
                    Keypad(onTap: keyTapped)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { formHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, h in
                            withAnimation(.easeInOut(duration: 0.22)) { formHeight = h }
                        }
                }
            )
        }
        .scrollContentBackground(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .background(
            ContactPickerPresenter(isPresented: $showContacts) { names in
                if !names.isEmpty { withAnimation(.snappy(duration: 0.28)) { splitPeople = names } }
                if splitPeople.isEmpty { isSplit = false }
            }
        )
        .safeAreaInset(edge: .bottom) {
            ctaRow
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color.pageBG)
        }
        .presentationDetents([.height(formHeight + 84)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.pageBG)
        .onAppear(perform: prefill)
        .onChange(of: isSplit) { _, on in
            if on && splitPeople.isEmpty { showContacts = true }
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
            if tx.isSplit {
                isSplit = true
                splitPeople = tx.splitNames
            }
        } else if let a = initialAmount, a > 0 {
            amount = trimmed(a)
        }
    }

    // MARK: - Keypad input

    private func keyTapped(_ key: String) {
        switch key {
        case "⌫":
            if !amount.isEmpty { amount.removeLast() }
        case ".":
            if !amount.contains(".") { amount = amount.isEmpty ? "0." : amount + "." }
        default:
            // cap at 2 decimals / 9 digits
            if let dot = amount.firstIndex(of: "."),
               amount.distance(from: amount.index(after: dot), to: amount.endIndex) >= 2 { return }
            guard amount.count < 9 else { return }
            amount = (amount == "0") ? key : amount + key
        }
    }

    // MARK: - Pieces

    /// Tapping the card reveals/hides the keypad (amount is usually pre-filled).
    private var amountCard: some View {
        Button {
            withAnimation(.snappy(duration: 0.3)) { showKeypad.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(isSplitting ? "Total bill" : "Amount")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.inkSecondary)
                    Spacer()
                    Image(systemName: showKeypad ? "chevron.down" : "keyboard")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .frame(width: 30, height: 30)
                        .background(Color.toggleTrack, in: Circle())
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("₹")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(amount.isEmpty ? Color.inkSecondary : Color.ink)
                    Text(amount.isEmpty ? "0" : amount)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(amount.isEmpty ? Color.inkSecondary.opacity(0.6) : Color.ink)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBG, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(showKeypad ? Color.ink : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.15), value: amount)
    }

    private var pillGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.inkSecondary)
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
            withAnimation(.snappy(duration: 0.28)) {
                selected = cat
                if cat != "Others" { custom = "" }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: style.icon)
                    .font(.subheadline)
                    .foregroundStyle(isOn ? Color.white : style.color)
                Text(cat)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isOn ? Color.white : Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isOn ? Color.accentColor : Color.cardBG)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var customField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name this category")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.inkSecondary)
            TextField("e.g. Doctor, Gift…", text: $custom)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .foregroundStyle(Color.ink)
                .padding()
                .background(Color.cardBG, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isSplit.animation(.snappy(duration: 0.28))) {
                HStack(spacing: 10) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Split with group")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ink)
                        Text("Counts only your share")
                            .font(.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
            .tint(Color.accentColor)

            if isSplit && !splitPeople.isEmpty {
                HStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(splitPeople, id: \.self) { name in
                                Text(name)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .noScrollEdgeEffect()
                    Button { showContacts = true } label: {
                        Image(systemName: "pencil")
                            .font(.subheadline)
                            .foregroundStyle(Color.inkSecondary)
                            .frame(width: 36, height: 36)
                            .background(Color.toggleTrack, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.cardBG, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Save only — the sheet is dismissed by swiping down / tapping outside.
    private var ctaRow: some View {
        Button(action: save) {
            Text(saving ? "Saving…" : (isEditing ? "Save changes" : "Save expense"))
                .font(.headline)
                .foregroundStyle(canSave ? Color.white : Color.inkSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    canSave ? Color.accentColor : Color.toggleTrack,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private func save() {
        guard let amt = amountValue else { return }   // store the FULL bill; share is derived
        let note = isSplitting ? "split|" + splitPeople.joined(separator: ", ") : (editing?.raw ?? "")
        saving = true
        Task {
            if let tx = editing {
                await store.edit(tx, amount: amt, category: chosenCategory, note: note)
            } else {
                await store.add(amount: amt, merchant: "", category: chosenCategory, note: note)
            }
            dismiss()
        }
    }

    private func trimmed(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(d)
    }
}

// MARK: - Soft custom keypad

private struct Keypad: View {
    let onTap: (String) -> Void

    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    private func keyButton(_ key: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap(key)
        } label: {
            Group {
                if key == "⌫" {
                    Image(systemName: "delete.left")
                        .font(.system(size: 20, weight: .semibold))
                } else {
                    Text(key)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                }
            }
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                key == "⌫" ? Color.toggleTrack : Color.cardBG,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CaptureSheet(store: Store(), initialAmount: 250, editing: nil)
}
