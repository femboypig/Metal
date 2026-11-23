import Foundation
import CoreGraphics

@main
struct PlayerPresentationChecks {
    static func main() {
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
        let fullCover = CGRect(x: 40, y: 160, width: 310, height: 310)
        let miniCover = CGRect(x: 28, y: 752, width: 42, height: 42)
        let collapsed = PlayerPresentationMotion.collapsedTransform(from: fullCover, to: miniCover)
        precondition(abs(fullCover.width * collapsed.a - miniCover.width) < 0.001)
        precondition(abs(fullCover.height * collapsed.d - miniCover.height) < 0.001)
        precondition(abs(fullCover.midX + collapsed.tx - miniCover.midX) < 0.001)
        precondition(abs(fullCover.midY + collapsed.ty - miniCover.midY) < 0.001)
        precondition(PlayerPresentationMotion.transform(collapsed, progress: 0) == collapsed)
        precondition(PlayerPresentationMotion.transform(collapsed, progress: 1) == .identity)
        for i in 0...100 {
            let pose = PlayerPresentationMotion.transform(collapsed, progress: Double(i) / 100)
            precondition(pose.a == pose.d && pose.b == 0 && pose.c == 0,
                "Artwork must keep its aspect ratio throughout the real-view transition")
        }
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
        print("Player presentation: real-view transforms, anchored clipping geometry, bounded pull, automatic dismissal threshold and cover swipes passed")
    }
}
