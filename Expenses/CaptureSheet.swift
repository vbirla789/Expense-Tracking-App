import SwiftUI

/// The bottom sheet that appears after a transaction (or via the "+" button):
/// amount pre-filled, quick category pills, a custom category field, and Save.
struct CaptureSheet: View {
    @ObservedObject var store: Store
    var initialAmount: Double?
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
            .navigationTitle("New expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { saveBar }
            .background(Color(.systemGroupedBackground))
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let a = initialAmount, a > 0 { amount = trimmed(a) }
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
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var pillGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)],
                      alignment: .leading, spacing: 10) {
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
            selected = cat
            custom = ""
        } label: {
            HStack(spacing: 6) {
                Image(systemName: style.icon).font(.caption)
                Text(cat).font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
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
            TextField("e.g. Ciggs, Cab, Rent…", text: $custom)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
                await store.add(amount: amt, merchant: "", category: chosenCategory)
                dismiss()
            }
        } label: {
            Text(saving ? "Saving…" : "Save expense")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canSave)
        .padding()
        .background(.bar)
    }

    private func trimmed(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(d)
    }
}

#Preview {
    CaptureSheet(store: Store(), initialAmount: 250)
}
