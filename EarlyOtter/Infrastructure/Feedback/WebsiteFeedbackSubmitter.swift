import Foundation

struct FeedbackClientMetadata: Equatable, Sendable {
    let appVersion: String
    let buildNumber: String
    let iosVersion: String

    static func live(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> FeedbackClientMetadata {
        let version = processInfo.operatingSystemVersion
        return FeedbackClientMetadata(
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown",
            iosVersion: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        )
    }
}

struct WebsiteFeedbackSubmitter: FeedbackSubmitting {
    private let endpoint: URL
    private let session: URLSession
    private let metadata: FeedbackClientMetadata

    init(
        endpoint: URL,
        session: URLSession = .shared,
        metadata: FeedbackClientMetadata = .live()
    ) {
        self.endpoint = endpoint
        self.session = session
        self.metadata = metadata
    }

    func submit(_ feedback: AppFeedback) async throws {
        let payload = Payload(
            schemaVersion: 1,
            category: feedback.category.rawValue,
            message: feedback.message,
            appVersion: metadata.appVersion,
            buildNumber: metadata.buildNumber,
            iosVersion: metadata.iosVersion
        )
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw WebsiteFeedbackError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw WebsiteFeedbackError.requestFailed(statusCode: response.statusCode)
        }
    }
}

enum WebsiteFeedbackError: Error, Equatable {
    case invalidResponse
    case requestFailed(statusCode: Int)
}

private struct Payload: Encodable {
    let schemaVersion: Int
    let category: String
    let message: String
    let appVersion: String
    let buildNumber: String
    let iosVersion: String
}
