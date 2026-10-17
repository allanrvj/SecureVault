//
//  SupabaseAuthService.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 17/10/2026.
//

import Supabase

struct SupabaseAuthService: AuthService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func hasValidSession() async -> Bool {
        // Throws if there is no session (or it can't be refreshed)
        (try? await client.auth.session) != nil
    }
}
