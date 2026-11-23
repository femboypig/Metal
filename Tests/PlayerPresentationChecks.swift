import Foundation
import CoreGraphics

@main
struct PlayerPresentationChecks {
    static func main() {
        for hz in [30.0, 60, 120] {
            for (start, target, duration) in [(0.0, 1.0, 0.46), (1, 0, 0.38), (0.97, 1, 0.16)] {
                var previous = start
                for i in 0...Int(ceil(duration * hz)) {
                    let next = PlayerPresentationMotion.position(start: start, target: target,
                        elapsed: Double(i) / hz, duration: duration)
                    precondition((0...1).contains(next))
                    precondition(target > start ? next >= previous : next <= previous)
                    previous = next
                }
                precondition(previous == target, "The slide must finish within its fixed duration")
            }
        }
        // Both directions use precisely the same mini-player and full-player endpoints.
        for height in [568.0, 667, 844, 932, 1024] {
            let mini = CGRect(x: 16, y: height - 102, width: 358, height: 60)
            let full = CGRect(x: 0, y: 0, width: 390, height: height)
            precondition(PlayerPresentationMotion.frame(source: mini, destination: full, progress: 0) == mini)
            precondition(PlayerPresentationMotion.frame(source: mini, destination: full, progress: 1) == full)
            precondition(PlayerPresentationMotion.frame(source: mini, destination: full, progress: -1) == mini)
            precondition(PlayerPresentationMotion.frame(source: mini, destination: full, progress: 2) == full)
            var previous = mini
            for i in 1...100 {
                let frame = PlayerPresentationMotion.frame(source: mini, destination: full, progress: Double(i) / 100)
                precondition(frame.minY <= previous.minY && frame.height >= previous.height)
                precondition(full.contains(frame))
                previous = frame
            }
        }
        precondition(PlayerPresentationMotion.phase(0, from: 0.2, to: 0.8) == 0)
        precondition(PlayerPresentationMotion.phase(1, from: 0.2, to: 0.8) == 1)
        // A short fast brush cannot close the player; a deliberate short pull commits immediately.
        for distance in [0.0, 8, 20, 35] {
            precondition(!PlayerPresentationMotion.shouldCommitPull(translation: distance, velocity: 3000))
        }
        precondition(!PlayerPresentationMotion.shouldCommitPull(translation: 63, velocity: 0))
        precondition(PlayerPresentationMotion.shouldCommitPull(translation: 64, velocity: 0))
        precondition(PlayerPresentationMotion.shouldCommitPull(translation: 36, velocity: 650))
        precondition(!PlayerPresentationMotion.shouldCommitPull(translation: -100, velocity: 2000))
        precondition(PlayerPresentationMotion.pullOffset(translation: 8) == 0)
        precondition(PlayerPresentationMotion.pullOffset(translation: 64) < 28)
        for distance in [-100.0, 0, 36, 64, 500, 2000] {
            precondition((0...28).contains(PlayerPresentationMotion.pullOffset(translation: distance)))
        }
        precondition(PlayerPresentationMotion.coverDirection(translation: -90, velocity: 0, width: 264) == -1)
        precondition(PlayerPresentationMotion.coverDirection(translation: 90, velocity: 0, width: 264) == 1)
        precondition(PlayerPresentationMotion.coverDirection(translation: 8, velocity: 10, width: 264) == 0)
        precondition(PlayerPresentationMotion.coverDirection(translation: -10, velocity: -600, width: 264) == -1)
        precondition(PlayerPresentationMotion.coverDirection(translation: 10, velocity: 600, width: 264) == 1)
        print("Player presentation: anchored transition geometry, shared timing, bounded pull, automatic dismissal threshold and cover swipes passed")
    }
}
