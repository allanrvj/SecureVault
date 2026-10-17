//
//  PasswordPolicy.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 15/10/2026.
//

import Foundation

enum PasswordPolicy {
    static let minimumLength = 6

    static func isValid(_ password: String) -> Bool {
        password.count >= minimumLength
    }
}
