import SwiftUI

struct ConnectionStatusView: View {
    @ObservedObject var settings: AppSettingsStore
    @ObservedObject var chatViewModel: ChatViewModel

    @State private var gatewayHealth: GatewayHealth?
    @State private var gatewayError: String?
    @State private var lastCheckedAt: Date?
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            List {
                Section("Gateway") {
                    LabeledContent("Endpoint", value: settings.endpointDisplayValue)
                        .accessibilityIdentifier("connection.endpoint")
                    LabeledContent("Reachability", value: gatewayReachabilityValue)
                        .accessibilityIdentifier("connection.gatewayState")
                    if let lastCheckedAt {
                        LabeledContent("Last Check", value: lastCheckedAt.formatted(date: .omitted, time: .shortened))
                    }
                }

                Section("Security") {
                    LabeledContent("Token Storage", value: settings.tokenStorageDescription)
                    LabeledContent("Bearer Token", value: settings.hasAuthToken ? "Loaded" : "Missing")
                    LabeledContent("Pinned Cert", value: settings.fingerprintDisplayValue)
                }

                Section("Session") {
                    LabeledContent("Chat Transport", value: settings.isConfigured ? "Server-sent events" : "Preview")
                    LabeledContent("Run State", value: chatViewModel.streamStateSummary)
                    LabeledContent("Last Run", value: chatViewModel.lastRunID ?? "No run yet")
                        .accessibilityIdentifier("connection.lastRun")
                    LabeledContent("Last Event", value: chatViewModel.lastEventDescription ?? "No stream events yet")
                }

                Section("Device") {
                    LabeledContent("Pairing Import", value: settings.lastPairingSource?.displayName ?? "None")
                    LabeledContent("Configured", value: settings.isConfigured ? "Ready" : "Incomplete")
                    if let importedAt = settings.lastPairingImportedAt {
                        LabeledContent("Imported At", value: importedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
            .navigationTitle("Connection")
            .toolbar {
                Button(isRefreshing ? "Refreshing..." : "Refresh") {
                    Task { await refresh() }
                }
                .disabled(isRefreshing)
            }
        }
        .task(id: refreshKey) {
            await refresh()
        }
    }

    private var refreshKey: String {
        "\(settings.apiBaseURL)|\(settings.authToken)|\(settings.pinnedCertFingerprint)"
    }

    private var gatewayReachabilityValue: String {
        if isRefreshing {
            return "Checking..."
        }
        if let gatewayHealth {
            return "\(gatewayHealth.service) (\(gatewayHealth.status))"
        }
        if let gatewayError {
            return gatewayError
        }
        return settings.isConfigured ? "Unknown" : "Not configured"
    }

    @MainActor
    private func refresh() async {
        guard settings.isConfigured else {
            gatewayHealth = nil
            gatewayError = nil
            lastCheckedAt = nil
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            gatewayHealth = try await settings.makeClient().fetchGatewayHealth()
            gatewayError = nil
            lastCheckedAt = Date()
        } catch let error as BearClawClientError {
            gatewayHealth = nil
            gatewayError = gatewayErrorText(error)
            lastCheckedAt = Date()
        } catch let error as URLError {
            gatewayHealth = nil
            gatewayError = error.localizedDescription
            lastCheckedAt = Date()
        } catch {
            gatewayHealth = nil
            gatewayError = "Health check failed"
            lastCheckedAt = Date()
        }
    }

    private func gatewayErrorText(_ error: BearClawClientError) -> String {
        switch error {
        case .unauthorized:
            return "Unauthorized"
        case let .apiError(_, message, _):
            return message
        case let .serverError(statusCode):
            return "HTTP \(statusCode)"
        case .invalidResponse, .invalidStreamEvent:
            return "Invalid response"
        }
    }
}
