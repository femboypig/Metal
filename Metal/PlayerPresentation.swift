import Foundation

/// Shared motion and release rules, independent of UIKit gesture delivery.
enum PlayerPresentationMotion {
    static func position(start: Double, target: Double, elapsed: Double, duration: Double) -> Double {
        let t = min(1, max(0, elapsed / max(0.001, duration)))
        let eased = 1 - pow(1 - t, 3)
        return start + (target - start) * eased
    }

    static func pullOffset(translation: Double) -> Double {
        // A short resistant pull gives feedback without allowing manual full-screen dragging.
        min(28, max(0, translation - 8) * 0.4)
    }

    static func shouldCommitPull(translation: Double, velocity: Double) -> Bool {
        translation >= 64 || (translation >= 36 && velocity >= 650)
    }

    /// Negative is next, positive is previous, zero returns the covers to rest.
    static func coverDirection(translation: Double, velocity: Double, width: Double) -> Int {
        let projected = translation + velocity * 0.12
        guard abs(projected) > max(44, width * 0.2) else { return 0 }
        return projected < 0 ? -1 : 1
    }
}
