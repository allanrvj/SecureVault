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
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
            Text("SecureVault is locked")
                .font(.title2)
            Button("Unlock") { Task { await viewModel.unlock() } }
                .buttonStyle(.borderedProminent)
            Button("Sign out", role: .destructive) { Task { await viewModel.signOut() } }
        }
        .task { await viewModel.unlock() }
    }
}

#if DEBUG
#Preview {
    LockedView(viewModel: .preview)
}
#endif // DEBUG
