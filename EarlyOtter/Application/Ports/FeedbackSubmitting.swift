protocol FeedbackSubmitting: Sendable {
    func submit(_ feedback: AppFeedback) async throws
}

enum FeedbackSubmissionError: Error {
    case unavailable
}
