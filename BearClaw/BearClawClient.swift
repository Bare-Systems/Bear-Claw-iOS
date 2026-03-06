import Foundation

enum BearClawClientError: Error, Equatable {
    case invalidResponse
    case unauthorized
    case apiError(code: ChatErrorCode, message: String, requestID: String?)
    case serverError(statusCode: Int)
}

protocol BearClawClientProtocol: Sendable {
    func sendMessage(_ text: String) async throws -> ChatMessage
}

actor BearClawClient: BearClawClientProtocol {
    private let baseURL: URL
    private let authTokenProvider: @Sendable () -> String?
    private let session: URLSession

    init(
        baseURL: URL,
        session: URLSession = .shared,
        authTokenProvider: @escaping @Sendable () -> String?
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authTokenProvider = authTokenProvider
    }

    func sendMessage(_ text: String) async throws -> ChatMessage {
        let endpoint = baseURL.appending(path: "v1/chat")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authTokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(ChatRequest(message: text))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BearClawClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            if let envelope = try? JSONDecoder().decode(ChatResponse.self, from: data) {
                return envelope.message
            }
            return try JSONDecoder().decode(ChatMessage.self, from: data)
        case 401:
            throw BearClawClientError.unauthorized
        case 400..<600:
            if let apiError = try? JSONDecoder().decode(ChatErrorResponse.self, from: data) {
                throw BearClawClientError.apiError(
                    code: apiError.code,
                    message: apiError.message,
                    requestID: apiError.requestID
                )
            }
            throw BearClawClientError.serverError(statusCode: httpResponse.statusCode)
        default:
            throw BearClawClientError.invalidResponse
        }
    }
}
