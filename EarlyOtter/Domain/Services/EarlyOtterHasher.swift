import CryptoKit
import Foundation

struct WakePlanHasher {
    func makeID(kind: String, components: [String]) -> WakePlanID {
        let payload = ([kind] + components).joined(separator: "|")
        let digest = SHA256.hash(data: Data(payload.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return WakePlanID(rawValue: "\(kind)-\(hex)")
    }
}
