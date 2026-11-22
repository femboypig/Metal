import Foundation

@main
struct PlayerPresentationChecks {
    static func main() {
        for hz in [30.0, 60, 120] {
            var position = 0.0, velocity = 0.0
            for target in [1.0, 0, 1] {
                var finished = false
                for _ in 0..<Int(hz * 2) {
                    let next = PlayerPresentationMotion.step(position: position, velocity: velocity,
                        target: target, delta: 1 / hz)
                    precondition((0...1).contains(next.position))
                    position = next.position; velocity = next.velocity
                    if next.finished { finished = true; break }
                }
                precondition(finished && position == target, "Presentation must settle at each refresh rate")
            }
            // A downward drag can reverse into a cancelled dismissal without jumping or diverging.
            position = 0.65; velocity = -1.2
            for _ in 0..<Int(hz * 2) {
                let next = PlayerPresentationMotion.step(position: position, velocity: velocity, target: 1, delta: 1 / hz)
                position = next.position; velocity = next.velocity
            }
            precondition(position == 1)
        }
        for height in [568.0, 667, 844, 932, 1024] {
            // Even an extremely quick accidental brush must return to the open player.
            for distance in [10.0, 30, 60, 90] {
                precondition(!PlayerPresentationMotion.shouldDismiss(progress: 0.95,
                    translation: distance, velocity: 3000, height: height))
            }
            precondition(PlayerPresentationMotion.shouldDismiss(progress: 0.65,
                translation: height * 0.4, velocity: 0, height: height))
            precondition(PlayerPresentationMotion.shouldDismiss(progress: 0.88,
                translation: 120, velocity: 1400, height: height))
            precondition(!PlayerPresentationMotion.shouldDismiss(progress: 0.95,
                translation: 150, velocity: -1000, height: height))
            let full = CGRect(x: 0, y: 0, width: 390, height: height)
            let mini = CGRect(x: 16, y: height - 102, width: 358, height: 60)
            precondition(PlayerPresentationMotion.surfaceFrame(mini: mini, full: full, progress: 0) == mini)
            precondition(PlayerPresentationMotion.surfaceFrame(mini: mini, full: full, progress: 1) == full)
            precondition(PlayerPresentationMotion.surfaceFrame(mini: mini, full: full, progress: -1) == mini)
            precondition(PlayerPresentationMotion.surfaceFrame(mini: mini, full: full, progress: 2) == full)
            var last = mini
            for i in 1...100 {
                let frame = PlayerPresentationMotion.surfaceFrame(mini: mini, full: full, progress: Double(i) / 100)
                precondition(frame.minY <= last.minY && frame.height >= last.height)
                precondition(full.contains(frame))
                last = frame
            }
        }
        precondition(PlayerPresentationMotion.reveal(0, from: 0.3, to: 0.88) == 0)
        precondition(PlayerPresentationMotion.reveal(1, from: 0.3, to: 0.88) == 1)
        precondition(PlayerPresentationMotion.coverDirection(translation: -90, velocity: 0, width: 264) == -1)
        precondition(PlayerPresentationMotion.coverDirection(translation: 90, velocity: 0, width: 264) == 1)
        precondition(PlayerPresentationMotion.coverDirection(translation: 8, velocity: 10, width: 264) == 0)
        precondition(PlayerPresentationMotion.coverDirection(translation: -10, velocity: -600, width: 264) == -1)
        precondition(PlayerPresentationMotion.coverDirection(translation: 10, velocity: 600, width: 264) == 1)
        print("Player presentation: settling, mini-player geometry, deliberate dismissal and cover swipes passed")
    }
}
