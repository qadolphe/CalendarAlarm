import Foundation
import XCTest
@testable import EarlyOtter

final class WebsiteTelemetryRecorderTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var queueURL: URL!

    override func setUp() {
        super.setUp()
        suiteName = "WebsiteTelemetryRecorderTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        queueURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("queue.json")
    }

    override func tearDown() {
        TelemetryStubURLProtocol.handler = nil
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: queueURL.deletingLastPathComponent())
        super.tearDown()
    }

    // MARK: Wire format

    func testWireEventMatchesServerContract() throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000) // 2026-09-21T14:13:20Z
        let event = TelemetryWireEvent(
            .permissionResolved(.calendar, granted: false),
            at: date,
            timeZone: TimeZone(identifier: "Pacific/Kiritimati")! // UTC+14, already the next day
        )

        XCTAssertEqual(event.name, "permission_resolved")
        XCTAssertEqual(event.props, ["kind": .string("calendar"), "granted": .bool(false)])
        XCTAssertEqual(event.day, "2026-09-22")
        XCTAssertEqual(event.occurredAt, "2026-09-21T14:13:20Z")

        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any]
        )
        let props = try XCTUnwrap(json["props"] as? [String: Any])
        XCTAssertEqual(props["granted"] as? Bool, false)
    }

    func testAlarmsSyncedClampsCountToServerRange() {
        let event = TelemetryWireEvent(.alarmsSynced(activeAlarmCount: 500, reason: .background), at: Date())

        XCTAssertEqual(event.name, "alarms_synced")
        XCTAssertEqual(event.props, ["activeAlarmCount": .int(100), "reason": .string("background")])
    }

    func testPermissionEventsSkipUndeterminedStates() {
        let events = TelemetryEvent.permissionEvents(
            for: PermissionSnapshot(calendar: .authorized, alarm: .notDetermined, notification: .denied)
        )

        XCTAssertEqual(events, [
            .permissionResolved(.calendar, granted: true),
            .permissionResolved(.notification, granted: false),
        ])
    }

    func testDayOverrideKind() {
        XCTAssertEqual(TelemetryDayOverrideKind(nil), .cleared)
        XCTAssertEqual(TelemetryDayOverrideKind(DayAlarmOverride(customWakeTime: nil, isSkipped: true)), .skip)
        XCTAssertEqual(
            TelemetryDayOverrideKind(DayAlarmOverride(customWakeTime: ClockTime(hour: 7, minute: 0))),
            .custom
        )
    }

    // MARK: Delivery

    func testFlushSendsBatchAndClearsQueue() async throws {
        var bodies: [Data] = []
        TelemetryStubURLProtocol.handler = { request in
            bodies.append(try request.bodyData())
            return (Self.response(for: request, status: 202), Data())
        }
        let recorder = makeRecorder()

        await recorder.enqueue(TelemetryWireEvent(.appOpened, at: Date()))
        await recorder.enqueue(TelemetryWireEvent(.onboardingCompleted, at: Date()))
        await recorder.flush()

        XCTAssertEqual(bodies.count, 1)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: bodies[0]) as? [String: Any])
        XCTAssertEqual(json["schemaVersion"] as? Int, 1)
        XCTAssertEqual(json["channel"] as? String, "debug")
        XCTAssertEqual(json["appVersion"] as? String, "1.2.3")
        XCTAssertNotNil(UUID(uuidString: try XCTUnwrap(json["installId"] as? String)))
        let names = try XCTUnwrap(json["events"] as? [[String: Any]]).compactMap { $0["name"] as? String }
        XCTAssertEqual(names, ["app_opened", "onboarding_completed"])
        let remaining = await recorder.queuedEvents
        XCTAssertTrue(remaining.isEmpty)
    }

    func testInstallIDIsStableAcrossBatches() async throws {
        var installIDs: [String] = []
        TelemetryStubURLProtocol.handler = { request in
            let json = try JSONSerialization.jsonObject(with: request.bodyData()) as? [String: Any]
            installIDs.append(json?["installId"] as? String ?? "")
            return (Self.response(for: request, status: 202), Data())
        }
        let recorder = makeRecorder()

        await recorder.enqueue(TelemetryWireEvent(.appOpened, at: Date()))
        await recorder.flush()
        await recorder.enqueue(TelemetryWireEvent(.appOpened, at: Date()))
        await recorder.flush()

        XCTAssertEqual(installIDs.count, 2)
        XCTAssertEqual(installIDs[0], installIDs[1])
    }

    func testFlushSplitsIntoBatchesOfFifty() async {
        var batchSizes: [Int] = []
        TelemetryStubURLProtocol.handler = { request in
            let json = try JSONSerialization.jsonObject(with: request.bodyData()) as? [String: Any]
            batchSizes.append((json?["events"] as? [Any])?.count ?? 0)
            return (Self.response(for: request, status: 202), Data())
        }
        let recorder = makeRecorder()

        for _ in 0..<19 {
            await recorder.enqueue(TelemetryWireEvent(.appOpened, at: Date()))
        }
        XCTAssertTrue(batchSizes.isEmpty, "Below the flush threshold nothing is sent")

        TelemetryStubURLProtocol.handler = { request in (Self.response(for: request, status: 503), Data()) }
        for _ in 0..<101 {
            await recorder.enqueue(TelemetryWireEvent(.appOpened, at: Date()))
        }
        TelemetryStubURLProtocol.handler = { request in
            let json = try JSONSerialization.jsonObject(with: request.bodyData()) as? [String: Any]
            batchSizes.append((json?["events"] as? [Any])?.count ?? 0)
            return (Self.response(for: request, status: 202), Data())
        }
        await recorder.flush()

        XCTAssertEqual(batchSizes, [50, 50, 20])
    }

    func testServerErrorKeepsEventsForRetry() async {
        TelemetryStubURLProtocol.handler = { request in (Self.response(for: request, status: 500), Data()) }
        let recorder = makeRecorder()

        await recorder.enqueue(TelemetryWireEvent(.appOpened, at: Date()))
        await recorder.flush()

        let remaining = await recorder.queuedEvents
        XCTAssertEqual(remaining.count, 1)
    }

    func testNetworkErrorKeepsEventsForRetry() async {
        TelemetryStubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let recorder = makeRecorder()

        await recorder.enqueue(TelemetryWireEvent(.appOpened, at: Date()))
        await recorder.flush()

        let remaining = await recorder.queuedEvents
        XCTAssertEqual(remaining.count, 1)
    }

    func testRejectedBatchIsDropped() async {
        TelemetryStubURLProtocol.handler = { request in (Self.response(for: request, status: 400), Data()) }
        let recorder = makeRecorder()

        await recorder.enqueue(TelemetryWireEvent(.appOpened, at: Date()))
        await recorder.flush()

        let remaining = await recorder.queuedEvents
        XCTAssertTrue(remaining.isEmpty)
    }

    func testQueueIsCappedAndSurvivesRestart() async {
        TelemetryStubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let recorder = makeRecorder()

        for _ in 0..<(WebsiteTelemetryRecorder.maxQueuedEvents + 5) {
            await recorder.enqueue(TelemetryWireEvent(.appOpened, at: Date()))
        }

        let restarted = makeRecorder()
        let persisted = await restarted.queuedEvents
        XCTAssertEqual(persisted.count, WebsiteTelemetryRecorder.maxQueuedEvents)
    }

    func testOptingOutClearsQueueAndInstallIDAndStopsRecording() async {
        var requestCount = 0
        TelemetryStubURLProtocol.handler = { request in
            requestCount += 1
            return (Self.response(for: request, status: 500), Data())
        }
        let recorder = makeRecorder()
        await recorder.enqueue(TelemetryWireEvent(.appOpened, at: Date()))
        await recorder.flush()
        XCTAssertNotNil(defaults.string(forKey: AppConfiguration.telemetryInstallIDStorageKey))

        await recorder.setEnabled(false)
        await recorder.enqueue(TelemetryWireEvent(.appOpened, at: Date()))
        await recorder.flush()

        XCTAssertFalse(recorder.isEnabled)
        let remaining = await recorder.queuedEvents
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertNil(defaults.string(forKey: AppConfiguration.telemetryInstallIDStorageKey))
        XCTAssertFalse(FileManager.default.fileExists(atPath: queueURL.path))
        XCTAssertEqual(requestCount, 1)
    }

    // MARK: Helpers

    private func makeRecorder() -> WebsiteTelemetryRecorder {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TelemetryStubURLProtocol.self]

        return WebsiteTelemetryRecorder(
            endpoint: URL(string: "https://earlyotter.com/api/telemetry")!,
            session: URLSession(configuration: configuration),
            metadata: ClientMetadata(appVersion: "1.2.3", buildNumber: "45", iosVersion: "26.0.0"),
            defaults: defaults,
            queueURL: queueURL,
            resolveChannel: { "debug" }
        )
    }

    private static func response(for request: URLRequest, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
}

private final class TelemetryStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLRequest {
    func bodyData() throws -> Data {
        if let httpBody { return httpBody }
        guard let httpBodyStream else { return Data() }

        httpBodyStream.open()
        defer { httpBodyStream.close() }

        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1_024)
        defer { buffer.deallocate() }

        while httpBodyStream.hasBytesAvailable {
            let count = httpBodyStream.read(buffer, maxLength: 1_024)
            if count < 0 { throw httpBodyStream.streamError ?? URLError(.cannotDecodeContentData) }
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }

        return data
    }
}
