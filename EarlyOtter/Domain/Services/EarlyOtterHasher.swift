import CryptoKit
import Foundation

struct EarlyOtterHasher {
    func makeID(kind: String, components: [String]) -> EarlyOtterID {
        let payload = ([kind] + components).joined(separator: "|")
        let digest = SHA256.hash(data: Data(payload.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return EarlyOtterID(rawValue: "\(kind)-\(hex)")
    }
}
