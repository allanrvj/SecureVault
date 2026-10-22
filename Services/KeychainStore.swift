//
//  KeychainStore.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 19/10/2026.
//

import Foundation

protocol KeychainStore {
    func set(_ data: Data, for key: String) throws
    func get(_ key: String) throws -> Data?
    func delete(_ key: String) throws
}
