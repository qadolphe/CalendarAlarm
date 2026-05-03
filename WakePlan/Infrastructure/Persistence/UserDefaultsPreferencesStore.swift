import Foundation

final class UserDefaultsPreferencesStore: PreferencesStoring {
    private let key = "wakeplan.preferences"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> AlarmPreferences {
        guard let data = defaults.data(forKey: key) else {
            return .default
        }

        return try decoder.decode(AlarmPreferences.self, from: data)
    }

    func save(_ preferences: AlarmPreferences) throws {
        let data = try encoder.encode(preferences)
        defaults.set(data, forKey: key)
    }
}

final class UserDefaultsAccountStore: AccountStoring {
    private let key = "wakeplan.connectedAccounts"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> [ConnectedCalendarAccount] {
        guard let data = defaults.data(forKey: key) else {
            return []
        }

        return try decoder.decode([ConnectedCalendarAccount].self, from: data)
    }

    func save(_ accounts: [ConnectedCalendarAccount]) throws {
        let data = try encoder.encode(accounts)
        defaults.set(data, forKey: key)
    }
}
