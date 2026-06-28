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

    private var amountValue: Double? { Double(amount) }

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
            ScrollView {
                VStack(spacing: 24) {
                    amountField
                    pillGrid
                    customField
                }
                .padding()
            }
            .navigationTitle(isEditing ? "Edit expense" : "New expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { saveBar }
            .scrollContentBackground(.hidden)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .onAppear(perform: prefill)
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
            Text("Amount")
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

    private var saveBar: some View {
        Button {
            guard let amt = amountValue else { return }
            saving = true
            Task {
                if let tx = editing {
                    await store.edit(tx, amount: amt, category: chosenCategory)
                } else {
                    await store.add(amount: amt, merchant: "", category: chosenCategory)
                }
                dismiss()
            }
        } label: {
            Text(saving ? "Saving…" : (isEditing ? "Save changes" : "Save expense"))
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.accentColor)
        .disabled(!canSave)
        .padding()
        .background(.ultraThinMaterial)
    }

    private func trimmed(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(d)
    }
}

#Preview {
    CaptureSheet(store: Store(), initialAmount: 250, editing: nil)
}
