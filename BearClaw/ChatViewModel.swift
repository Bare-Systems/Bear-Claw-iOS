import Foundation
import Combine

struct ChatTimelineEvent: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let detail: String

    init(id: UUID = UUID(), title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var draft = ""
    @Published var messages: [ChatMessage] = []
    @Published var errorText: String?
    @Published private(set) var isStreaming = false
    @Published private(set) var lastRunID: String?
    @Published private(set) var lastEventDescription: String?
    @Published private(set) var lastCompletedAt: Date?
    @Published private(set) var timeline: [ChatTimelineEvent] = []

    private let clientProvider: () -> BearClawClientProtocol

    init(clientProvider: @escaping () -> BearClawClientProtocol) {
        self.clientProvider = clientProvider
    }

    var streamStateSummary: String {
        if isStreaming {
            return "Streaming"
        }
        if let lastCompletedAt {
            return "Idle after \(lastCompletedAt.formatted(date: .omitted, time: .shortened))"
        }
        return "Idle"
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        draft = ""
        errorText = nil
        messages.append(.init(role: .user, content: text))
        let assistantMessageID = UUID()
        messages.append(.init(id: assistantMessageID, role: .assistant, content: ""))
        timeline.removeAll()
        isStreaming = true
        lastEventDescription = "Connecting to stream..."

        defer {
            isStreaming = false
            lastCompletedAt = Date()
        }

        do {
            for try await update in clientProvider().streamMessage(text) {
                apply(update, assistantMessageID: assistantMessageID)
            }
            finalizeAssistantMessage(id: assistantMessageID)
            errorText = nil
        } catch {
            finalizeAssistantMessage(id: assistantMessageID)
            errorText = userFacingError(error)
            lastEventDescription = errorText
        }
    }

    private func apply(_ update: ChatStreamUpdate, assistantMessageID: UUID) {
        switch update {
        case let .connected(runID):
            lastRunID = runID
            lastEventDescription = runID.map { "Connected to run \($0)" } ?? "Connected"
            appendTimeline(title: "Connected", detail: lastEventDescription ?? "Connected")
        case let .event(event):
            lastRunID = event.runID
            let summary = summarize(event)
            lastEventDescription = summary.detail
            appendTimeline(title: summary.title, detail: summary.detail)

            if event.type == "model_output", let content = event.content {
                updateAssistantMessage(id: assistantMessageID, content: content)
            }

            if event.type == "error" {
                errorText = summary.detail
            }
        }
    }

    private func appendTimeline(title: String, detail: String) {
        timeline.append(.init(title: title, detail: detail))
        if timeline.count > 8 {
            timeline.removeFirst(timeline.count - 8)
        }
    }

    private func updateAssistantMessage(id: UUID, content: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index] = ChatMessage(id: id, role: .assistant, content: content, timestamp: messages[index].timestamp)
    }

    private func finalizeAssistantMessage(id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        if messages[index].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.remove(at: index)
        }
    }

    private func summarize(_ event: RunStreamEvent) -> (title: String, detail: String) {
        switch event.type {
        case "prompt":
            return ("Prompt", event.content ?? "Prompt queued")
        case "tool_call":
            if let tool = event.tool, let arguments = event.arguments, !arguments.isEmpty {
                return ("Tool Call", "\(tool) \(arguments)")
            }
            return ("Tool Call", event.tool ?? "Running tool")
        case "tool_result":
            let detail = event.content ?? event.message ?? (event.success == true ? "Tool succeeded" : "Tool finished")
            return ("Tool Result", detail)
        case "model_output":
            return ("Model Output", event.content ?? "Assistant replied")
        case "error":
            return ("Error", event.message ?? event.code ?? "Run failed")
        case "done":
            return ("Done", "Run completed")
        default:
            return (event.type.replacingOccurrences(of: "_", with: " ").capitalized, event.message ?? event.content ?? "Event received")
        }
    }

    private func userFacingError(_ error: Error) -> String {
        if let clientError = error as? BearClawClientError {
            switch clientError {
            case .unauthorized:
                return "Unauthorized. Update your bearer token in Settings."
            case let .apiError(code, message, _):
                switch code {
                case .upstreamTimeout:
                    return "Gateway timed out. Try again."
                case .rateLimited:
                    return "Rate limited. Wait a moment and retry."
                default:
                    return "Request failed: \(message)"
                }
            case .serverError:
                return "Gateway error. Try again shortly."
            case .invalidResponse, .invalidStreamEvent:
                return "Gateway returned an invalid response."
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection."
            case .timedOut:
                return "Network timeout. Try again."
            default:
                return "Network request failed."
            }
        }

        return "Message failed. Check gateway URL and token in Settings."
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

    func streamMessage(_ text: String) -> AsyncThrowingStream<ChatStreamUpdate, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.connected(runID: "preview-run"))
            continuation.yield(.event(.init(type: "model_output", runID: "preview-run", userID: nil, deviceID: nil, scopes: nil, timestamp: nil, tool: nil, arguments: nil, success: nil, content: "Received: \(text)", code: nil, message: nil)))
            continuation.yield(.event(.init(type: "done", runID: "preview-run", userID: nil, deviceID: nil, scopes: nil, timestamp: nil, tool: nil, arguments: nil, success: nil, content: nil, code: nil, message: nil)))
            continuation.finish()
        }
    }

    func fetchGatewayHealth() async throws -> GatewayHealth {
        GatewayHealth(status: "ok", service: "preview")
    }
}
