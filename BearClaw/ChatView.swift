import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    let isConfigured: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if !isConfigured {
                    Text("Running in local preview mode. Configure API in Settings to use BearClaw.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                List(viewModel.messages) { message in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.role.rawValue.uppercased())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(message.content)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                }
                .listStyle(.plain)

                if let errorText = viewModel.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    TextField("Message BearClaw...", text: $viewModel.draft)
                        .textFieldStyle(.roundedBorder)
                    Button("Send") {
                        Task { await viewModel.send() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("BearClaw Chat")
        }
    }
}

#Preview {
    ChatView(viewModel: .preview, isConfigured: false)
}
