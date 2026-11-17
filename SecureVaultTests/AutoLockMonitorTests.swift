//
//  AutoLockMonitorTests.swift
//  SecureVaultTests
//
//  Created by Allan Ray Jasa on 17/11/2026.
//

@testable import SecureVault
import UIKit
import XCTest

/// MainActor-isolated so the monitor's onLock closure can capture it under Swift 6.
@MainActor
private final class LockCounter {
    var count = 0
}

@MainActor
final class AutoLockMonitorTests: XCTestCase {
    func test_enteringBackground_locksImmediately() async {
        let center = NotificationCenter()
        let counter = LockCounter()
        let monitor = AutoLockMonitor(notificationCenter: center) { counter.count += 1 }

        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        XCTAssertEqual(counter.count, 1)
        withExtendedLifetime(monitor) {}
    }

    func test_otherNotifications_doNotLock() async {
        let center = NotificationCenter()
        let counter = LockCounter()
        let monitor = AutoLockMonitor(notificationCenter: center) { counter.count += 1 }

        // Control Center, system dialogs and the Face ID prompt resign active only.
        center.post(name: UIApplication.willResignActiveNotification, object: nil)

        XCTAssertEqual(counter.count, 0)
        withExtendedLifetime(monitor) {}
    }

    func test_idleForTimeout_locks() async {
        let counter = LockCounter()
        let locked = expectation(description: "locked after idle timeout")
        let monitor = AutoLockMonitor(idleTimeout: 0.05, notificationCenter: NotificationCenter()) {
            counter.count += 1
            locked.fulfill()
        }

        await fulfillment(of: [locked], timeout: 2)

        XCTAssertEqual(counter.count, 1)
        withExtendedLifetime(monitor) {}
    }

    func test_activity_postponesIdleLock() async throws {
        let counter = LockCounter()
        let monitor = AutoLockMonitor(idleTimeout: 0.4, notificationCenter: NotificationCenter()) {
            counter.count += 1
        }

        try await Task.sleep(for: .milliseconds(250))
        monitor.registerActivity() // idle clock restarts here
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(counter.count, 0, "500 ms passed, but only 250 ms since the last activity")

        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(counter.count, 1, "Should lock once idle for the full timeout")
        withExtendedLifetime(monitor) {}
    }
}
