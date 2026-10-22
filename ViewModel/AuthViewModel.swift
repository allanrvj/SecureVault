//
//  AuthViewModel.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 15/10/2026.
//

import Foundation
import Supabase

@MainActor
@Observable
final class AuthViewModel {
    enum State {
        case loading, locked, signedOut, signedIn
    }
    
    var state: State = .loading
    var errorMessage: String?
    var isSubmitting = false
    private(set) var settingsMessage: String?
    private(set) var isBiometricLockEnabled = false
    private(set) var deviceLockUnavailable = false
    private var isAuthenticating = false
        
    private let service: AuthService
    private let authenticator: DeviceAuthenticator
    private let preference: BiometricPreference
    
    init(service: AuthService,
         authenticator: DeviceAuthenticator,
         preference: BiometricPreference) {
        self.service = service
        self.authenticator = authenticator
        self.preference = preference
    }
    
    func restoreSession() async {
        guard await service.hasValidSession() else {
            state = .signedOut
            return
        }
        isBiometricLockEnabled = preference.isEnabled()
        state = isBiometricLockEnabled ? .locked : .signedIn
    }
    
    func signIn(email: String, password: String) async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        
        do {
            try await service.signIn(email: email, password: password)
            state = .signedIn
        } catch {
            errorMessage = "Sign in failed. Check your email and password."
        }
    }
    
    func signOut() async {
        do {
            try await service.signOut()
        } catch {
            // Even if the network call fails, treat the user as signed out locally
        }
        state = .signedOut
    }
    
    func unlock() async {
        guard state == .locked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        switch await authenticator.authenticate(reason: "Unlock SecureVault") {
        case .success:
            state = .signedIn
        case .unavailable:
            // Gate can't be enforced; don't lock the user out of their own vault
            deviceLockUnavailable = true
            state = .signedIn
        case .cancelled, .failed:
            state = .locked
        }
    }
    
    func setBiometricLock(_ enabled: Bool) async {
        settingsMessage = nil

        guard enabled else {
            save(false)
            return
        }

        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        switch await authenticator.authenticate(reason: "Confirm to turn on Face ID unlock") {
        case .success:
            save(true)
        case .cancelled, .failed:
            break // the switch stays off
        case .unavailable:
            settingsMessage = "Set up a device passcode or Face ID in iOS Settings first."
        }
    }
    
    private func save(_ enabled: Bool) {
        do {
            try preference.setEnabled(enabled)
            isBiometricLockEnabled = enabled
        } catch {
            settingsMessage = "Couldn't save the setting."
        }
    }
    
    #if DEBUG
    func resetBiometricLock() {
        preference.reset()
        isBiometricLockEnabled = false
        settingsMessage = nil
    }
    #endif
}
