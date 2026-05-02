import Foundation

enum AppRuntime {
    #if DEBUG
    static let usesFakeCalendar = ProcessInfo.processInfo.arguments.contains("-useFakeCalendar")
    #else
    static let usesFakeCalendar = false
    #endif
}
