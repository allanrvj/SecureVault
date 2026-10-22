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
                supabaseURL: AppConfig.supabaseURL,
                supabaseKey: AppConfig.supabaseKey,
                options: SupabaseClientOptions (auth: .init(emitLocalSessionAsInitialSession: true))
            )
        ),
        authenticator: SystemDeviceAuthenticator(),
        preference: BiometricPreference(store: SystemKeychainStore())
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
            case .locked:
                LockedView(viewModel: viewModel)
            case .signedOut:
                SignupLoginView(viewModel: viewModel)
            case .signedIn:
                HomeView(viewModel: viewModel)
            }
        }
    }
}
