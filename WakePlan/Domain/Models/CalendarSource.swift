import Foundation

struct CalendarSource: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let title: String
    let isSelected: Bool
}
