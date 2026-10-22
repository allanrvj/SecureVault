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
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Home")
                        .font(.title)
                    Button("Log out") {
                        Task { await viewModel.signOut() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            SettingsView(viewModel: viewModel)
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
        }
}

#if DEBUG
#Preview {
    HomeView(viewModel: .preview)
}
#endif // DEBUG
