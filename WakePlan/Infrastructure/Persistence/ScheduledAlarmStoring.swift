import Foundation

protocol ScheduledAlarmStoring {
    func load() throws -> ScheduledAlarmRecord?
    func save(_ record: ScheduledAlarmRecord) throws
    func clear() throws
}
