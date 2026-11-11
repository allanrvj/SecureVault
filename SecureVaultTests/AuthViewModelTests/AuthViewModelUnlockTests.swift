//
//  AuthViewModelUnlockTests.swift
//  SecureVaultTests
//
//  Created by Allan Ray Jasa on 11/11/2026.
//

@testable import SecureVault
import XCTest

@MainActor
final class AuthViewModelUnlockTests: XCTestCase {
    // MARK: - unlock

    func test_unlock_onSuccess_isSignedIn() async {
        let harness = await makeLockedHarness()
        harness.authenticator.result = .success

        await harness.sut.unlock()

        XCTAssertEqual(harness.sut.state, .signedIn)
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
    }

    func test_unlock_whenCancelled_staysLocked() async {
        let harness = await makeLockedHarness()
        harness.authenticator.result = .cancelled

        await harness.sut.unlock()

        XCTAssertEqual(harness.sut.state, .locked)
    }

    func test_unlock_whenAuthenticationFails_staysLocked() async {
        let harness = await makeLockedHarness()
        harness.authenticator.result = .failed

        await harness.sut.unlock()

        XCTAssertEqual(harness.sut.state, .locked)
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
}
