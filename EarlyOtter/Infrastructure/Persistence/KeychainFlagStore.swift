import Foundation
import Security

protocol FlagStoring: Sendable {
    func isSet() -> Bool
    func set(_ isSet: Bool)
}

/// A boolean kept in the Keychain. Unlike UserDefaults it survives deleting and
/// reinstalling the app, and `ThisDeviceOnly` keeps it out of backups and other devices.
struct KeychainFlagStore: FlagStoring {
    let account: String
    var service = "com.quentinadolphe.wakeplan.flags"

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func isSet() -> Bool {
        SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    func set(_ isSet: Bool) {
        SecItemDelete(query as CFDictionary)
        guard isSet else { return }

        var item = query
        item[kSecValueData as String] = Data([1])
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
