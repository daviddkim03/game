import Foundation
import Security
import SystemCore

/// Keeps the sign-in in the Keychain. Readable after the first unlock so
/// background refreshes and Apple Pay logging work while the phone is locked.
struct KeychainSessionStore: SessionStore {
    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.daviddkim03.system.session",
            kSecAttrAccount as String: "firebase",
        ]
    }

    func read() -> StoredSession? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess,
            let data = item as? Data
        else { return nil }
        return try? JSONDecoder().decode(StoredSession.self, from: data)
    }

    func write(_ session: StoredSession?) {
        SecItemDelete(query as CFDictionary)
        guard let session, let data = try? JSONEncoder().encode(session) else { return }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
