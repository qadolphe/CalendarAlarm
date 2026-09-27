protocol TelemetryRecording: Sendable {
    /// Whether the user allows anonymous usage data to be sent.
    var isEnabled: Bool { get }
    /// Turning telemetry off also discards queued events and the install ID.
    func setEnabled(_ isEnabled: Bool) async
    /// Marks this phone as the developer's, so its events are tagged `internal`
    /// and kept out of the real numbers. Survives reinstalls.
    var isInternalDevice: Bool { get }
    func setInternalDevice(_ isInternal: Bool) async
    /// Fire-and-forget: queues the event and returns immediately.
    func record(_ event: TelemetryEvent)
    func flush() async
}

struct NoOpTelemetryRecorder: TelemetryRecording {
    var isEnabled: Bool { false }
    func setEnabled(_ isEnabled: Bool) async {}
    var isInternalDevice: Bool { false }
    func setInternalDevice(_ isInternal: Bool) async {}
    func record(_ event: TelemetryEvent) {}
    func flush() async {}
}
