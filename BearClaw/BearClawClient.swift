import Foundation

enum BearClawClientError: Error, Equatable {
    case invalidResponse
    case invalidStreamEvent
    case unauthorized
    case apiError(code: ChatErrorCode, message: String, requestID: String?)
    case serverError(statusCode: Int)
}

protocol BearClawClientProtocol: Sendable {
    func sendMessage(_ text: String) async throws -> ChatMessage
    func streamMessage(_ text: String) -> AsyncThrowingStream<ChatStreamUpdate, Error>
    func fetchGatewayHealth() async throws -> GatewayHealth
}

private struct ServerSentEvent: Equatable, Sendable {
    let event: String
    let data: String
}

final class BearClawClient: BearClawClientProtocol, @unchecked Sendable {
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
        let request = try makeJSONRequest(path: "v1/chat", text: text)
        let (data, response) = try await session.data(for: request)
        let httpResponse = try validateHTTPResponse(response)
        switch httpResponse.statusCode {
        case 200:
            if let envelope = try? JSONDecoder().decode(ChatResponse.self, from: data) {
                return envelope.message
            }
            return try JSONDecoder().decode(ChatMessage.self, from: data)
        default:
            throw Self.mapError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    func streamMessage(_ text: String) -> AsyncThrowingStream<ChatStreamUpdate, Error> {
        let endpoint = baseURL
        let session = self.session
        let authTokenProvider = self.authTokenProvider

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: endpoint.appending(path: "v1/chat/stream"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    if let token = authTokenProvider() {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }
                    request.httpBody = try JSONEncoder().encode(ChatRequest(message: text))

                    let (bytes, response) = try await session.bytes(for: request)
                    let httpResponse = try validateHTTPResponse(response)
                    switch httpResponse.statusCode {
                    case 200:
                        continuation.yield(.connected(runID: httpResponse.value(forHTTPHeaderField: "X-Run-ID")))
                        try await Self.consumeServerSentEvents(from: bytes) { frame in
                            guard let data = frame.data.data(using: .utf8) else {
                                throw BearClawClientError.invalidStreamEvent
                            }
                            let event = try JSONDecoder().decode(RunStreamEvent.self, from: data)
                            continuation.yield(.event(event))
                        }
                        continuation.finish()
                    default:
                        let data = try await Self.collectData(from: bytes)
                        throw Self.mapError(statusCode: httpResponse.statusCode, data: data)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func fetchGatewayHealth() async throws -> GatewayHealth {
        var request = URLRequest(url: baseURL.appending(path: "health"))
        request.httpMethod = "GET"
        if let token = authTokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        let httpResponse = try validateHTTPResponse(response)
        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(GatewayHealth.self, from: data)
        default:
            throw Self.mapError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    private func makeJSONRequest(path: String, text: String) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authTokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(ChatRequest(message: text))
        return request
    }

    private func validateHTTPResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BearClawClientError.invalidResponse
        }
        return httpResponse
    }

    private static func mapError(statusCode: Int, data: Data) -> BearClawClientError {
        switch statusCode {
        case 401:
            return .unauthorized
        case 400..<600:
            if let apiError = try? JSONDecoder().decode(ChatErrorResponse.self, from: data) {
                return .apiError(
                    code: apiError.code,
                    message: apiError.message,
                    requestID: apiError.requestID
                )
            }
            return .serverError(statusCode: statusCode)
        default:
            return .invalidResponse
        }
    }

    private static func collectData(from bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        return data
    }

    private static func consumeServerSentEvents(
        from bytes: URLSession.AsyncBytes,
        onEvent: @escaping @Sendable (ServerSentEvent) throws -> Void
    ) async throws {
        var currentEvent = ""
        var currentDataLines: [String] = []

        func flushFrame() throws {
            guard !currentEvent.isEmpty || !currentDataLines.isEmpty else { return }
            let frame = ServerSentEvent(
                event: currentEvent.isEmpty ? "message" : currentEvent,
                data: currentDataLines.joined(separator: "\n")
            )
            try onEvent(frame)
            currentEvent = ""
            currentDataLines.removeAll(keepingCapacity: true)
        }

        for try await line in bytes.lines {
            if Task.isCancelled {
                throw CancellationError()
            }

            if line.isEmpty {
                try flushFrame()
                continue
            }

            if line.hasPrefix(":") {
                continue
            }

            if let value = parseField(prefix: "event:", line: line) {
                currentEvent = value
                continue
            }

            if let value = parseField(prefix: "data:", line: line) {
                currentDataLines.append(value)
            }
        }

        try flushFrame()
    }

    private static func parseField(prefix: String, line: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        let value = line.dropFirst(prefix.count)
        if value.first == " " {
            return String(value.dropFirst())
        }
        return String(value)
    }
}
