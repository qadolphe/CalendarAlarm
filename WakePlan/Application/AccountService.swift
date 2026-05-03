import Foundation

final class AccountService {
    private let accountStore: AccountStoring
    private let googleAuthenticator: GoogleAccountAuthenticating

    init(
        accountStore: AccountStoring,
        googleAuthenticator: GoogleAccountAuthenticating
    ) {
        self.accountStore = accountStore
        self.googleAuthenticator = googleAuthenticator
    }

    @MainActor
    func connectGoogleAccount() async throws -> [ConnectedCalendarAccount] {
        let result = try await googleAuthenticator.signIn()
        var accounts = try accountStore.load()

        let newAccount = ConnectedCalendarAccount(
            id: result.accountID,
            provider: .google,
            displayName: result.displayName,
            isEnabled: true
        )

        if let existingIndex = accounts.firstIndex(where: {
            $0.provider == .google && result.matchingAccountIDs.contains($0.id)
        }) {
            accounts[existingIndex] = newAccount
        } else {
            accounts.append(newAccount)
        }

        try accountStore.save(accounts)
        return accounts
    }
}
