//
//  AuthViewModel.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 15/10/2026.
//

import Foundation
import Supabase

@MainActor
@Observable
final class AuthViewModel {
    enum State {
            case loading, signedOut, signedIn
        }

        var state: State = .loading
        var isSubmitting = false
        var errorMessage: String?

        private let service: AuthService

        init(service: AuthService) {
            self.service = service
        }

        func restoreSession() async {
            state = await service.hasValidSession() ? .signedIn : .signedOut
        }

        func signIn(email: String, password: String) async {
            isSubmitting = true
            errorMessage = nil
            defer { isSubmitting = false }

            do {
                try await service.signIn(email: email, password: password)
                state = .signedIn
            } catch {
                errorMessage = "Sign in failed. Check your email and password."
            }
        }

        func signOut() async {
            do {
                try await service.signOut()
            } catch {
                // Even if the network call fails, treat the user as signed out locally
            }
            state = .signedOut
        }
}
