//
//  AuthViewModelTests.swift
//  SecureVaultTests
//
//  Created by Allan Ray Jasa on 22/10/2026.
//

import XCTest
@testable import SecureVault

// MARK: - Test doubles
//
// The fakes are `@unchecked Sendable` so they compile under both Swift 5 and
// Swift 6 language modes. Tests drive them sequentially, so there is no real
// concurrent access.

private struct TestError: Error {}

private final class FakeAuthService: AuthService, @unchecked Sendable {
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
        if let signInError { throw signInError }
    }

    func finishSignIn() {
        isSignInSuspended = false
        signInContinuation?.resume()
        signInContinuation = nil
    }

    func signOut() async throws {
        signOutCallCount += 1
        if let signOutError { throw signOutError }
    }

    func hasValidSession() async -> Bool { hasSession }
}

private final class FakeDeviceAuthenticator: DeviceAuthenticator, @unchecked Sendable {
    var result: BiometricResult = .success
    var suspends = false

    private(set) var reasons: [String] = []
    private(set) var isSuspended = false
    private var continuation: CheckedContinuation<BiometricResult, Never>?

    var callCount: Int { reasons.count }

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

// MARK: - Tests

@MainActor
final class AuthViewModelTests: XCTestCase {

    // MARK: Harness

    private struct Harness {
        let sut: AuthViewModel
        let service: FakeAuthService
        let authenticator: FakeDeviceAuthenticator
        let store: InMemoryKeychainStore
        let preference: BiometricPreference
    }

    private func makeHarness() -> Harness {
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
    private func makeLockedHarness() async -> Harness {
        let harness = makeHarness()
        harness.service.hasSession = true
        await harness.sut.restoreSession()
        XCTAssertEqual(harness.sut.state, .locked, "Precondition: view model should be locked")
        return harness
    }

    /// Yields to the main actor until `condition` holds, so tests can observe
    /// a call that is suspended mid-flight without sleeping.
    private func waitUntil(_ condition: @autoclosure () -> Bool,
                           file: StaticString = #filePath,
                           line: UInt = #line) async {
        for _ in 0..<1_000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("Condition was not met in time", file: file, line: line)
    }

    // MARK: - Initial state

    func test_init_startsInLoadingStateWithNoMessages() async {
        let sut = makeHarness().sut

        XCTAssertEqual(sut.state, .loading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertNil(sut.settingsMessage)
        XCTAssertFalse(sut.isSubmitting)
        XCTAssertFalse(sut.isBiometricLockEnabled)
        XCTAssertFalse(sut.deviceLockUnavailable)
    }

    // MARK: - restoreSession

    func test_restoreSession_withoutValidSession_isSignedOut() async {
        let harness = makeHarness()
        harness.service.hasSession = false

        await harness.sut.restoreSession()

        XCTAssertEqual(harness.sut.state, .signedOut)
        XCTAssertFalse(harness.sut.isBiometricLockEnabled)
    }

    func test_restoreSession_withValidSessionAndPreferenceNeverSet_isLocked() async {
        let harness = makeHarness()
        harness.service.hasSession = true

        await harness.sut.restoreSession()

        XCTAssertEqual(harness.sut.state, .locked)
        XCTAssertTrue(harness.sut.isBiometricLockEnabled)
    }

    func test_restoreSession_withValidSessionAndLockEnabled_isLocked() async throws {
        let harness = makeHarness()
        harness.service.hasSession = true
        try harness.preference.setEnabled(true)

        await harness.sut.restoreSession()

        XCTAssertEqual(harness.sut.state, .locked)
        XCTAssertTrue(harness.sut.isBiometricLockEnabled)
    }

    func test_restoreSession_withValidSessionAndLockDisabled_isSignedIn() async throws {
        let harness = makeHarness()
        harness.service.hasSession = true
        try harness.preference.setEnabled(false)

        await harness.sut.restoreSession()

        XCTAssertEqual(harness.sut.state, .signedIn)
        XCTAssertFalse(harness.sut.isBiometricLockEnabled)
    }

    func test_restoreSession_whenKeychainReadFails_failsClosedAndIsLocked() async {
        let harness = makeHarness()
        harness.service.hasSession = true
        harness.store.getError = TestError()

        await harness.sut.restoreSession()

        XCTAssertEqual(harness.sut.state, .locked)
        XCTAssertTrue(harness.sut.isBiometricLockEnabled)
    }

    // MARK: - signIn

    func test_signIn_onSuccess_isSignedInWithoutError() async {
        let harness = makeHarness()

        await harness.sut.signIn(email: "allan@example.com", password: "secret")

        XCTAssertEqual(harness.sut.state, .signedIn)
        XCTAssertNil(harness.sut.errorMessage)
        XCTAssertFalse(harness.sut.isSubmitting)
    }

    func test_signIn_forwardsCredentialsToService() async {
        let harness = makeHarness()

        await harness.sut.signIn(email: "allan@example.com", password: "secret")

        XCTAssertEqual(harness.service.signInCalls.count, 1)
        XCTAssertEqual(harness.service.signInCalls.first?.email, "allan@example.com")
        XCTAssertEqual(harness.service.signInCalls.first?.password, "secret")
    }

    func test_signIn_onFailure_setsErrorMessageAndStaysSignedOut() async {
        let harness = makeHarness()
        harness.service.hasSession = false
        await harness.sut.restoreSession()
        harness.service.signInError = TestError()

        await harness.sut.signIn(email: "allan@example.com", password: "wrong")

        XCTAssertEqual(harness.sut.state, .signedOut)
        XCTAssertEqual(harness.sut.errorMessage, "Sign in failed. Check your email and password.")
        XCTAssertFalse(harness.sut.isSubmitting)
    }

    func test_signIn_afterFailure_clearsPreviousErrorOnRetry() async {
        let harness = makeHarness()
        harness.service.signInError = TestError()
        await harness.sut.signIn(email: "allan@example.com", password: "wrong")
        XCTAssertNotNil(harness.sut.errorMessage)

        harness.service.signInError = nil
        await harness.sut.signIn(email: "allan@example.com", password: "right")

        XCTAssertNil(harness.sut.errorMessage)
        XCTAssertEqual(harness.sut.state, .signedIn)
    }

    func test_signIn_whileInFlight_isSubmittingIsTrueThenResets() async {
        let harness = makeHarness()
        harness.service.suspendSignIn = true

        let task = Task { await harness.sut.signIn(email: "allan@example.com", password: "secret") }
        await waitUntil(harness.service.isSignInSuspended)

        XCTAssertTrue(harness.sut.isSubmitting)

        harness.service.finishSignIn()
        await task.value

        XCTAssertFalse(harness.sut.isSubmitting)
        XCTAssertEqual(harness.sut.state, .signedIn)
    }

    // MARK: - signOut

    func test_signOut_onSuccess_isSignedOut() async {
        let harness = makeHarness()
        await harness.sut.signIn(email: "allan@example.com", password: "secret")

        await harness.sut.signOut()

        XCTAssertEqual(harness.sut.state, .signedOut)
        XCTAssertEqual(harness.service.signOutCallCount, 1)
    }

    func test_signOut_whenServiceThrows_isStillSignedOutLocally() async {
        let harness = makeHarness()
        await harness.sut.signIn(email: "allan@example.com", password: "secret")
        harness.service.signOutError = TestError()

        await harness.sut.signOut()

        XCTAssertEqual(harness.sut.state, .signedOut)
        XCTAssertEqual(harness.service.signOutCallCount, 1)
    }

    // MARK: - unlock

    func test_unlock_onSuccess_isSignedIn() async {
        let harness = await makeLockedHarness()
        harness.authenticator.result = .success

        await harness.sut.unlock()

        XCTAssertEqual(harness.sut.state, .signedIn)
        XCTAssertFalse(harness.sut.deviceLockUnavailable)
    }

    func test_unlock_usesExpectedAuthenticationReason() async {
        let harness = await makeLockedHarness()

        await harness.sut.unlock()

        XCTAssertEqual(harness.authenticator.reasons, ["Unlock SecureVault"])
    }

    func test_unlock_whenDeviceLockUnavailable_letsUserInAndFlagsIt() async {
        let harness = await makeLockedHarness()
        harness.authenticator.result = .unavailable

        await harness.sut.unlock()

        XCTAssertEqual(harness.sut.state, .signedIn)
        XCTAssertTrue(harness.sut.deviceLockUnavailable)
    }

    func test_unlock_whenCancelled_staysLocked() async {
        let harness = await makeLockedHarness()
        harness.authenticator.result = .cancelled

        await harness.sut.unlock()

        XCTAssertEqual(harness.sut.state, .locked)
        XCTAssertFalse(harness.sut.deviceLockUnavailable)
    }

    func test_unlock_whenAuthenticationFails_staysLocked() async {
        let harness = await makeLockedHarness()
        harness.authenticator.result = .failed

        await harness.sut.unlock()

        XCTAssertEqual(harness.sut.state, .locked)
        XCTAssertFalse(harness.sut.deviceLockUnavailable)
    }

    func test_unlock_afterCancellation_canBeRetried() async {
        let harness = await makeLockedHarness()
        harness.authenticator.result = .cancelled
        await harness.sut.unlock()
        XCTAssertEqual(harness.sut.state, .locked)

        harness.authenticator.result = .success
        await harness.sut.unlock()

        XCTAssertEqual(harness.sut.state, .signedIn)
        XCTAssertEqual(harness.authenticator.callCount, 2)
    }

    func test_unlock_whenSignedOut_doesNotAuthenticate() async {
        let harness = makeHarness()
        harness.service.hasSession = false
        await harness.sut.restoreSession()

        await harness.sut.unlock()

        XCTAssertEqual(harness.sut.state, .signedOut)
        XCTAssertEqual(harness.authenticator.callCount, 0)
    }

    func test_unlock_whenAlreadySignedIn_doesNotAuthenticate() async {
        let harness = makeHarness()
        await harness.sut.signIn(email: "allan@example.com", password: "secret")

        await harness.sut.unlock()

        XCTAssertEqual(harness.sut.state, .signedIn)
        XCTAssertEqual(harness.authenticator.callCount, 0)
    }

    func test_unlock_whileAuthenticationInFlight_doesNotStartSecondAuthentication() async {
        let harness = await makeLockedHarness()
        harness.authenticator.suspends = true

        let first = Task { await harness.sut.unlock() }
        await waitUntil(harness.authenticator.isSuspended)

        await harness.sut.unlock()

        XCTAssertEqual(harness.authenticator.callCount, 1)

        harness.authenticator.finish(with: .success)
        await first.value

        XCTAssertEqual(harness.sut.state, .signedIn)
        XCTAssertEqual(harness.authenticator.callCount, 1)
    }

    // MARK: - setBiometricLock (enable)

    func test_setBiometricLock_enable_onSuccess_enablesAndPersists() async throws {
        let harness = makeHarness()
        try harness.preference.setEnabled(false)
        harness.authenticator.result = .success

        await harness.sut.setBiometricLock(true)

        XCTAssertTrue(harness.sut.isBiometricLockEnabled)
        XCTAssertTrue(harness.preference.isEnabled())
        XCTAssertNil(harness.sut.settingsMessage)
    }

    func test_setBiometricLock_enable_usesExpectedAuthenticationReason() async {
        let harness = makeHarness()

        await harness.sut.setBiometricLock(true)

        XCTAssertEqual(harness.authenticator.reasons, ["Confirm to turn on Face ID unlock"])
    }

    func test_setBiometricLock_enable_whenCancelled_staysOffAndSavesNothing() async {
        let harness = makeHarness()
        harness.authenticator.result = .cancelled

        await harness.sut.setBiometricLock(true)

        XCTAssertFalse(harness.sut.isBiometricLockEnabled)
        XCTAssertNil(harness.sut.settingsMessage)
        XCTAssertTrue(harness.store.storage.isEmpty)
    }

    func test_setBiometricLock_enable_whenAuthenticationFails_staysOffAndSavesNothing() async {
        let harness = makeHarness()
        harness.authenticator.result = .failed

        await harness.sut.setBiometricLock(true)

        XCTAssertFalse(harness.sut.isBiometricLockEnabled)
        XCTAssertNil(harness.sut.settingsMessage)
        XCTAssertTrue(harness.store.storage.isEmpty)
    }

    func test_setBiometricLock_enable_whenDeviceLockUnavailable_showsSetupMessage() async {
        let harness = makeHarness()
        harness.authenticator.result = .unavailable

        await harness.sut.setBiometricLock(true)

        XCTAssertFalse(harness.sut.isBiometricLockEnabled)
        XCTAssertEqual(harness.sut.settingsMessage,
                       "Set up a device passcode or Face ID in iOS Settings first.")
        XCTAssertTrue(harness.store.storage.isEmpty)
    }

    func test_setBiometricLock_enable_whenSaveFails_showsSaveErrorAndStaysOff() async {
        let harness = makeHarness()
        harness.authenticator.result = .success
        harness.store.setError = TestError()

        await harness.sut.setBiometricLock(true)

        XCTAssertFalse(harness.sut.isBiometricLockEnabled)
        XCTAssertEqual(harness.sut.settingsMessage, "Couldn't save the setting.")
    }

    func test_setBiometricLock_enable_clearsPreviousMessage() async {
        let harness = makeHarness()
        harness.authenticator.result = .unavailable
        await harness.sut.setBiometricLock(true)
        XCTAssertNotNil(harness.sut.settingsMessage)

        harness.authenticator.result = .success
        await harness.sut.setBiometricLock(true)

        XCTAssertNil(harness.sut.settingsMessage)
        XCTAssertTrue(harness.sut.isBiometricLockEnabled)
    }

    func test_setBiometricLock_enable_whileAuthenticationInFlight_isIgnored() async {
        let harness = makeHarness()
        harness.authenticator.suspends = true

        let first = Task { await harness.sut.setBiometricLock(true) }
        await waitUntil(harness.authenticator.isSuspended)

        await harness.sut.setBiometricLock(true)

        XCTAssertEqual(harness.authenticator.callCount, 1)

        harness.authenticator.finish(with: .success)
        await first.value

        XCTAssertTrue(harness.sut.isBiometricLockEnabled)
        XCTAssertEqual(harness.authenticator.callCount, 1)
    }

    // MARK: - setBiometricLock (disable)

    func test_setBiometricLock_disable_persistsWithoutPromptingForAuthentication() async {
        let harness = makeHarness()
        await harness.sut.setBiometricLock(true)
        XCTAssertEqual(harness.authenticator.callCount, 1)

        await harness.sut.setBiometricLock(false)

        XCTAssertFalse(harness.sut.isBiometricLockEnabled)
        XCTAssertFalse(harness.preference.isEnabled())
        XCTAssertEqual(harness.authenticator.callCount, 1, "Disabling should not prompt again")
        XCTAssertNil(harness.sut.settingsMessage)
    }

    func test_setBiometricLock_disable_whenSaveFails_showsSaveErrorAndKeepsLockEnabled() async {
        let harness = makeHarness()
        await harness.sut.setBiometricLock(true)
        harness.store.setError = TestError()

        await harness.sut.setBiometricLock(false)

        XCTAssertTrue(harness.sut.isBiometricLockEnabled)
        XCTAssertEqual(harness.sut.settingsMessage, "Couldn't save the setting.")
    }

    // MARK: - resetBiometricLock

    #if DEBUG
    func test_resetBiometricLock_clearsFlagAndMessage() async {
        let harness = makeHarness()
        harness.authenticator.result = .unavailable
        await harness.sut.setBiometricLock(true)
        XCTAssertNotNil(harness.sut.settingsMessage)

        harness.sut.resetBiometricLock()

        XCTAssertFalse(harness.sut.isBiometricLockEnabled)
        XCTAssertNil(harness.sut.settingsMessage)
    }

    func test_resetBiometricLock_removesStoredPreference_soDefaultAppliesAgain() async throws {
        let harness = makeHarness()
        try harness.preference.setEnabled(false)
        XCTAssertFalse(harness.preference.isEnabled())

        harness.sut.resetBiometricLock()

        XCTAssertTrue(harness.preference.isEnabled(), "Never-set preference defaults to on")
    }
    #endif
}
