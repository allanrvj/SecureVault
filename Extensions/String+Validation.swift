//
//  String+Validation.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 15/10/2026.
//

import Foundation

extension String {
    var isValidEmail: Bool {
        trimmingCharacters(in: .whitespaces)
            .wholeMatch(of: /[^\s@]+@[^\s@]+\.[^\s@]+/) != nil
    }
}
