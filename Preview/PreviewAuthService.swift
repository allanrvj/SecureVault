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
        AuthViewModel(service: PreviewAuthService())
    }
}
#endif
