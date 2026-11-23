import Foundation
import CoreGraphics

/// Shared motion and release rules, independent of UIKit gesture delivery.
enum PlayerPresentationMotion {
    static func position(start: Double, target: Double, elapsed: Double, duration: Double) -> Double {
        let t = min(1, max(0, elapsed / max(0.001, duration)))
        // A critically damped response: one coherent motion without overshoot or a bounce.
        let response = 1 - (1 + 8 * t) * exp(-8 * t)
        let eased = response / (1 - 9 * exp(-8))
        return start + (target - start) * eased
    }

    static func phase(_ progress: Double, from start: Double, to end: Double) -> Double {
        let t = min(1, max(0, (progress - start) / max(0.001, end - start)))
        return t * t * (3 - 2 * t)
    }

    static func frame(source: CGRect, destination: CGRect, progress: Double) -> CGRect {
        let t = CGFloat(min(1, max(0, progress)))
        let x: CGFloat = source.origin.x + (destination.origin.x - source.origin.x) * t
        let y: CGFloat = source.origin.y + (destination.origin.y - source.origin.y) * t
        let width: CGFloat = source.size.width + (destination.size.width - source.size.width) * t
        let height: CGFloat = source.size.height + (destination.size.height - source.size.height) * t
        return CGRect(x: x, y: y, width: width, height: height)
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
