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

    static func shouldDismiss(progress: Double, translation: Double, velocity: Double, height: Double) -> Bool {
        // Velocity alone must never turn a short accidental touch into a dismissal.
        let deliberatePull = translation >= max(120, height * 0.19)
        let deliberateFlick = translation >= 110 && velocity >= 1250
        let projected = progress - max(0, velocity) * 0.12 / max(1, height)
        return (deliberatePull && projected < 0.74) || deliberateFlick
    }

    static func reveal(_ progress: Double, from start: Double, to end: Double) -> Double {
        let t = min(1, max(0, (progress - start) / max(0.001, end - start)))
        return t * t * (3 - 2 * t)
    }

    static func surfaceFrame(mini: CGRect, full: CGRect, progress: Double) -> CGRect {
        let t = CGFloat(min(1, max(0, progress)))
        return CGRect(x: mini.minX + (full.minX - mini.minX) * t,
            y: mini.minY + (full.minY - mini.minY) * t,
            width: mini.width + (full.width - mini.width) * t,
            height: mini.height + (full.height - mini.height) * t)
    }

    /// Negative is next, positive is previous, zero returns the covers to rest.
    static func coverDirection(translation: Double, velocity: Double, width: Double) -> Int {
        let projected = translation + velocity * 0.12
        guard abs(projected) > max(44, width * 0.2) else { return 0 }
        return projected < 0 ? -1 : 1
    }
}
