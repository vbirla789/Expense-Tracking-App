import SwiftUI
import ContactsUI

/// Native multi-select contact picker. Uses the system picker, which runs
/// out-of-process — so it needs NO contacts-permission prompt; the app only
/// ever receives the people you explicitly tick.
struct ContactPicker: UIViewControllerRepresentable {
    var onSelect: ([String]) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: ([String]) -> Void
        init(onSelect: @escaping ([String]) -> Void) { self.onSelect = onSelect }

        // Implementing ONLY the plural delegate makes the picker multi-select
        // (checkmarks + a Done button).
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            let names = contacts.map { c -> String in
                let full = CNContactFormatter.string(from: c, style: .fullName) ?? ""
                if !full.isEmpty { return full }
                let parts = [c.givenName, c.familyName].filter { !$0.isEmpty }
                return parts.isEmpty ? "Someone" : parts.joined(separator: " ")
            }
            onSelect(names)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onSelect([])
        }
    }
}
