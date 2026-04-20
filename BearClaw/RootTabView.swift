import SwiftUI

struct RootTabView: View {
    private enum Tab: Hashable {
        case chat
        case connection
        case settings
    }

    @StateObject private var settings: AppSettingsStore
    @StateObject private var chatViewModel: ChatViewModel
    @State private var selectedTab: Tab = .chat

    init(settings: AppSettingsStore? = nil, chatViewModel: ChatViewModel? = nil) {
        let resolvedSettings = settings ?? AppLaunch.makeSettingsStore()
        let resolvedViewModel = chatViewModel ?? ChatViewModel(clientProvider: { resolvedSettings.makeClient() })
        _settings = StateObject(wrappedValue: resolvedSettings)
        _chatViewModel = StateObject(wrappedValue: resolvedViewModel)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatView(viewModel: chatViewModel, isConfigured: settings.isConfigured)
                .tabItem {
                    Label("Chat", systemImage: "message")
                }
                .tag(Tab.chat)

            ConnectionStatusView(settings: settings, chatViewModel: chatViewModel)
                .tabItem {
                    Label("Connection", systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(Tab.connection)

            SettingsView(settings: settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
    }

    private func handleIncomingURL(_ url: URL) {
        do {
            try settings.applyPairingURL(url)
            selectedTab = .connection
        } catch {
            settings.recordPairingFailure(error)
            selectedTab = .settings
        }
    }
}
