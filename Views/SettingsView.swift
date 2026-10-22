//
//  SettingsView.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 20/10/2026.
//

import SwiftUI

struct SettingsView: View {
    let viewModel: AuthViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Authenticate with Face ID", isOn: Binding(
                    get: { viewModel.isBiometricLockEnabled },
                    set: { newValue in Task { await viewModel.setBiometricLock(newValue) } }
                ))
            } footer: {
                if let message = viewModel.settingsMessage {
                    Text(message).foregroundStyle(.red)
                }
            }
            #if DEBUG
            Section("Debug") {
                Button("Reset Face ID preference", role: .destructive) {
                    viewModel.resetBiometricLock()
                }
            }
            #endif // DEBUG
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    SettingsView(viewModel: .preview)
}
#endif // DEBUG
