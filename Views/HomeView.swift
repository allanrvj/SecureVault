//
//  HomeView.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 17/10/2026.
//

import SwiftUI

struct HomeView: View {
    let viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Home")
                .font(.title)
            Button("Log out") {
                Task { await viewModel.signOut() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    HomeView(viewModel: AuthViewModel(service: PreviewAuthService()))
}

private struct PreviewAuthService: AuthService {
    func signIn(email: String, password: String) async throws {}
    func signOut() async throws {}
    func hasValidSession() async -> Bool { true }
}
