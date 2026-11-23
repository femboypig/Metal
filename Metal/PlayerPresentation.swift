import Foundation
import CoreGraphics

/// Shared motion and release rules, independent of UIKit gesture delivery.
enum PlayerPresentationMotion {
    static func frame(source: CGRect, destination: CGRect, progress: Double) -> CGRect {
        let t = CGFloat(min(1, max(0, progress)))
        let x: CGFloat = source.origin.x + (destination.origin.x - source.origin.x) * t
        let y: CGFloat = source.origin.y + (destination.origin.y - source.origin.y) * t
        let width: CGFloat = source.size.width + (destination.size.width - source.size.width) * t
        let height: CGFloat = source.size.height + (destination.size.height - source.size.height) * t
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func collapsedTransform(from destination: CGRect, to source: CGRect) -> CGAffineTransform {
        let scale = min(source.width / max(1, destination.width), source.height / max(1, destination.height))
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
            tx: source.midX - destination.midX, ty: source.midY - destination.midY)
    }

    static func transform(_ collapsed: CGAffineTransform, progress: Double) -> CGAffineTransform {
        let t = CGFloat(min(1, max(0, progress)))
        return CGAffineTransform(a: collapsed.a + (1 - collapsed.a) * t, b: 0, c: 0,
            d: collapsed.d + (1 - collapsed.d) * t, tx: collapsed.tx * (1 - t), ty: collapsed.ty * (1 - t))
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
