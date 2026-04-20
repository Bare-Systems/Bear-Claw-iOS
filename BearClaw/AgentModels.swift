import Foundation

struct ChatRequest: Codable, Equatable, Sendable {
    let message: String

    init(message: String) {
        self.message = message
    }
}

struct ChatResponse: Codable, Equatable, Sendable {
    let message: ChatMessage
    let requiresConfirmation: Bool
    let confirmationReason: String?

    init(
        message: ChatMessage,
        requiresConfirmation: Bool = false,
        confirmationReason: String? = nil
    ) {
        self.message = message
        self.requiresConfirmation = requiresConfirmation
        self.confirmationReason = confirmationReason
    }
}

enum ChatErrorCode: String, Codable, Equatable, Sendable {
    case unauthorized
    case invalidRequest = "invalid_request"
    case rateLimited = "rate_limited"
    case toolUnavailable = "tool_unavailable"
    case upstreamTimeout = "upstream_timeout"
    case internalError = "internal_error"
}

struct ChatErrorResponse: Codable, Equatable, Sendable {
    let code: ChatErrorCode
    let message: String
    let requestID: String?

    init(code: ChatErrorCode, message: String, requestID: String? = nil) {
        self.code = code
        self.message = message
        self.requestID = requestID
    }

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case requestID = "request_id"
    }
}

struct ChatMessage: Codable, Identifiable, Equatable, Sendable {
    enum Role: String, Codable, Sendable {
        case user
        case assistant
        case system
    }

    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

struct GatewayHealth: Codable, Equatable, Sendable {
    let status: String
    let service: String
}

struct RunStreamEvent: Codable, Equatable, Sendable {
    let type: String
    let runID: String
    let userID: String?
    let deviceID: String?
    let scopes: String?
    let timestamp: Int?
    let tool: String?
    let arguments: String?
    let success: Bool?
    let content: String?
    let code: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case type
        case runID = "run_id"
        case userID = "user_id"
        case deviceID = "device_id"
        case scopes
        case timestamp = "ts"
        case tool
        case arguments
        case success
        case content
        case code
        case message
    }
}

enum ChatStreamUpdate: Equatable, Sendable {
    case connected(runID: String?)
    case event(RunStreamEvent)
}

struct AgentActionRequest: Codable, Equatable, Sendable {
    let action: String
    let arguments: [String: String]

    init(action: String, arguments: [String: String] = [:]) {
        self.action = action
        self.arguments = arguments
    }
}

struct AgentActionResult: Codable, Equatable, Sendable {
    let action: String
    let success: Bool
    let summary: String

    init(action: String, success: Bool, summary: String) {
        self.action = action
        self.success = success
        self.summary = summary
    }
}
