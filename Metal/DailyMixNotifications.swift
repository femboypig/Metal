//
//  DailyMixNotifications.swift
//  Metal
//

import Foundation
import UserNotifications

extension Notification.Name {
    static let metalDailyMixNotificationTapped = Notification.Name(
        "MetalDailyMixNotificationTapped"
    )
}

final class DailyMixNotificationScheduler {
    static let shared = DailyMixNotificationScheduler()

    static let categoryIdentifier = "METAL_DAILY_MIX"
    static let destinationKey = "metal.destination"
    static let destinationValue = "daily-mix"

    private let center = UNUserNotificationCenter.current()
    private let dailyIdentifierPrefix = "metal.daily-mix.day."
    private let legacyMinuteIdentifierPrefix = "metal.daily-mix.minute."

    private let messages: [(title: String, body: String)] = [
        ("This might hit today", "Open your daily mix."),
        ("Your music. Right now.", "Tap to start listening."),
        ("Made for you", "Your daily mix is ready."),
        ("Your mix just dropped", "See what made the cut today."),
        ("Today sounds like this", "Your personalized mix is ready."),
        ("Something for right now", "Your daily playlist is waiting."),
        ("Your day needs a soundtrack", "We’ve already made one."),
        ("Fresh picks for you", "A new mix, made for today."),
        ("This one’s for you", "Your daily playlist is waiting."),
        ("Need some music?", "We’ve got something for you."),
        ("A little less scrolling", "A little more listening. Open your mix."),
        ("Press play on today", "Your daily selection is waiting."),
        ("Meet your next listen", "Take your mix for a spin."),
        ("A moment for music", "Start with one track. See where it goes."),
        ("Find your rhythm", "Your mix is a tap away."),
        ("Take the scenic route", "Let your daily mix keep you company."),
        ("Back to the music", "Pick up with your personal mix."),
        ("Give today a listen", "Open Metal and start your mix."),
        ("A small listening break", "Your playlist is ready when you are."),
        ("Something worth a play", "Explore today’s selection."),
        ("Make room for a song", "Your mix can take it from here."),
        ("Your library, another angle", "Hear a different side of your collection."),
        ("Let the next song choose", "Start your mix and follow along."),
        ("For your headphones", "A personal selection, ready to play."),
        ("No search needed", "Tap into your daily mix."),
        ("Stay for another track", "Your daily playlist is waiting in Metal."),
        ("A familiar place to start", "Find your way through today’s mix."),
        ("Bring the music along", "Your mix is ready for wherever you’re headed."),
        ("Turn a moment into music", "Press play on your daily selection."),
        ("What’s next?", "There’s a mix waiting in Metal."),
        ("One tap, a whole mix", "Let your library surprise you.")
    ]

    private init() {}

    func requestAuthorizationAndSchedule() {
        removeLegacyMinuteNotifications()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }

            switch settings.authorizationStatus {
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if let error {
                        print("Daily Mix notifications: authorization failed: \(error)")
                    }
                    if granted {
                        self.scheduleDailyNotification()
                    }
                }
            case .authorized, .provisional, .ephemeral:
                self.scheduleDailyNotification()
            case .denied:
                self.removeDailyNotifications()
            @unknown default:
                break
            }
        }
    }

    private func scheduleDailyNotification() {
        // Persist a different minute for each day-of-month. Repeating calendar
        // requests keep working without a server or background app execution.
        // Scheduling again must not move an already pending notification today.
        let defaults = UserDefaults.standard
        let key = "Metal_DailyMixNotificationMinutes_v2"
        var minutes = defaults.array(forKey: key) as? [Int] ?? []
        if minutes.count != 31 || minutes.contains(where: { !(540...1230).contains($0) }) {
            minutes = (1...31).map { _ in Int.random(in: 540...1230) }
            for index in 1..<minutes.count {
                while abs(minutes[index] - minutes[index - 1]) < 60 {
                    minutes[index] = Int.random(in: 540...1230)
                }
            }
            defaults.set(minutes, forKey: key)
        }
        for day in 1...31 {
            let message = messages[(day - 1) % messages.count]
            let content = UNMutableNotificationContent()
            content.title = message.title
            let hour = minutes[day - 1] / 60
            let invitation = hour < 12 ? "A soundtrack for your morning."
                : (hour < 18 ? "Make a little space for music today." : "Something to listen to this evening.")
            content.body = day.isMultiple(of: 3) ? invitation : message.body
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier
            content.threadIdentifier = "metal.daily-mix"
            content.userInfo = [Self.destinationKey: Self.destinationValue]

            var dateComponents = DateComponents()
            dateComponents.calendar = .autoupdatingCurrent
            dateComponents.day = day
            dateComponents.hour = minutes[day - 1] / 60
            dateComponents.minute = minutes[day - 1] % 60

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: "\(dailyIdentifierPrefix)\(day)",
                content: content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error {
                    print("Daily Mix notifications: failed to schedule day \(day): \(error)")
                }
            }
        }
    }

    private func removeLegacyMinuteNotifications() {
        let identifiers = (0..<60).map { "\(legacyMinuteIdentifierPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func removeDailyNotifications() {
        let identifiers = (1...31).map { "\(dailyIdentifierPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
