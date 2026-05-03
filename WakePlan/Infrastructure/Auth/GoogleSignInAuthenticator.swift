import Foundation
import GoogleSignIn
import UIKit

enum GoogleAuthError: LocalizedError {
    case missingPresentingViewController

    var errorDescription: String? {
        switch self {
        case .missingPresentingViewController:
            return "Google Sign-In could not find a screen to present from."
        }
    }
}

@MainActor
final class GoogleSignInAuthenticator: GoogleAccountAuthenticating {
    func signIn() async throws -> GoogleAccountAuthResult {
        guard let presentingViewController = UIApplication.shared.topViewController() else {
            throw GoogleAuthError.missingPresentingViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController,
            hint: nil,
            additionalScopes: [
                "https://www.googleapis.com/auth/calendar.readonly"
            ]
        )

        let user = result.user
        let profile = user.profile
        let email = profile?.email ?? "Unknown Google Account"
        let name = profile?.name ?? email

        return GoogleAccountAuthResult(
            accountID: CalendarAccountID(rawValue: user.userID ?? email),
            displayName: name,
            email: email
        )
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
