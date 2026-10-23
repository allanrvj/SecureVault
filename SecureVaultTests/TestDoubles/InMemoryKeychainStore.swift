//
//  InMemoryKeychainStore.swift
//  SecureVaultTests
//
//  Shared test double so every test file uses the same fake.
//

import Foundation
@testable import SecureVault

final class InMemoryKeychainStore: KeychainStore, @unchecked Sendable {
    var storage: [String: Data] = [:]
    var getError: Error?
    var setError: Error?
    var deleteError: Error?

    private(set) var deletedKeys: [String] = []

    func set(_ data: Data, for key: String) throws {
        if let setError { throw setError }
        storage[key] = data
    }

    func get(_ key: String) throws -> Data? {
        if let getError { throw getError }
        return storage[key]
    }

    func delete(_ key: String) throws {
        deletedKeys.append(key)
        if let deleteError { throw deleteError }
        storage[key] = nil
    }
}
