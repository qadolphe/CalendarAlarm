import Foundation

struct Minutes: Codable, Equatable, Hashable, Comparable, Sendable {
    let rawValue: Int

    init(_ rawValue: Int) {
        self.rawValue = max(0, rawValue)
    }

    static func < (lhs: Minutes, rhs: Minutes) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
