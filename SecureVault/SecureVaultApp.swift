//
//  SecureVaultApp.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 13/10/2026.
//

import SwiftUI
import Supabase

@main
struct SecureVaultApp: App {
    @State private var authViewModel = AuthViewModel(
        service: SupabaseAuthService(
            client: SupabaseClient(
                supabaseURL: URL(string: "https://yybwnewqjzlbngelcwql.supabase.co")!,
                supabaseKey: "sb_publishable_xKGo112KcXU1eNrLDyxldQ_ldiAhB2C",
                options: SupabaseClientOptions (auth: .init(emitLocalSessionAsInitialSession: true))
            )
        )
    )
    
    var body: some Scene {
        WindowGroup {
            RootView(viewModel: authViewModel)
        }
    }
    
    struct RootView: View {
        let viewModel: AuthViewModel

        var body: some View {
            switch viewModel.state {
            case .loading:
                ProgressView()
                    .task { await viewModel.restoreSession() }
            case .signedOut:
                SignupLoginScreen(viewModel: viewModel)
            case .signedIn:
                HomeView(viewModel: viewModel)
            }
        }
    }
}
