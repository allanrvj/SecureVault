//
//  AuthViewModelTestSupport.swift
//  SecureVaultTests
//
//  Shared test doubles and helpers for the AuthViewModel test files.
//
//  Created by Allan Ray Jasa on 10/11/2026.
//

@testable import SecureVault
import XCTest

// MARK: - Test doubles

//
// The fakes are `@unchecked Sendable` so they compile under both Swift 5 and
// Swift 6 language modes. Tests drive them sequentially, so there is no real
// concurrent access.

struct TestError: Error {}

final class FakeAuthService: AuthService, @unchecked Sendable {
    var hasSession = false
    var signInError: Error?
    var signOutError: Error?
    var suspendSignIn = false

    private(set) var signInCalls: [(email: String, password: String)] = []
    private(set) var signOutCallCount = 0
    private(set) var isSignInSuspended = false
    private var signInContinuation: CheckedContinuation<Void, Never>?

    func signIn(email: String, password: String) async throws {
        signInCalls.append((email, password))
        if suspendSignIn {
            await withCheckedContinuation { continuation in
                self.signInContinuation = continuation
                self.isSignInSuspended = true
            }
        }
        if let signInError {
            throw signInError
        }
    }

    func finishSignIn() {
        isSignInSuspended = false
        signInContinuation?.resume()
        signInContinuation = nil
    }

    func signOut() async throws {
        signOutCallCount += 1
        if let signOutError {
            throw signOutError
        }
    }

    func hasValidSession() async -> Bool {
        hasSession
    }
}

final class FakeDeviceAuthenticator: DeviceAuthenticator, @unchecked Sendable {
    var result: BiometricResult = .success
    var suspends = false

    private(set) var reasons: [String] = []
    private(set) var isSuspended = false
    private var continuation: CheckedContinuation<BiometricResult, Never>?

    var callCount: Int {
        reasons.count
    }

    func authenticate(reason: String) async -> BiometricResult {
        reasons.append(reason)
        guard suspends else { return result }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.isSuspended = true
        }
    }

    func finish(with result: BiometricResult) {
        isSuspended = false
        continuation?.resume(returning: result)
        continuation = nil
    }
}

// MARK: - Harness

struct Harness {
    let sut: AuthViewModel
    let service: FakeAuthService
    let authenticator: FakeDeviceAuthenticator
    let store: InMemoryKeychainStore
    let preference: BiometricPreference
}

@MainActor
func makeHarness() -> Harness {
    let service = FakeAuthService()
    let authenticator = FakeDeviceAuthenticator()
    let store = InMemoryKeychainStore()
    let preference = BiometricPreference(store: store)
    let sut = AuthViewModel(service: service,
                            authenticator: authenticator,
                            preference: preference)
    return Harness(sut: sut,
                   service: service,
                   authenticator: authenticator,
                   store: store,
                   preference: preference)
}

/// A view model that has restored a valid session with the lock enabled.
@MainActor
func makeLockedHarness() async -> Harness {
    let harness = makeHarness()
    harness.service.hasSession = true
    await harness.sut.restoreSession()
    XCTAssertEqual(harness.sut.state, .locked, "Precondition: view model should be locked")
    return harness
}

/// Yields to the main actor until `condition` holds, so tests can observe
/// a call that is suspended mid-flight without sleeping.
@MainActor
func waitUntil(_ condition: @autoclosure () -> Bool,
               file: StaticString = #filePath,
               line: UInt = #line) async {
    for _ in 0 ..< 1000 {
        if condition() {
            return
        }
        await Task.yield()
    }
    XCTFail("Condition was not met in time", file: file, line: line)
}
