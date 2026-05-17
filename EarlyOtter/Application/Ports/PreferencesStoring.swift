import Foundation

protocol PreferencesStoring {
    func load() throws -> AlarmPreferences
    func save(_ preferences: AlarmPreferences) throws
}
