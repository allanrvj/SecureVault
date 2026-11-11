//
//  AuthViewModelSessionTests.swift
//  SecureVaultTests
//
//  Created by Allan Ray Jasa on 11/11/2026.
//

@testable import SecureVault
import XCTest

@MainActor
final class AuthViewModelSessionTests: XCTestCase {
    // MARK: - Initial state

    func test_init_startsInLoadingStateWithNoMessages() async {
        let sut = makeHarness().sut

        XCTAssertEqual(sut.state, .loading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertNil(sut.settingsMessage)
        XCTAssertFalse(sut.isSubmitting)
        XCTAssertFalse(sut.isBiometricLockEnabled)
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
}
