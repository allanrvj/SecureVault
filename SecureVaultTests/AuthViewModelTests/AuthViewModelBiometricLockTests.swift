//
//  AuthViewModelBiometricLockTests.swift
//  SecureVaultTests
//
//  Created by Allan Ray Jasa on 11/11/2026.
//

@testable import SecureVault
import XCTest

@MainActor
final class AuthViewModelBiometricLockTests: XCTestCase {
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
    #endif // DEBUG
}
