import SwiftUI

struct SettingsView: View {
    var onSave: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    @State private var endpoint = Settings.endpoint
    @State private var token = Settings.token

    var body: some View {
        NavigationStack {
            Form {
                Section("Google Apps Script") {
                    TextField("Web App URL (ends in /exec)", text: $endpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("Secret token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Text("Use the same Web App URL and SECRET from your Apps Script deployment. They're stored only on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Settings.endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
                        Settings.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
