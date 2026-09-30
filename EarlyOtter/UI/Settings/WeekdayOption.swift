import Foundation

struct WeekdayOption: Identifiable, Equatable, Sendable {
    let weekday: Int
    let shortLabel: String
    let fullLabel: String
    /// One letter, as the Clock app's day picker shows it.
    let initial: String

    var id: Int { weekday }
}

enum EarlyOtterUIConfiguration {
    /// Day names come from the current locale, so they follow the app's language.
    static var sundayFirstWeekdays: [WeekdayOption] {
        let calendar = Calendar.current
        return (1...7).map { weekday in
            WeekdayOption(
                weekday: weekday,
                shortLabel: calendar.shortWeekdaySymbols[weekday - 1].uppercased(),
                fullLabel: calendar.standaloneWeekdaySymbols[weekday - 1],
                initial: calendar.veryShortStandaloneWeekdaySymbols[weekday - 1]
            )
        }
    }
}
