import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettingsStore

    var body: some View {
        NavigationStack {
            Form {
                Section("BearClaw Gateway") {
                    TextField("https://example.com", text: $settings.apiBaseURL)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                    SecureField("Bearer token", text: $settings.authToken)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }

                Section("Status") {
                    LabeledContent("Chat Mode", value: settings.isConfigured ? "Live API" : "Preview")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView(settings: AppSettingsStore())
}
