import Foundation
import Security

struct SavedConnection: Equatable {
    let serverURL: URL
    let token: String
    let playerName: String
}

struct CredentialStore {
    private let defaults = UserDefaults.standard
    private let serverURLKey = "tater.serverURL"
    private let playerNameKey = "tater.playerName"
    private let keychainService = "com.tatertotterson.TaterTubePlayerTV"
    private let tokenAccount = "paired-server-token"

    func load() -> SavedConnection? {
        guard
            let server = defaults.string(forKey: serverURLKey),
            let serverURL = URL(string: server),
            let token = loadToken(),
            !token.isEmpty
        else {
            return nil
        }

        return SavedConnection(
            serverURL: serverURL,
            token: token,
            playerName: defaults.string(forKey: playerNameKey) ?? "Tater Tube Player"
        )
    }

    func save(_ connection: SavedConnection) throws {
        try saveToken(connection.token)
        defaults.set(connection.serverURL.absoluteString, forKey: serverURLKey)
        defaults.set(connection.playerName, forKey: playerNameKey)
    }

    func clear() {
        defaults.removeObject(forKey: serverURLKey)
        defaults.removeObject(forKey: playerNameKey)
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenAccount
        ]
    }

    private func loadToken() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func saveToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw CredentialError.invalidToken
        }

        SecItemDelete(baseQuery as CFDictionary)
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialError.keychain(status)
        }
    }
}

enum CredentialError: LocalizedError {
    case invalidToken
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "The server returned an invalid pairing token."
        case .keychain(let status):
            return "The pairing token could not be saved (Keychain error \(status))."
        }
    }
}
