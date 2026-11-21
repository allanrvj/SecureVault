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
            List {
                Section("Your vault") {
                    ForEach(VaultItem.samples) { item in
                        Label(item.title, systemImage: item.symbol)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await viewModel.signOut() }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                        } else {
                            Text("Log out")
                        }
                    }
                    .disabled(viewModel.isSubmitting)
                }
            }
            .navigationTitle("Vault")
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

/// Placeholder data until real vault storage exists
struct VaultItem: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String

    static let samples = [
        VaultItem(title: "Passwords", symbol: "key.fill"),
        VaultItem(title: "Documents", symbol: "doc.fill"),
        VaultItem(title: "Secure notes", symbol: "note.text"),
    ]
}

#if DEBUG
    #Preview {
        HomeView(viewModel: .preview)
    }
#endif // DEBUG
