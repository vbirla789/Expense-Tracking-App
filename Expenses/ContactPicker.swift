import SwiftUI
import ContactsUI

/// Presents Apple's native multi-select contact picker *imperatively* from a
/// hidden host controller. Presenting it this way (instead of a SwiftUI .sheet)
/// means dismissing the picker never dismisses the capture sheet behind it.
/// No contacts permission needed — the system picker returns only who you tick.
struct ContactPickerPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onSelect: ([String]) -> Void

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        if isPresented, host.presentedViewController == nil, !context.coordinator.presenting {
            context.coordinator.presenting = true
            let picker = CNContactPickerViewController()
            picker.delegate = context.coordinator
            host.present(picker, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPickerPresenter
        var presenting = false
        init(_ parent: ContactPickerPresenter) { self.parent = parent }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.onSelect(contacts.map(name))
            finish()
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.onSelect([])
            finish()
        }

        private func finish() {
            presenting = false
            parent.isPresented = false
        }

        private func name(_ c: CNContact) -> String {
            let full = CNContactFormatter.string(from: c, style: .fullName) ?? ""
            if !full.isEmpty { return full }
            let parts = [c.givenName, c.familyName].filter { !$0.isEmpty }
            return parts.isEmpty ? "Someone" : parts.joined(separator: " ")
        }
    }
}
