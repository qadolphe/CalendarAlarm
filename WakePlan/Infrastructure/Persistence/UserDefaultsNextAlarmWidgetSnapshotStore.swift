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
        defaults: UserDefaults? = nil
    ) {
        self.defaults = defaults ?? Self.makeDefaults()
    }

    private static func makeDefaults() -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: AppConfiguration.widgetAppGroupIdentifier) else {
            assertionFailure("Unable to create shared widget defaults for app group \(AppConfiguration.widgetAppGroupIdentifier)")
            return .standard
        }

        return defaults
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
        defaults.synchronize()
    }

    func clear() throws {
        defaults.removeObject(forKey: key)
        defaults.synchronize()
    }
}