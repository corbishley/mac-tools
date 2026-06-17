import Foundation
import Security

enum KeychainHelper {
    static func readPassword(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func claudeAccessToken() -> String? {
        guard let json = readPassword(service: "Claude Code-credentials"),
              let data = json.data(using: .utf8),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = obj["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String
        else { return nil }
        return token
    }

    static func neonApiKey() -> String? {
        readPassword(service: "neon-api-key")
    }

    static func cloudflareApiToken() -> String? {
        readPassword(service: "cloudflare-api-token")
    }
}
