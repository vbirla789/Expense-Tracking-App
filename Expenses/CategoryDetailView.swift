import SwiftUI

/// Drill-down filter: total for one category + the transactions that make it up.
struct CategoryDetailView: View {
    @ObservedObject var store: Store
    let category: String
    var monthOnly: Bool

    var body: some View {
        let txns = store.transactions(in: category, monthOnly: monthOnly)
        let total = txns.reduce(0) { $0 + $1.amount }
        let style = CategoryStyle.of(category)

        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    iconBubble(style)
                    Text("Total in \(category)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(inr(total))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("\(txns.count) transaction\(txns.count == 1 ? "" : "s") · \(monthOnly ? "this month" : "all time")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .cardStyle()

                if txns.isEmpty {
                    Text("No transactions in this category yet.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(txns.enumerated()), id: \.element.id) { idx, tx in
                            if idx > 0 { Divider().padding(.leading, 52) }
                            TransactionRow(tx: tx, store: store)
                        }
                    }
                    .cardStyle()
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.inline)
    }
}
