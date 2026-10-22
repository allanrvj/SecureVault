//
//  PreviewAuthService.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 17/10/2026.
//

import Foundation

#if DEBUG
struct PreviewAuthService: AuthService {
    func signIn(email: String, password: String) async throws {}
    func signOut() async throws {}
    func hasValidSession() async -> Bool { true }
}

extension AuthViewModel {
    static var preview: AuthViewModel {
        AuthViewModel(service: PreviewAuthService(),
                      authenticator: FakeDeviceAuthenticator(),
                      preference: BiometricPreference(store: FakeKeychainStore()))
    }
}
#endif // DEBUG

#if DEBUG
struct FakeDeviceAuthenticator: DeviceAuthenticator {
    var result: BiometricResult = .success
    func authenticate(reason: String) async -> BiometricResult { result }
}
#endif

#if DEBUG
final class FakeKeychainStore: KeychainStore {
    private var storage: [String: Data] = [:]

    func get(_ key: String) throws -> Data? { storage[key] }
    func set(_ data: Data, for key: String) throws { storage[key] = data }
    func delete(_ key: String) throws {}
}
#endif // DEBUG
