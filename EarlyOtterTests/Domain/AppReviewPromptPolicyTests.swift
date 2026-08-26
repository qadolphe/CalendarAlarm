import XCTest
@testable import EarlyOtter

final class AppReviewPromptPolicyTests: XCTestCase {
    func testUnqualifiedOpenIsNotCounted() {
        let evaluation = AppReviewPromptPolicy.evaluate(
            qualifiedOpenCount: 1,
            lastRequestedVersion: "",
            currentVersion: "1.0",
            isQualifiedOpen: false
        )

        XCTAssertEqual(evaluation.qualifiedOpenCount, 1)
        XCTAssertFalse(evaluation.shouldRequestReview)
    }

    func testThirdQualifiedOpenRequestsReview() {
        let evaluation = AppReviewPromptPolicy.evaluate(
            qualifiedOpenCount: 2,
            lastRequestedVersion: "",
            currentVersion: "1.0",
            isQualifiedOpen: true
        )

        XCTAssertEqual(evaluation.qualifiedOpenCount, 3)
        XCTAssertTrue(evaluation.shouldRequestReview)
    }

    func testSameVersionIsNotRequestedAgain() {
        let evaluation = AppReviewPromptPolicy.evaluate(
            qualifiedOpenCount: 2,
            lastRequestedVersion: "1.0",
            currentVersion: "1.0",
            isQualifiedOpen: true
        )

        XCTAssertEqual(evaluation.qualifiedOpenCount, 2)
        XCTAssertFalse(evaluation.shouldRequestReview)
    }
}
