import XCTest
@testable import EarlyOtter

final class AppFeedbackTests: XCTestCase {
    func testFeedbackTrimsMessage() throws {
        let feedback = try AppFeedback(
            category: .suggestion,
            message: "  Make setup shorter. \n"
        )

        XCTAssertEqual(feedback.message, "Make setup shorter.")
    }

    func testFeedbackRejectsEmptyMessage() {
        XCTAssertThrowsError(
            try AppFeedback(category: .experience, message: " \n ")
        ) { error in
            XCTAssertEqual(error as? AppFeedbackError, .emptyMessage)
        }
    }

    func testFeedbackRejectsMessageOverLimit() {
        XCTAssertThrowsError(
            try AppFeedback(
                category: .issue,
                message: String(repeating: "a", count: AppFeedback.maximumMessageLength + 1)
            )
        ) { error in
            XCTAssertEqual(error as? AppFeedbackError, .messageTooLong)
        }
    }
}
