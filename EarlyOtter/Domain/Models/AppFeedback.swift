import Foundation

enum FeedbackCategory: String, CaseIterable, Identifiable, Sendable {
    case experience
    case suggestion
    case issue

    var id: Self { self }
}

struct AppFeedback: Equatable, Sendable {
    static let maximumMessageLength = 2_000

    let category: FeedbackCategory
    let message: String

    init(category: FeedbackCategory, message: String) throws {
        let message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            throw AppFeedbackError.emptyMessage
        }
        guard message.count <= Self.maximumMessageLength else {
            throw AppFeedbackError.messageTooLong
        }

        self.category = category
        self.message = message
    }
}

enum AppFeedbackError: Error, Equatable {
    case emptyMessage
    case messageTooLong
}
