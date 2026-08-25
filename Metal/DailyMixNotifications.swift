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
    private let identifierPrefix = "metal.daily-mix.minute."

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
        ("Need some music?", "We’ve got something for you.")
    ]

    private init() {}

    func requestAuthorizationAndSchedule() {
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }

            switch settings.authorizationStatus {
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if let error {
                        print("Daily Mix notifications: authorization failed: \(error)")
                    }
                    if granted {
                        self.scheduleEveryMinute()
                    }
                }
            case .authorized, .provisional, .ephemeral:
                self.scheduleEveryMinute()
            case .denied:
                self.removeScheduledNotifications()
            @unknown default:
                break
            }
        }
    }

    private func scheduleEveryMinute() {
        // Calendar triggers keep firing even while Metal is suspended or not
        // running. Sixty requests cover every minute of the hour indefinitely.
        for minute in 0..<60 {
            let message = messages[minute % messages.count]
            let content = UNMutableNotificationContent()
            content.title = message.title
            content.body = message.body
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier
            content.threadIdentifier = "metal.daily-mix"
            content.userInfo = [Self.destinationKey: Self.destinationValue]

            var dateComponents = DateComponents()
            dateComponents.calendar = .autoupdatingCurrent
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)\(minute)",
                content: content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error {
                    print("Daily Mix notifications: failed to schedule minute \(minute): \(error)")
                }
            }
        }
    }

    private func removeScheduledNotifications() {
        let identifiers = (0..<60).map { "\(identifierPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
