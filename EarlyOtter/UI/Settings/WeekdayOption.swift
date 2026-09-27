import Foundation

struct WeekdayOption: Identifiable, Equatable, Sendable {
    let weekday: Int
    let shortLabel: String
    let fullLabel: String

    var id: Int { weekday }
}

enum EarlyOtterUIConfiguration {
    static let sundayFirstWeekdays: [WeekdayOption] = [
        WeekdayOption(weekday: 1, shortLabel: "SUN", fullLabel: "Sunday"),
        WeekdayOption(weekday: 2, shortLabel: "MON", fullLabel: "Monday"),
        WeekdayOption(weekday: 3, shortLabel: "TUE", fullLabel: "Tuesday"),
        WeekdayOption(weekday: 4, shortLabel: "WED", fullLabel: "Wednesday"),
        WeekdayOption(weekday: 5, shortLabel: "THU", fullLabel: "Thursday"),
        WeekdayOption(weekday: 6, shortLabel: "FRI", fullLabel: "Friday"),
        WeekdayOption(weekday: 7, shortLabel: "SAT", fullLabel: "Saturday")
    ]
}
