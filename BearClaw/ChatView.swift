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
                        .accessibilityIdentifier("chat.previewBanner")
                }

                if viewModel.isStreaming || viewModel.lastRunID != nil || viewModel.lastEventDescription != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            if viewModel.isStreaming {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(viewModel.streamStateSummary)
                                .font(.subheadline.weight(.semibold))
                                .accessibilityIdentifier("chat.streamState")
                        }

                        if let runID = viewModel.lastRunID {
                            Text("Run \(runID)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("chat.runID")
                        }

                        if let lastEventDescription = viewModel.lastEventDescription {
                            Text(lastEventDescription)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("chat.lastEvent")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                List {
                    if !viewModel.timeline.isEmpty {
                        Section("Live Run") {
                            ForEach(viewModel.timeline) { event in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(event.detail)
                                        .font(.footnote)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Section("Messages") {
                        ForEach(viewModel.messages) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message.role.rawValue.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(message.content.isEmpty ? "Waiting for response..." : message.content)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .accessibilityIdentifier("chat.message.\(message.role.rawValue)")
                        }
                    }
                }
                .listStyle(.plain)
                .accessibilityIdentifier("chat.messages")

                if let errorText = viewModel.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("chat.errorText")
                }

                HStack {
                    TextField("Message BearClaw...", text: $viewModel.draft)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.isStreaming)
                        .accessibilityIdentifier("chat.messageInput")
                    Button("Send") {
                        Task { await viewModel.send() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isStreaming)
                    .accessibilityIdentifier("chat.sendButton")
                }
            }
            .padding()
            .navigationTitle("BearClaw Chat")
        }
    }
}
