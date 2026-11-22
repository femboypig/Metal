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
        precondition(!PlayerPresentationMotion.shouldDismiss(progress: 0.95, velocity: 0, height: 850))
        precondition(PlayerPresentationMotion.shouldDismiss(progress: 0.72, velocity: 0, height: 850))
        precondition(PlayerPresentationMotion.shouldDismiss(progress: 0.95, velocity: 1000, height: 850))
        precondition(!PlayerPresentationMotion.shouldDismiss(progress: 0.72, velocity: -1000, height: 850))
        precondition(PlayerPresentationMotion.coverDirection(translation: -90, velocity: 0, width: 264) == -1)
        precondition(PlayerPresentationMotion.coverDirection(translation: 90, velocity: 0, width: 264) == 1)
        precondition(PlayerPresentationMotion.coverDirection(translation: 8, velocity: 10, width: 264) == 0)
        precondition(PlayerPresentationMotion.coverDirection(translation: -10, velocity: -600, width: 264) == -1)
        precondition(PlayerPresentationMotion.coverDirection(translation: 10, velocity: 600, width: 264) == 1)
        print("Player presentation: settling, cancelled dismissal, release velocity and cover swipes passed")
    }
}
