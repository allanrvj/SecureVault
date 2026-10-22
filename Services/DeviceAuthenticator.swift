//
//  BiometricAuthenticator.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 20/10/2026.
//

import Foundation
import LocalAuthentication

enum BiometricResult: Equatable {
    case success, cancelled, unavailable, failed
}

protocol DeviceAuthenticator {
    func authenticate(reason: String) async -> BiometricResult
}

struct SystemDeviceAuthenticator: DeviceAuthenticator {
    func authenticate(reason: String) async -> BiometricResult {
        let context = LAContext() // fresh context per attempt
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .unavailable // no passcode set
        }
        
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return ok ? .success : .failed
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .systemCancel, .appCancel:
                return .cancelled
            case .passcodeNotSet, .biometryNotAvailable, .biometryNotEnrolled:
                return .unavailable
            default:
                return .failed
            }
        } catch {
            return .failed
        }
    }
}
