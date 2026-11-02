import Foundation
import CryptoKit

enum ChecksumUtility {
    static func calculateHashes(for filePath: String) -> (sha256: String, md5: String)? {
        let url = URL(fileURLWithPath: filePath)
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            return nil
        }

        let sha256Digest = SHA256.hash(data: data)
        let sha256String = sha256Digest.map { String(format: "%02x", $0) }.joined()

        let md5Digest = Insecure.MD5.hash(data: data)
        let md5String = md5Digest.map { String(format: "%02x", $0) }.joined()

        return (sha256String, md5String)
    }
}
