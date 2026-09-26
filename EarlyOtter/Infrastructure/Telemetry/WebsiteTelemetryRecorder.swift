import Foundation
import StoreKit

/// Sends queued `TelemetryEvent`s in batches to earlyotter.com/api/telemetry.
/// Events are saved to disk first, so events recorded offline or during a background
/// refresh are sent on a later flush.
actor WebsiteTelemetryRecorder: TelemetryRecording {
    static let maxQueuedEvents = 500
    static let maxBatchSize = 50
    static let flushThreshold = 20

    private let endpoint: URL
    private let session: URLSession
    private let metadata: ClientMetadata
    private nonisolated let defaults: UserDefaults
    private let queueURL: URL
    private let resolveChannel: @Sendable () async -> String
    private let encoder = JSONEncoder()
    private var queue: [TelemetryWireEvent]?
    private var channel: String?
    private let rejectedStatuses = Set(400..<500).subtracting([408, 429])
    private var isFlushing = false

    init(
        endpoint: URL,
        session: URLSession = .shared,
        metadata: ClientMetadata = .live(),
        defaults: UserDefaults = .standard,
        queueURL: URL = WebsiteTelemetryRecorder.defaultQueueURL,
        resolveChannel: @escaping @Sendable () async -> String = WebsiteTelemetryRecorder.currentChannel
    ) {
        self.endpoint = endpoint
        self.session = session
        self.metadata = metadata
        self.defaults = defaults
        self.queueURL = queueURL
        self.resolveChannel = resolveChannel
    }

    nonisolated var isEnabled: Bool {
        defaults.object(forKey: AppConfiguration.telemetryConsentStorageKey) as? Bool ?? true
    }

    func setEnabled(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: AppConfiguration.telemetryConsentStorageKey)
        guard !isEnabled else { return }

        queue = []
        try? FileManager.default.removeItem(at: queueURL)
        defaults.removeObject(forKey: AppConfiguration.telemetryInstallIDStorageKey)
    }

    nonisolated func record(_ event: TelemetryEvent) {
        guard isEnabled else { return }
        let wireEvent = TelemetryWireEvent(event, at: Date())
        Task { await self.enqueue(wireEvent) }
    }

    func enqueue(_ event: TelemetryWireEvent) async {
        guard isEnabled else { return }

        var events = loadQueue()
        events.append(event)
        if events.count > Self.maxQueuedEvents {
            events.removeFirst(events.count - Self.maxQueuedEvents)
        }
        saveQueue(events)

        if events.count >= Self.flushThreshold {
            await flush()
        }
    }

    func flush() async {
        guard isEnabled, !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        while isEnabled {
            let batch = Array(loadQueue().prefix(Self.maxBatchSize))
            guard !batch.isEmpty, await send(batch) else { return }

            // Events queued while the batch was in flight stay in the queue.
            var remaining = loadQueue()
            remaining.removeFirst(min(batch.count, remaining.count))
            saveQueue(remaining)
        }
    }

    var queuedEvents: [TelemetryWireEvent] {
        loadQueue()
    }

    /// Returns true when the batch is finished with: delivered, or rejected with a 4xx
    /// the server will never accept. Returns false to keep it for a later retry.
    private func send(_ events: [TelemetryWireEvent]) async -> Bool {
        let channel = await resolvedChannel()
        let payload = TelemetryBatchPayload(
            installId: installID(),
            appVersion: metadata.appVersion,
            buildNumber: metadata.buildNumber,
            iosVersion: metadata.iosVersion,
            channel: channel,
            events: events
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try encoder.encode(payload)
            let (_, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return (200..<300).contains(status) || rejectedStatuses.contains(status)
        } catch {
            return false
        }
    }

    private func resolvedChannel() async -> String {
        if let channel { return channel }
        let resolved = await resolveChannel()
        channel = resolved
        return resolved
    }

    private func installID() -> String {
        if let existing = defaults.string(forKey: AppConfiguration.telemetryInstallIDStorageKey) {
            return existing
        }
        let created = UUID().uuidString.lowercased()
        defaults.set(created, forKey: AppConfiguration.telemetryInstallIDStorageKey)
        return created
    }

    private func loadQueue() -> [TelemetryWireEvent] {
        if let queue { return queue }
        let loaded = (try? Data(contentsOf: queueURL))
            .flatMap { try? JSONDecoder().decode([TelemetryWireEvent].self, from: $0) } ?? []
        queue = loaded
        return loaded
    }

    private func saveQueue(_ events: [TelemetryWireEvent]) {
        queue = events
        guard let data = try? encoder.encode(events) else { return }
        try? FileManager.default.createDirectory(
            at: queueURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: queueURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static var defaultQueueURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Telemetry", isDirectory: true)
            .appendingPathComponent("queue.json")
    }

    @Sendable
    static func currentChannel() async -> String {
#if DEBUG
        return "debug"
#else
        guard let transaction = try? await AppTransaction.shared else { return "appstore" }
        switch transaction.unsafePayloadValue.environment {
        case .production: return "appstore"
        case .sandbox: return "testflight"
        default: return "debug"
        }
#endif
    }
}
