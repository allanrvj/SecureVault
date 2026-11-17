//
//  SettingsView.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 20/10/2026.
//

import SwiftUI

struct SettingsView: View {
    let viewModel: AuthViewModel

    private var idleDescription: String {
        Duration.seconds(AutoLockMonitor.idleTimeout)
            .formatted(.units(allowed: [.minutes, .seconds], width: .wide))
    }

    var body: some View {
        Form {
            Section {
                Toggle("Require Face ID", isOn: Binding(
                    get: { viewModel.isBiometricLockEnabled },
                    set: { newValue in Task { await viewModel.setBiometricLock(newValue) } }
                ))
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("When on, SecureVault locks as soon as you leave the app and after \(idleDescription)"
                        + " without activity. Face ID or your device passcode is needed to open it again."
                        + " When off, anyone holding your unlocked phone can open your vault.")
                    if let message = viewModel.settingsMessage {
                        Text(message).foregroundStyle(.red)
                    }
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
