//
//  BiometricCredentialStore.swift
//  The Ideal Week
//
//  Stores biometric login credentials in the iOS Keychain.
//

import Foundation
import Security

final class BiometricCredentialStore {
    static let shared = BiometricCredentialStore()

    private let service = Bundle.main.bundleIdentifier ?? "org.loveandchaos.theidealweek"
    private let emailAccount = "biometric_email"
    private let passwordAccount = "biometric_password"

    private let legacyEmailKey = "stored_email"
    private let legacyPasswordKey = "stored_password"

    private init() {}

    func store(email: String, password: String) {
        save(value: email, account: emailAccount)
        save(value: password, account: passwordAccount)
    }

    func fetch() -> (email: String, password: String)? {
        // One-time migration from old UserDefaults storage.
        migrateFromUserDefaultsIfNeeded()

        guard
            let email = read(account: emailAccount),
            let password = read(account: passwordAccount)
        else {
            return nil
        }
        return (email, password)
    }

    func clear() {
        delete(account: emailAccount)
        delete(account: passwordAccount)
    }

    private func migrateFromUserDefaultsIfNeeded() {
        guard
            read(account: emailAccount) == nil,
            read(account: passwordAccount) == nil
        else {
            return
        }

        guard
            let legacyEmail = UserDefaults.standard.string(forKey: legacyEmailKey),
            let legacyPassword = UserDefaults.standard.string(forKey: legacyPasswordKey)
        else {
            return
        }

        store(email: legacyEmail, password: legacyPassword)
        UserDefaults.standard.removeObject(forKey: legacyEmailKey)
        UserDefaults.standard.removeObject(forKey: legacyPasswordKey)
    }

    private func save(value: String, account: String) {
        let encodedValue = Data(value.utf8)
        var query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = encodedValue
        SecItemAdd(query as CFDictionary, nil)
    }

    private func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }

    private func delete(account: String) {
        let query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            // Requires device passcode; items deleted if passcode removed
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        ]
    }
}
