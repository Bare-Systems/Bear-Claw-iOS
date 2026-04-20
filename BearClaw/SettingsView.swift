import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var settings: AppSettingsStore
    @State private var pairingInput = ""
    @State private var selectedQRCodeImage: PhotosPickerItem?
    @State private var showingFileImporter = false

    var body: some View {
        NavigationStack {
            Form {
                Section("BearClaw Gateway") {
                    TextField("https://example.com", text: $settings.apiBaseURL)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .accessibilityIdentifier("settings.apiBaseURL")
                    SecureField("Bearer token", text: $settings.authToken)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .accessibilityIdentifier("settings.authToken")
                    TextField("Pinned cert SHA256", text: $settings.pinnedCertFingerprint)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .accessibilityIdentifier("settings.pinnedCertFingerprint")
                }

                Section("Pairing") {
                    TextField("Paste pairing JSON or tardi1: code", text: $pairingInput, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .accessibilityIdentifier("settings.pairingInput")

                    Button("Import Pasted Payload") {
                        importPastedPayload()
                    }
                    .accessibilityIdentifier("settings.importPairingButton")

                    PhotosPicker(
                        selection: $selectedQRCodeImage,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Import From QR Image", systemImage: "qrcode.viewfinder")
                    }
                    .accessibilityIdentifier("settings.importQRCodeButton")

                    Button("Import Shared File") {
                        showingFileImporter = true
                    }
                    .accessibilityIdentifier("settings.importFileButton")

                    if let pairingStatus = settings.pairingStatusMessage {
                        Text(pairingStatus)
                            .font(.footnote)
                            .foregroundStyle(settings.pairingStatusIsError ? .red : .green)
                            .accessibilityIdentifier("settings.pairingStatus")
                    }
                }

                Section("Status") {
                    LabeledContent("Chat Mode", value: settings.isConfigured ? "Live SSE" : "Preview")
                    LabeledContent("Token Storage", value: settings.tokenStorageDescription)
                    if let source = settings.lastPairingSource {
                        LabeledContent("Last Pairing", value: source.displayName)
                    }
                    if !settings.isConfigured && !settings.apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Use HTTPS for remote gateways. HTTP is only allowed for localhost.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .accessibilityIdentifier("settings.gatewayWarning")
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json, .plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .onChange(of: selectedQRCodeImage) { _, newItem in
            guard let newItem else { return }
            Task { await importQRCodeImage(newItem) }
        }
    }

    private func importPastedPayload() {
        do {
            try settings.applyPairingPayload(pairingInput, source: .manualPaste)
            pairingInput = ""
        } catch {
            settings.recordPairingFailure(error)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            try settings.applyPairingURL(url)
        } catch {
            settings.recordPairingFailure(error)
        }
    }

    @MainActor
    private func importQRCodeImage(_ item: PhotosPickerItem) async {
        defer { selectedQRCodeImage = nil }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw TardiPairingError.invalidQRCode
            }
            try settings.applyPairingQRCodeImage(data)
        } catch {
            settings.recordPairingFailure(error)
        }
    }
}
