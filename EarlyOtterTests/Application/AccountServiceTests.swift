import XCTest
@testable import EarlyOtter

@MainActor
final class AccountServiceTests: XCTestCase {
    func testConnectGoogleAccountAppendsNewAccount() async throws {
        let store = InMemoryAccountStore(accounts: [])
        let authenticator = StubGoogleAuthenticator(
            result: GoogleAccountAuthResult(
                accountID: CalendarAccountID(rawValue: "google.user.1"),
                matchingAccountIDs: [CalendarAccountID(rawValue: "google.user.1")],
                displayName: "Quentin",
                email: "quentin@example.com"
            )
        )
        let service = AccountService(
            accountStore: store,
            googleAuthenticator: authenticator
        )

        let accounts = try await service.connectGoogleAccount()

        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts.first?.id.rawValue, "google.user.1")
        XCTAssertEqual(accounts.first?.provider, .google)
        XCTAssertEqual(accounts.first?.displayName, "Quentin")
        XCTAssertEqual(accounts.first?.isEnabled, true)
    }

    func testConnectGoogleAccountUpdatesExistingAccount() async throws {
        let store = InMemoryAccountStore(
            accounts: [
                ConnectedCalendarAccount(
                    id: CalendarAccountID(rawValue: "google.user.1"),
                    provider: .google,
                    displayName: "Old Name",
                    isEnabled: false
                )
            ]
        )
        let authenticator = StubGoogleAuthenticator(
            result: GoogleAccountAuthResult(
                accountID: CalendarAccountID(rawValue: "google.user.1"),
                matchingAccountIDs: [CalendarAccountID(rawValue: "google.user.1")],
                displayName: "New Name",
                email: "quentin@example.com"
            )
        )
        let service = AccountService(
            accountStore: store,
            googleAuthenticator: authenticator
        )

        let accounts = try await service.connectGoogleAccount()

        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts.first?.displayName, "New Name")
        XCTAssertEqual(accounts.first?.isEnabled, true)
    }
}

private final class InMemoryAccountStore: AccountStoring {
    private var accounts: [ConnectedCalendarAccount]

    init(accounts: [ConnectedCalendarAccount]) {
        self.accounts = accounts
    }

    func load() throws -> [ConnectedCalendarAccount] {
        accounts
    }

    func save(_ accounts: [ConnectedCalendarAccount]) throws {
        self.accounts = accounts
    }
}

@MainActor
private final class StubGoogleAuthenticator: GoogleAccountAuthenticating {
    private let result: GoogleAccountAuthResult

    init(result: GoogleAccountAuthResult) {
        self.result = result
    }

    func signIn() async throws -> GoogleAccountAuthResult {
        result
    }
}
