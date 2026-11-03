import Foundation

@main
enum ListeningHistoryChecks {
    static func main() {
        let now = 1_800_000_000.0
        func event(_ reason: ListeningEndReason, seconds: Double = 2, progress: Double = 0.01,
                   age: Double = 0, manual: Bool = false) -> ListeningSessionEvent {
            ListeningSessionEvent(filename: "song", timestamp: now - age, hour: 12, weekday: 2,
                listenedSeconds: seconds, progress: progress, skipped: reason == .next,
                source: .dailyMix, reason: reason, duration: 180, manuallySelected: manual)
        }
        let immediateSkip = event(.next, seconds: 0.2)
        precondition(immediateSkip.isRejection && immediateSkip.reward < 0,
            "Sub-five-second skips must be retained as evidence")
        precondition(!event(.selection).isRejection && event(.selection).reward == 0)
        precondition(!event(.previous).isRejection && event(.previous).reward == 0)
        precondition(event(.sleepTimer, seconds: 170, progress: 0.95).reward == 0)
        precondition(event(.failure).reward == 0)
        precondition(event(.dislike, seconds: 175).reward == -1)
        let soughtEnd = event(.completed, seconds: 5, progress: 1)
        precondition(soughtEnd.reward == 0 && soughtEnd.engagement < 0.05,
            "Seeking to the end must not count as listening")
        let positive = event(.completed, seconds: 179, progress: 1)
        let one = ListeningTaste.learnedAdjustment(events: [immediateSkip], now: now)
        precondition(one > -0.2 && one < 0, "One rejection must have limited influence")
        let old = ListeningTaste.learnedAdjustment(events: [event(.next, age: 80 * 86_400)], now: now)
        precondition(abs(old) < abs(one), "Old evidence must decay")
        let recovered = ListeningTaste.learnedAdjustment(events: [immediateSkip] + Array(repeating: positive, count: 8), now: now)
        precondition(recovered > 0, "Positive listening must recover from earlier rejection")
        let automatic = ListeningTaste.learnedAdjustment(events: [positive], now: now)
        let intentional = ListeningTaste.learnedAdjustment(events: [event(.completed, seconds: 179, progress: 1, manual: true)], now: now)
        precondition(intentional > automatic, "Manual listening carries stronger positive evidence")
        let quality = ListeningQuality.dailyMix(in: [immediateSkip, positive, event(.sleepTimer), event(.failure)])
        precondition(quality.impressions == 2 && quality.earlySkipRate == 0.5 && quality.completionRate == 0.5)
        let legacy = Data(#"{"version":1,"tracks":{"song":{"playStarts":3}},"sessions":[{"filename":"song","timestamp":100,"hour":12,"weekday":2,"listenedSeconds":90,"progress":0.5,"skipped":false}]}"#.utf8)
        let decoded = try! JSONDecoder().decode(ListeningTelemetryDocument.self, from: legacy)
        precondition(decoded.tracks["song"]?.playStarts == 3)
        precondition(decoded.sessions?.first?.source == nil && decoded.sessions?.first?.engagement == 0.5)
        let roundtrip = try! JSONDecoder().decode(ListeningSessionEvent.self, from: JSONEncoder().encode(immediateSkip))
        precondition(roundtrip.reason == .next && roundtrip.source == .dailyMix && roundtrip.isRejection)
        print("Listening history behavioral checks passed")
    }
}
