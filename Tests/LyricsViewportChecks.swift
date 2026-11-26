import UIKit

@main struct LyricsViewportMain {
    static func main() {
        UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(LyricsViewportApp.self))
    }
}

@MainActor final class LyricsViewportApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var playbackPosition: Double = 0
    private var playbackDriver: Timer?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Checks", sessionRole: session.role)
        configuration.delegateClass = LyricsViewportScene.self
        return configuration
    }
    func start(in scene: UIWindowScene) {
        let controller = UIViewController()
        controller.view.backgroundColor = .black
        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller; window.makeKeyAndVisible(); self.window = window
        Task { @MainActor in
            do { try await checks(in: controller.view); finish(true, "Lyrics viewport: generated result, automatic following, interrupted animation, manual browsing, resume, seek and cached reload passed") }
            catch { finish(false, String(describing: error)) }
        }
    }
    private struct Failure: Error, CustomStringConvertible { var description: String }
    private func require(_ condition: @autoclosure () -> Bool, _ text: String) throws {
        if !condition() { throw Failure(description: text) }
    }
    private func settle() async throws { try await Task.sleep(nanoseconds: 650_000_000) }
    private func centered(_ view: LyricsView, row: Int) throws {
        view.table.layoutIfNeeded()
        let rect = view.table.rectForRow(at: IndexPath(row: row, section: 0))
        let distance = abs(rect.midY - view.table.contentOffset.y - view.table.bounds.midY)
        try require(distance < 36, "Row \(row) failed centering: \(distance); \(view.playbackDiagnostics())")
        try require(view.active == row, "Highlight did not follow playback to row \(row)")
    }
    private func checks(in host: UIView) async throws {
        let view = LyricsView(frame: CGRect(x: 16, y: 100, width: 330, height: 300))
        host.addSubview(view)
        playbackDriver = Timer(fire: Date().addingTimeInterval(0.05), interval: 0.05, repeats: true) { [weak self, weak view] _ in
            guard let self, let view else { return }
            view.update(time: self.playbackPosition)
        }
        RunLoop.main.add(playbackDriver!, forMode: .common)
        defer { playbackDriver?.invalidate(); playbackDriver = nil }
        let texts = (0..<16).map { "Строка \($0) — ветер над городом\nОстанется с нами до рассвета" }
        let plain = LyricsDocument(lines: texts.map { LyricLine(time: nil, text: $0) }, source: "Fixture")
        var generated = plain
        for row in generated.lines.indices {
            generated.lines[row].time = Double(row)
            generated.lines[row].end = Double(row) + 0.7
        }
        generated.timingTrusted = false
        generated.onDeviceTiming = LyricsOnDeviceTiming(language: "ru", date: Date(), wordCoverage: 0.8,
            lineCoverage: 1, originalLines: plain.lines, originalOffset: 0)
        view.display(plain); view.setNeedsLayout(); view.layoutIfNeeded()
        view.display(generated); view.layoutIfNeeded(); playbackPosition = 0.1; view.update(time: playbackPosition)
        try await settle(); try centered(view, row: 0)
        try require(view.playbackUpdates >= 5, "The UI clock must advance without taps or gestures")
        for row in 1...4 {
            playbackPosition = Double(row) + 0.1; view.update(time: playbackPosition)
            try await settle(); playbackPosition = Double(row) + 0.2; view.update(time: playbackPosition)
            try centered(view, row: row)
        }
        // Layout and compositor changes must not leave an animation lock latched.
        playbackPosition = 5.1; view.update(time: playbackPosition)
        view.frame.size.height = 350; view.setNeedsLayout(); view.layoutIfNeeded()
        view.table.layer.removeAllAnimations()
        try await settle(); playbackPosition = 5.2; view.update(time: playbackPosition)
        try centered(view, row: 5)
        view.scrollViewWillBeginDragging(view.table)
        view.table.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
        let browsingOffset = view.table.contentOffset.y
        playbackPosition = 8.1; view.update(time: playbackPosition); try await settle()
        try require(abs(view.table.contentOffset.y - browsingOffset) < 1, "Manual browsing was overridden")
        try require(view.active == 8, "Highlight stopped while browsing")
        view.resumeTapped(); try await settle(); playbackPosition = 8.2; view.update(time: playbackPosition)
        try centered(view, row: 8)
        playbackPosition = 10.1; view.update(time: playbackPosition); view.table.layer.removeAllAnimations()
        try await settle(); playbackPosition = 10.2; view.update(time: playbackPosition)
        try centered(view, row: 10)
        playbackPosition = 2.1; view.update(time: playbackPosition); try await settle(); playbackPosition = 2.2; view.update(time: playbackPosition)
        try centered(view, row: 2)
        view.display(generated); view.layoutIfNeeded(); playbackPosition = 11.1; view.update(time: playbackPosition)
        try await settle(); playbackPosition = 11.2; view.update(time: playbackPosition)
        try centered(view, row: 11)
        try require(view.table.frame.height == view.bounds.height, "Processing status must not reserve lyrics viewport space")
    }
    private func finish(_ passed: Bool, _ message: String) {
        let result: [String: Any] = ["passed": passed, "message": message]
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("lyrics-viewport-result.json")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted]) { try? data.write(to: url) }
        print(message)
        exit(passed ? 0 : 1)
    }
}

@MainActor final class LyricsViewportScene: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene, let app = UIApplication.shared.delegate as? LyricsViewportApp else { return }
        app.start(in: scene)
    }
}
