//
//  LockedView.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 20/10/2026.
//

import SwiftUI

struct LockedView: View {
    let viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Same icon family as the login header, so the app feels like one product
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("SecureVault is locked")
                    .font(.title2.bold())
                Text("Use Face ID or your passcode to continue")
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await viewModel.unlock() }
            } label: {
                // Icon + text tells users what will happen when they tap
                Label("Unlock", systemImage: "faceid")
            }
            .primaryButtonStyle()

            // Quiet secondary action: signing out is rare, so it shouldn't compete with Unlock
            Button("Sign out", role: .destructive) {
                Task { await viewModel.signOut() }
            }
            .font(.footnote)

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Same grouped background as Login and Settings
        .background(Color(.systemGroupedBackground))
    }
}

#if DEBUG
    #Preview {
        LockedView(viewModel: .preview)
    }
#endif // DEBUG
