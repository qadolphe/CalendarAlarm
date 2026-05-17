import Foundation

protocol ScheduledAlarmStoring {
    func load() throws -> [ScheduledAlarmRecord]
    func save(_ records: [ScheduledAlarmRecord]) throws
    func clear() throws
}
