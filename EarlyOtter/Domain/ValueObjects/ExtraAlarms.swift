import Foundation

/// Alarms a rule rings before its calculated wake-up, evenly spaced, so the
/// calculated time is always the last to ring.
struct ExtraAlarms: Codable, Equatable, Sendable {
    static let counts = 0...3
    static let spacings = stride(from: 5, through: 30, by: 5).map(Minutes.init)
    static let none = ExtraAlarms(count: 0, spacing: Minutes(5))

    let count: Int
    let spacing: Minutes

    init(count: Int, spacing: Minutes) {
        self.count = count.clamped(to: Self.counts)
        self.spacing = Minutes(spacing.rawValue.clamped(to: 5...30))
    }

    /// How early each extra alarm rings, earliest first, e.g. [10, 5].
    var offsets: [Minutes] {
        stride(from: count, to: 0, by: -1).map { Minutes($0 * spacing.rawValue) }
    }

    // Decoded through the initializer so stored values are clamped too.
    private enum CodingKeys: String, CodingKey { case count, spacing }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            count: try container.decode(Int.self, forKey: .count),
            spacing: try container.decode(Minutes.self, forKey: .spacing)
        )
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
