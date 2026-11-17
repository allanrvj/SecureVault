//
//  AuthViewModelLockTests.swift
//  SecureVaultTests
//
//  Created by Allan Ray Jasa on 17/11/2026.
//

@testable import SecureVault
import XCTest

@MainActor
final class AuthViewModelLockTests: XCTestCase {
    /// Restored with the lock enabled, then unlocked: signed in, lock still on.
    private func makeSignedInHarness() async -> Harness {
        let harness = await makeLockedHarness()
        await harness.sut.unlock()
        XCTAssertEqual(harness.sut.state, .signedIn, "Precondition: view model should be signed in")
        return harness
    }

    // MARK: - lock

    func test_lock_whenSignedInWithLockEnabled_locks() async {
        let harness = await makeSignedInHarness()

        harness.sut.lock()

        XCTAssertEqual(harness.sut.state, .locked)
    }

    func test_lock_afterFreshSignIn_locksWhenLockPreferenceIsOn() async {
        let harness = makeHarness()
        await harness.sut.signIn(email: "allan@example.com", password: "secret")
        XCTAssertEqual(harness.sut.state, .signedIn)

        harness.sut.lock()

        XCTAssertEqual(harness.sut.state, .locked)
    }

    func test_lock_whenLockDisabled_staysSignedIn() async {
        let harness = await makeSignedInHarness()
        await harness.sut.setBiometricLock(false)

        harness.sut.lock()

        XCTAssertEqual(harness.sut.state, .signedIn)
    }

    func test_lock_whenSignedOut_staysSignedOut() async {
        let harness = makeHarness()
        harness.service.hasSession = false
        await harness.sut.restoreSession()

        harness.sut.lock()

        XCTAssertEqual(harness.sut.state, .signedOut)
    }

    func test_lock_whileLoading_staysLoading() async {
        let harness = makeHarness()

        harness.sut.lock()

        XCTAssertEqual(harness.sut.state, .loading)
    }

    func test_lock_whenAlreadyLocked_staysLockedWithoutAuthenticating() async {
        let harness = await makeLockedHarness()

        harness.sut.lock()

        XCTAssertEqual(harness.sut.state, .locked)
        XCTAssertEqual(harness.authenticator.callCount, 0)
    }

    func test_lock_thenUnlock_signsInAgain() async {
        let harness = await makeSignedInHarness()
        harness.sut.lock()

        await harness.sut.unlock()

        XCTAssertEqual(harness.sut.state, .signedIn)
        XCTAssertEqual(harness.authenticator.callCount, 2)
    }
}
