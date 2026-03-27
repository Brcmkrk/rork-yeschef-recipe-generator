import Foundation
import Security

enum KeychainHelper {
    private static let deviceIdKey = "com.yeschef.device_uuid"

    static var persistentDeviceId: String {
        if let existing = read(key: deviceIdKey, sync: true) {
            return existing
        }
        if let legacy = read(key: deviceIdKey, sync: false) {
            save(key: deviceIdKey, value: legacy, sync: true)
            deleteLegacy(key: deviceIdKey)
            return legacy
        }
        let newId = UUID().uuidString
        save(key: deviceIdKey, value: newId, sync: true)
        return newId
    }

    private static func save(key: String, value: String, sync: Bool) {
        guard let data = value.data(using: .utf8) else { return }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        if sync {
            query[kSecAttrSynchronizable as String] = kCFBooleanTrue
        }
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func read(key: String, sync: Bool) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if sync {
            query[kSecAttrSynchronizable as String] = kCFBooleanTrue
        }
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteLegacy(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
