import SwiftUI

struct AddExpenseView: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var amount = ""
    @State private var merchant = ""
    @State private var category = "Food & Dining"
    @State private var saving = false

    private var amountValue: Double? { Double(amount) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                TextField("Merchant (optional)", text: $merchant)
                Picker("Category", selection: $category) {
                    ForEach(allCategories, id: \.self) { Text($0) }
                }
            }
            .navigationTitle("Add expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amt = amountValue else { return }
                        saving = true
                        Task {
                            await store.add(amount: amt, merchant: merchant, category: category)
                            dismiss()
                        }
                    }
                    .disabled(amountValue == nil || saving)
                }
            }
        }
    }
}

#Preview {
    AddExpenseView(store: Store())
}
