import SwiftUI

struct RootTabView: View {
    @StateObject private var settings: AppSettingsStore
    @StateObject private var chatViewModel: ChatViewModel

    init() {
        let settings = AppSettingsStore()
        _settings = StateObject(wrappedValue: settings)
        _chatViewModel = StateObject(
            wrappedValue: ChatViewModel(clientProvider: { settings.makeClient() })
        )
    }

    var body: some View {
        TabView {
            ChatView(viewModel: chatViewModel, isConfigured: settings.isConfigured)
                .tabItem {
                    Label("Chat", systemImage: "message")
                }

            WeatherDashboardView()
                .tabItem {
                    Label("Weather", systemImage: "cloud.sun")
                }

            SecurityDashboardView()
                .tabItem {
                    Label("Security", systemImage: "lock.shield")
                }

            FinanceDashboardView()
                .tabItem {
                    Label("Finance", systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView(settings: settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

private struct WeatherDashboardView: View {
    private let metrics: [(String, String)] = [
        ("Home Temp", "68 F"),
        ("Humidity", "44%"),
        ("7-Day Outlook", "Rain Tue, clear weekend")
    ]

    var body: some View {
        NavigationStack {
            List(metrics, id: \.0) { metric in
                LabeledContent(metric.0, value: metric.1)
            }
            .navigationTitle("Polar")
        }
    }
}

private struct SecurityDashboardView: View {
    private let events = [
        "Front Door: Locked",
        "Garage Camera: No motion",
        "Package Check: No package detected"
    ]

    var body: some View {
        NavigationStack {
            List(events, id: \.self) { event in
                Text(event)
            }
            .navigationTitle("Koala")
            .toolbar {
                Button("Lock All") {
                }
            }
        }
    }
}

private struct FinanceDashboardView: View {
    private let items: [(String, String)] = [
        ("Electric Bill", "+$18 vs last month"),
        ("Spending", "Within monthly budget"),
        ("Cash Flow", "Healthy")
    ]

    var body: some View {
        NavigationStack {
            List(items, id: \.0) { item in
                LabeledContent(item.0, value: item.1)
            }
            .navigationTitle("Kodiak")
        }
    }
}

#Preview {
    RootTabView()
}
