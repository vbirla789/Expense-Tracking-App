import SwiftUI
import Combine
import Contacts

struct ContactItem: Identifiable, Hashable {
    let id: String
    let name: String
}

@MainActor
final class ContactsLoader: ObservableObject {
    @Published var contacts: [ContactItem] = []
    @Published var denied = false
    @Published var loading = true

    func load() async {
        loading = true
        denied = false
        let granted = await Self.requestAccess()
        if !granted {
            denied = true
            loading = false
            return
        }
        contacts = await Self.fetchContacts()
        loading = false
    }

    private static func requestAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            CNContactStore().requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private static func fetchContacts() async -> [ContactItem] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let store = CNContactStore()
                let keys = [CNContactGivenNameKey, CNContactFamilyNameKey] as [CNKeyDescriptor]
                let request = CNContactFetchRequest(keysToFetch: keys)
                var result: [ContactItem] = []
                do {
                    try store.enumerateContacts(with: request) { contact, _ in
                        let formatted = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
                        let name = formatted.isEmpty
                            ? [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                            : formatted
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            result.append(ContactItem(id: contact.identifier, name: trimmed))
                        }
                    }
                } catch {
                    // return whatever was collected
                }
                let sorted = result.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                continuation.resume(returning: sorted)
            }
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .task {
                if loader.contacts.isEmpty && !loader.denied {
                    await loader.load()
                }
            }
        }
    }
}
