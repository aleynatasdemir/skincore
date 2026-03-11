import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()
    
    private let accessTokenKey = "com.skincore.accessToken"
    private let refreshTokenKey = "com.skincore.refreshToken"
    
    private init() {}
    
    // MARK: - Access Token
    
    func saveAccessToken(_ token: String) {
        save(key: accessTokenKey, value: token)
    }
    
    func getAccessToken() -> String? {
        return load(key: accessTokenKey)
    }
    
    func deleteAccessToken() {
        delete(key: accessTokenKey)
    }
    
    // MARK: - Refresh Token
    
    func saveRefreshToken(_ token: String) {
        save(key: refreshTokenKey, value: token)
    }
    
    func getRefreshToken() -> String? {
        return load(key: refreshTokenKey)
    }
    
    func deleteRefreshToken() {
        delete(key: refreshTokenKey)
    }
    
    // MARK: - Clear All
    
    func clearAll() {
        deleteAccessToken()
        deleteRefreshToken()
    }
    
    // MARK: - Save Tokens from Auth Response
    
    func saveTokens(from response: AuthResponse) {
        saveAccessToken(response.accessToken)
        saveRefreshToken(response.refreshToken)
    }
    
    // MARK: - Keychain Operations
    
    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        // Delete existing item first
        delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
