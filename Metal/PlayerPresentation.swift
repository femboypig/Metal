import Foundation

/// Shared motion and release rules, independent of UIKit gesture delivery.
enum PlayerPresentationMotion {
    static func step(position: Double, velocity: Double, target: Double, delta: Double)
        -> (position: Double, velocity: Double, finished: Bool) {
        let dt = min(1.0 / 30, max(0, delta))
        let speed = velocity + ((target - position) * 225 - velocity * 30) * dt
        let next = min(1, max(0, position + speed * dt))
        let finished = abs(target - next) < 0.0008 && abs(speed) < 0.012
        return (finished ? target : next, finished ? 0 : speed, finished)
    }

    static func shouldDismiss(progress: Double, velocity: Double, height: Double) -> Bool {
        let projected = progress - velocity * 0.18 / max(1, height)
        return projected < 0.8
    }

    /// Negative is next, positive is previous, zero returns the covers to rest.
    static func coverDirection(translation: Double, velocity: Double, width: Double) -> Int {
        let projected = translation + velocity * 0.12
        guard abs(projected) > max(44, width * 0.2) else { return 0 }
        return projected < 0 ? -1 : 1
    }
}
