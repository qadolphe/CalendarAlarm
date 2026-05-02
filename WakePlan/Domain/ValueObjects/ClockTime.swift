import Foundation

struct ClockTime: Codable, Equatable, Hashable, Sendable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        precondition((0...23).contains(hour))
        precondition((0...59).contains(minute))

        self.hour = hour
        self.minute = minute
    }

    static let defaultLatestWakeTime = ClockTime(hour: 8, minute: 0)

    func date(on targetDay: TargetDay, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: targetDay.date)
        components.hour = hour
        components.minute = minute
        components.second = 0

        return calendar.date(from: components) ?? targetDay.date
    }
}
