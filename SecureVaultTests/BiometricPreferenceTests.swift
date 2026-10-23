//
//  BiometricPreferenceTests.swift
//  SecureVaultTests
//
//  Created by Allan Ray Jasa on 23/10/2026.
//

import XCTest
@testable import SecureVault

private struct TestError: Error {}

// `@MainActor` + `async` on every test: a synchronous test of a main-actor
// type crashes with a bad free on iOS 26.3. This stays safe whether or not the
// target's default actor isolation makes `BiometricPreference` main-actor.
@MainActor
final class BiometricPreferenceTests: XCTestCase {

    // MARK: Harness

    private let expectedKey = "biometricUnlockEnabled"

    private func makeSUT() -> (sut: BiometricPreference, store: InMemoryKeychainStore) {
        let store = InMemoryKeychainStore()
        return (BiometricPreference(store: store), store)
    }

    // MARK: - isEnabled

    func test_isEnabled_whenNeverSet_returnsTrue() async {
        let (sut, _) = makeSUT()

        XCTAssertTrue(sut.isEnabled())
    }

    func test_isEnabled_whenStoredAsEnabled_returnsTrue() async {
        let (sut, store) = makeSUT()
        store.storage[expectedKey] = Data([1])

        XCTAssertTrue(sut.isEnabled())
    }

    func test_isEnabled_whenStoredAsDisabled_returnsFalse() async {
        let (sut, store) = makeSUT()
        store.storage[expectedKey] = Data([0])

        XCTAssertFalse(sut.isEnabled())
    }

    func test_isEnabled_whenKeychainReadFails_failsClosedAndReturnsTrue() async {
        let (sut, store) = makeSUT()
        store.storage[expectedKey] = Data([0])
        store.getError = TestError()

        XCTAssertTrue(sut.isEnabled(), "A read failure should assume the user wants protection")
    }

    func test_isEnabled_whenOnlyOtherKeysStored_returnsTrue() async {
        let (sut, store) = makeSUT()
        store.storage["someOtherKey"] = Data([0])

        XCTAssertTrue(sut.isEnabled(), "Values under other keys must not affect the preference")
    }

    // MARK: - isEnabled (unexpected stored data)
    //
    // These document the current behaviour: only `Data([1])` counts as enabled,
    // so anything else that can be read is treated as disabled.

    func test_isEnabled_whenStoredDataIsEmpty_returnsFalse() async {
        let (sut, store) = makeSUT()
        store.storage[expectedKey] = Data()

        XCTAssertFalse(sut.isEnabled())
    }

    func test_isEnabled_whenStoredDataIsUnrecognised_returnsFalse() async {
        let (sut, store) = makeSUT()
        store.storage[expectedKey] = Data([2])

        XCTAssertFalse(sut.isEnabled())
    }

    // MARK: - setEnabled

    func test_setEnabled_true_storesOneUnderExpectedKey() async throws {
        let (sut, store) = makeSUT()

        try sut.setEnabled(true)

        XCTAssertEqual(store.storage[expectedKey], Data([1]))
        XCTAssertEqual(store.storage.count, 1)
    }

    func test_setEnabled_false_storesZeroUnderExpectedKey() async throws {
        let (sut, store) = makeSUT()

        try sut.setEnabled(false)

        XCTAssertEqual(store.storage[expectedKey], Data([0]))
        XCTAssertEqual(store.storage.count, 1)
    }

    func test_setEnabled_false_makesIsEnabledReturnFalse() async throws {
        let (sut, _) = makeSUT()

        try sut.setEnabled(false)

        XCTAssertFalse(sut.isEnabled())
    }

    func test_setEnabled_true_makesIsEnabledReturnTrue() async throws {
        let (sut, _) = makeSUT()

        try sut.setEnabled(true)

        XCTAssertTrue(sut.isEnabled())
    }

    func test_setEnabled_toggledRepeatedly_reflectsLatestValue() async throws {
        let (sut, _) = makeSUT()

        try sut.setEnabled(false)
        XCTAssertFalse(sut.isEnabled())

        try sut.setEnabled(true)
        XCTAssertTrue(sut.isEnabled())

        try sut.setEnabled(false)
        XCTAssertFalse(sut.isEnabled())
    }

    func test_setEnabled_calledTwice_overwritesInsteadOfAddingEntries() async throws {
        let (sut, store) = makeSUT()

        try sut.setEnabled(true)
        try sut.setEnabled(false)

        XCTAssertEqual(store.storage.count, 1)
        XCTAssertEqual(store.storage[expectedKey], Data([0]))
    }

    func test_setEnabled_whenKeychainWriteFails_throwsAndStoresNothing() async {
        let (sut, store) = makeSUT()
        store.setError = TestError()

        XCTAssertThrowsError(try sut.setEnabled(false))
        XCTAssertTrue(store.storage.isEmpty)
    }

    func test_setEnabled_whenKeychainWriteFails_keepsPreviousValue() async throws {
        let (sut, store) = makeSUT()
        try sut.setEnabled(false)
        store.setError = TestError()

        XCTAssertThrowsError(try sut.setEnabled(true))

        XCTAssertFalse(sut.isEnabled(), "A failed write must not change the stored preference")
    }

    // MARK: - Persistence

    func test_isEnabled_onNewInstanceSharingStore_returnsPersistedValue() async throws {
        let store = InMemoryKeychainStore()
        try BiometricPreference(store: store).setEnabled(false)

        let reloaded = BiometricPreference(store: store)

        XCTAssertFalse(reloaded.isEnabled())
    }

    // MARK: - reset

    #if DEBUG
    func test_reset_afterSetEnabledFalse_restoresDefaultOn() async throws {
        let (sut, store) = makeSUT()
        try sut.setEnabled(false)
        XCTAssertFalse(sut.isEnabled())

        sut.reset()

        XCTAssertTrue(store.storage.isEmpty)
        XCTAssertTrue(sut.isEnabled(), "Never-set preference defaults to on")
    }

    func test_reset_always_deletesExpectedKey() async {
        let (sut, store) = makeSUT()

        sut.reset()

        XCTAssertEqual(store.deletedKeys, [expectedKey])
    }

    func test_reset_whenNothingStored_keepsDefaultOn() async {
        let (sut, _) = makeSUT()

        sut.reset()

        XCTAssertTrue(sut.isEnabled())
    }

    func test_reset_whenKeychainDeleteFails_keepsStoredValue() async throws {
        let (sut, store) = makeSUT()
        try sut.setEnabled(false)
        store.deleteError = TestError()

        sut.reset()

        XCTAssertFalse(sut.isEnabled(), "A failed delete leaves the stored preference untouched")
    }
    #endif
}
