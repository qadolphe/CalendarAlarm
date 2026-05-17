import Foundation
import GoogleSignIn
import UIKit

enum GoogleAuthError: LocalizedError {
    case missingPresentingViewController
    case missingAccountIdentifier

    var errorDescription: String? {
        switch self {
        case .missingPresentingViewController:
            return "Google Sign-In could not find a screen to present from."
        case .missingAccountIdentifier:
            return "Google Sign-In did not return an email or account identifier."
        }
    }
}

@MainActor
final class GoogleSignInAuthenticator: GoogleAccountAuthenticating {
    private static let calendarReadonlyScope = "https://www.googleapis.com/auth/calendar.readonly"

    func signIn() async throws -> GoogleAccountAuthResult {
        guard let presentingViewController = UIApplication.shared.topViewController() else {
            throw GoogleAuthError.missingPresentingViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController,
            hint: nil,
            additionalScopes: [
                Self.calendarReadonlyScope
            ]
        )

        let user = result.user
        let profile = user.profile
        let email = profile?.email ?? "Unknown Google Account"
        let name = profile?.name ?? email
        let matchingAccountIDs = GoogleAccountIdentity.matchingIDs(for: user)

        guard let accountID = GoogleAccountIdentity.preferredID(for: user) else {
            throw GoogleAuthError.missingAccountIdentifier
        }

        return GoogleAccountAuthResult(
            accountID: accountID,
            matchingAccountIDs: matchingAccountIDs,
            displayName: name,
            email: email
        )
    }
}

enum GoogleAccountIdentity {
    static func preferredID(for user: GIDGoogleUser) -> CalendarAccountID? {
        if let email = normalizedEmail(user.profile?.email) {
            return CalendarAccountID(rawValue: email)
        }

        if let userID = normalizedValue(user.userID) {
            return CalendarAccountID(rawValue: userID)
        }

        return nil
    }

    static func matchingIDs(for user: GIDGoogleUser) -> Set<CalendarAccountID> {
        var ids: Set<CalendarAccountID> = []

        if let email = normalizedEmail(user.profile?.email) {
            ids.insert(CalendarAccountID(rawValue: email))
        }

        if let userID = normalizedValue(user.userID) {
            ids.insert(CalendarAccountID(rawValue: userID))
        }

        return ids
    }

    private static func normalizedEmail(_ value: String?) -> String? {
        normalizedValue(value)?.lowercased()
    }

    private static func normalizedValue(_ value: String?) -> String? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension UIApplication {
    func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let base = base ?? connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController

        if let navigationController = base as? UINavigationController {
            return topViewController(base: navigationController.visibleViewController)
        }

        if let tabBarController = base as? UITabBarController {
            return topViewController(base: tabBarController.selectedViewController)
        }

        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }

        return base
    }
}
