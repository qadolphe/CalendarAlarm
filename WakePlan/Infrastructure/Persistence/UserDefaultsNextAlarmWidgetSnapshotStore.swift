import Foundation

protocol NextAlarmWidgetSnapshotStoring {
    func load() throws -> NextAlarmWidgetSnapshot?
    func save(_ snapshot: NextAlarmWidgetSnapshot) throws
    func clear() throws
}

final class UserDefaultsNextAlarmWidgetSnapshotStore: NextAlarmWidgetSnapshotStoring {
    private let key = "wakeplan.widget.nextAlarmSnapshot"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = UserDefaults(suiteName: AppConfiguration.widgetAppGroupIdentifier) ?? .standard
    ) {
        self.defaults = defaults
    }

    func load() throws -> NextAlarmWidgetSnapshot? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        return try decoder.decode(NextAlarmWidgetSnapshot.self, from: data)
    }

    func save(_ snapshot: NextAlarmWidgetSnapshot) throws {
        let data = try encoder.encode(snapshot)
        defaults.set(data, forKey: key)
    }

    func clear() throws {
        defaults.removeObject(forKey: key)
    }
}