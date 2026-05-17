import Foundation

struct CalendarSource: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let title: String
    let isSelected: Bool
    let accountID: CalendarAccountID?
    let provider: CalendarProvider

    init(
        id: String,
        title: String,
        isSelected: Bool,
        accountID: CalendarAccountID? = nil,
        provider: CalendarProvider = .apple
    ) {
        self.id = id
        self.title = title
        self.isSelected = isSelected
        self.accountID = accountID
        self.provider = provider
    }
}
