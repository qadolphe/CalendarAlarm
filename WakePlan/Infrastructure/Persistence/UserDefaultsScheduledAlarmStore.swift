import Foundation

final class UserDefaultsScheduledAlarmStore: ScheduledAlarmStoring {
    private let key = "wakeplan.scheduledAlarm"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> ScheduledAlarmRecord? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        return try decoder.decode(ScheduledAlarmRecord.self, from: data)
    }

    func save(_ record: ScheduledAlarmRecord) throws {
        let data = try encoder.encode(record)
        defaults.set(data, forKey: key)
    }

    func clear() throws {
        defaults.removeObject(forKey: key)
    }
}
