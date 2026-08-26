struct AppReviewPromptPolicy {
    static let requiredQualifiedOpenCount = 3

    struct Evaluation: Equatable {
        let qualifiedOpenCount: Int
        let shouldRequestReview: Bool
    }

    static func evaluate(
        qualifiedOpenCount: Int,
        lastRequestedVersion: String,
        currentVersion: String,
        isQualifiedOpen: Bool
    ) -> Evaluation {
        guard isQualifiedOpen, lastRequestedVersion != currentVersion else {
            return Evaluation(
                qualifiedOpenCount: qualifiedOpenCount,
                shouldRequestReview: false
            )
        }

        let nextCount = min(
            qualifiedOpenCount + 1,
            requiredQualifiedOpenCount
        )

        return Evaluation(
            qualifiedOpenCount: nextCount,
            shouldRequestReview: nextCount == requiredQualifiedOpenCount
        )
    }
}
