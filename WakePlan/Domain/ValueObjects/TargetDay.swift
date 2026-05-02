import Foundation

struct TargetDay: Codable, Equatable, Hashable, Sendable {
    let date: Date

    init(date: Date, calendar: Calendar = .current) {
        self.date = calendar.startOfDay(for: date)
    }

    static func tomorrow(from now: Date = Date(), calendar: Calendar = .current) -> TargetDay {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return TargetDay(date: tomorrow, calendar: calendar)
    }

    func interval(calendar: Calendar) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }
}
