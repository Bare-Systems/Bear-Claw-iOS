import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var draft = ""
    @Published var messages: [ChatMessage] = []
    @Published var errorText: String?

    private let clientProvider: () -> BearClawClientProtocol

    init(clientProvider: @escaping () -> BearClawClientProtocol) {
        self.clientProvider = clientProvider
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        draft = ""
        messages.append(.init(role: .user, content: text))

        do {
            let response = try await clientProvider().sendMessage(text)
            messages.append(response)
            errorText = nil
        } catch {
            errorText = "Message failed. Check auth/session and try again."
        }
    }
}

extension ChatViewModel {
    static var preview: ChatViewModel {
        ChatViewModel(clientProvider: { PreviewClient() })
    }
}

struct PreviewClient: BearClawClientProtocol {
    func sendMessage(_ text: String) async throws -> ChatMessage {
        ChatMessage(role: .assistant, content: "Received: \(text)")
    }
}
