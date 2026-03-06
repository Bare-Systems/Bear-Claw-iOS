import Testing
import Foundation
@testable import iOS

@Suite(.serialized)
struct iOSTests {
    @Test func actionResultPreservesPayload() {
        let result = AgentActionResult(action: "lock_doors", success: true, summary: "Doors locked")
        #expect(result.action == "lock_doors")
        #expect(result.success)
    }

    @Test func chatErrorResponseDecodesRequestID() throws {
        let data = Data("""
        {"code":"rate_limited","message":"Slow down","request_id":"req_123"}
        """.utf8)
        let decoded = try JSONDecoder().decode(ChatErrorResponse.self, from: data)
        #expect(decoded.code == .rateLimited)
        #expect(decoded.message == "Slow down")
        #expect(decoded.requestID == "req_123")
    }

    @Test func bearClawClientSendsChatRequestAndDecodesEnvelope() async throws {
        let expected = ChatMessage(
            id: UUID(uuidString: "E53AB489-EAA6-48E7-A644-70BC8B3D1F76")!,
            role: .assistant,
            content: "Hi from BearClaw",
            timestamp: Date(timeIntervalSince1970: 1_710_000_000)
        )
        let responseBody = try JSONEncoder().encode(ChatResponse(message: expected))

        await MockURLProtocolStore.shared.setHandler { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://example.com/v1/chat")

            let sent = try JSONDecoder().decode(ChatRequest.self, from: try bodyData(from: request))
            #expect(sent.message == "hello")

            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseBody)
        }

        let client = BearClawClient(
            baseURL: URL(string: "https://example.com")!,
            session: makeMockSession(),
            authTokenProvider: { "token-123" }
        )

        let actual = try await client.sendMessage("hello")
        #expect(actual == expected)
    }

    @Test func bearClawClientMapsTypedAPIErrors() async throws {
        let responseBody = Data("""
        {"code":"rate_limited","message":"Try again in 60 seconds","request_id":"req_429"}
        """.utf8)

        await MockURLProtocolStore.shared.setHandler { request in
            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseBody)
        }

        let client = BearClawClient(
            baseURL: URL(string: "https://example.com")!,
            session: makeMockSession(),
            authTokenProvider: { nil }
        )

        await #expect(throws: BearClawClientError.apiError(
            code: .rateLimited,
            message: "Try again in 60 seconds",
            requestID: "req_429"
        )) {
            _ = try await client.sendMessage("hello")
        }
    }
}

private func makeMockSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
}

private func bodyData(from request: URLRequest) throws -> Data {
    if let body = request.httpBody {
        return body
    }
    guard let stream = request.httpBodyStream else {
        throw URLError(.badURL)
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1_024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)
        if read < 0 {
            throw stream.streamError ?? URLError(.cannotParseResponse)
        }
        if read == 0 {
            break
        }
        data.append(buffer, count: read)
    }

    return data
}

private actor MockURLProtocolStore {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    static let shared = MockURLProtocolStore()
    private var handler: Handler?

    func setHandler(_ handler: @escaping Handler) {
        self.handler = handler
    }

    func run(request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let handler else {
            throw URLError(.badServerResponse)
        }
        return try handler(request)
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Task {
            do {
                let (response, data) = try await MockURLProtocolStore.shared.run(request: request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}
