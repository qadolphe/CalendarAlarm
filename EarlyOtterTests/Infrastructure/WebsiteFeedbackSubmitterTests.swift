import Foundation
import XCTest
@testable import EarlyOtter

final class WebsiteFeedbackSubmitterTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testSubmitSendsExpectedRequest() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = try request.bodyData()
            return (
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 201,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data()
            )
        }
        let submitter = makeSubmitter()

        try await submitter.submit(
            AppFeedback(category: .suggestion, message: "Add a shorter setup flow.")
        )

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.url, URL(string: "https://earlyotter.com/api/feedback"))
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(capturedBody)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        XCTAssertEqual(json["schemaVersion"] as? Int, 1)
        XCTAssertEqual(json["category"] as? String, "suggestion")
        XCTAssertEqual(json["message"] as? String, "Add a shorter setup flow.")
        XCTAssertEqual(json["appVersion"] as? String, "1.2.3")
        XCTAssertEqual(json["buildNumber"] as? String, "45")
        XCTAssertEqual(json["iosVersion"] as? String, "26.0.0")
    }

    func testSubmitRejectsNonSuccessResponse() async throws {
        StubURLProtocol.handler = { request in
            (
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data()
            )
        }

        do {
            try await makeSubmitter().submit(
                AppFeedback(category: .issue, message: "An issue occurred.")
            )
            XCTFail("Expected request to fail")
        } catch {
            XCTAssertEqual(
                error as? WebsiteFeedbackError,
                .requestFailed(statusCode: 500)
            )
        }
    }

    func testSubmitForwardsTransportError() async throws {
        StubURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            try await makeSubmitter().submit(
                AppFeedback(category: .experience, message: "Works well.")
            )
            XCTFail("Expected request to fail")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
    }

    private func makeSubmitter() -> WebsiteFeedbackSubmitter {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        return WebsiteFeedbackSubmitter(
            endpoint: URL(string: "https://earlyotter.com/api/feedback")!,
            session: URLSession(configuration: configuration),
            metadata: FeedbackClientMetadata(
                appVersion: "1.2.3",
                buildNumber: "45",
                iosVersion: "26.0.0"
            )
        )
    }
}

private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLRequest {
    func bodyData() throws -> Data {
        if let httpBody {
            return httpBody
        }

        guard let httpBodyStream else {
            return Data()
        }

        httpBodyStream.open()
        defer { httpBodyStream.close() }

        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1_024)
        defer { buffer.deallocate() }

        while httpBodyStream.hasBytesAvailable {
            let count = httpBodyStream.read(buffer, maxLength: 1_024)
            if count < 0 {
                throw httpBodyStream.streamError ?? URLError(.cannotDecodeContentData)
            }
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }

        return data
    }
}
