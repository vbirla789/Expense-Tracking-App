import SwiftUI
@preconcurrency import Contacts

struct ContactItem: Identifiable, Hashable {
    let id: String
    let name: String
}

@MainActor
final class ContactsLoader: ObservableObject {
    @Published var contacts: [ContactItem] = []
    @Published var denied = false
    @Published var loading = true

    func load() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            if !granted {
                Task { @MainActor in self.denied = true; self.loading = false }
                return
            }
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey] as [CNKeyDescriptor]
            let req = CNContactFetchRequest(keysToFetch: keys)
            var items: [ContactItem] = []
            try? store.enumerateContacts(with: req) { c, _ in
                let formatted = CNContactFormatter.string(from: c, style: .fullName) ?? ""
                let name = formatted.isEmpty
                    ? [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                    : formatted
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { items.append(ContactItem(id: c.identifier, name: trimmed)) }
            }
            items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            Task { @MainActor in self.contacts = items; self.loading = false }
        }
    }
}

/// Custom contact list with search, checkmarks, and pre-selection.
struct ContactPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var loader = ContactsLoader()
    @State private var search = ""
    @State private var selected: Set<String>
    let onDone: ([String]) -> Void

    init(preselected: [String], onDone: @escaping ([String]) -> Void) {
        _selected = State(initialValue: Set(preselected))
        self.onDone = onDone
    }

    private var filtered: [ContactItem] {
        search.isEmpty ? loader.contacts
            : loader.contacts.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if loader.denied {
                    ContentUnavailableView("No contacts access", systemImage: "person.crop.circle.badge.xmark",
                        description: Text("Allow Contacts for Expenses in Settings to pick people."))
                } else if loader.loading {
                    ProgressView()
                } else {
                    List(filtered) { item in
                        Button {
                            if selected.contains(item.name) { selected.remove(item.name) }
                            else { selected.insert(item.name) }
                        } label: {
                            HStack {
                                Text(item.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: selected.contains(item.name) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(item.name) ? Color.accentColor : Color.secondary)
                            }
                        }
                    }
                    .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
                }
            }
            .navigationTitle("Split with")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone(Array(selected)); dismiss() }
                }
            }
            .onAppear { if loader.contacts.isEmpty && !loader.denied { loader.load() } }
        }
    }
}
