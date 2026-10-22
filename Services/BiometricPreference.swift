//
//  BiometricPreference.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 19/10/2026.
//

import Foundation

struct BiometricPreference {
    private let store: KeychainStore
    private let key = "biometricUnlockEnabled"

    init(store: KeychainStore) { self.store = store }

    func isEnabled() -> Bool {
        do {
            guard let data = try store.get(key) else { return true } // never set: default on
            return data == Data([1])
        } catch {
            // Can't read the preference: assume the user wants protection
            return true
        }
    }
    
    func setEnabled(_ enabled: Bool) throws {
        try store.set(Data([enabled ? 1 : 0]), for: key)
    }
    
    #if DEBUG
    func reset() {
        try? store.delete(key)
    }
    #endif
}
