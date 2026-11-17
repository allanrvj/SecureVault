//
//  AutoLockMonitor.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 13/11/2026.
//

import Combine
import Foundation
import UIKit

/// Calls `onLock` when the app enters the background, or when the user has
/// been idle (no touches, no typing) for `idleTimeout` seconds.
@MainActor
final class AutoLockMonitor {
    static let idleTimeout: TimeInterval = 60

    private let touches = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var touchRecognizer: TouchRecognizer?

    init(
        idleTimeout: TimeInterval = AutoLockMonitor.idleTimeout,
        notificationCenter: NotificationCenter = .default,
        onLock: @escaping @MainActor () -> Void
    ) {
        // Trigger 1: app goes to the background -> lock immediately.
        let enteredBackground = notificationCenter
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .map { _ in () }

        // "Activity" = a touch, or typing (the keyboard lives in its own
        // window, so taps on it never reach our touch recognizer).
        let activity = Publishers.Merge3(
            touches,
            notificationCenter.publisher(for: UITextField.textDidChangeNotification).map { _ in () },
            notificationCenter.publisher(for: UITextView.textDidChangeNotification).map { _ in () }
        )

        // Trigger 2: idle. debounce only emits once the upstream has been
        // quiet for `idleTimeout`, which is exactly "idle for N seconds".
        // prepend(()) starts the clock at launch, before the first touch.
        let idle = activity
            .prepend(())
            .debounce(for: .seconds(idleTimeout), scheduler: DispatchQueue.main)

        Publishers.Merge(enteredBackground, idle)
            .sink { onLock() }
            .store(in: &cancellables)
    }

    /// Call once the window exists (e.g. from the root view's onAppear).
    func installTouchTracking() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        guard touchRecognizer == nil,
              let window = windows.first(where: \.isKeyWindow) ?? windows.first
        else { return }

        let recognizer = TouchRecognizer { [weak self] in self?.registerActivity() }
        window.addGestureRecognizer(recognizer)
        touchRecognizer = recognizer
    }

    func registerActivity() {
        touches.send()
    }
}

/// Reports every touch-down anywhere in the window without interfering
/// with the app's own gestures.
private final class TouchRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private let onTouch: () -> Void

    init(onTouch: @escaping () -> Void) {
        self.onTouch = onTouch
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_: Set<UITouch>, with _: UIEvent) {
        onTouch()
        state = .failed // step aside so we never block other recognizers
    }

    func gestureRecognizer(
        _: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
