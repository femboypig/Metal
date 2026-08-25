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
        ("Need some music?", "We’ve got something for you.")
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
        // One repeating calendar request per possible day of the month keeps a
        // different message rotating daily while still working when Metal is
        // suspended. Every valid calendar date fires at 10:00 local time.
        for day in 1...31 {
            let message = messages[(day - 1) % messages.count]
            let content = UNMutableNotificationContent()
            content.title = message.title
            content.body = message.body
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier
            content.threadIdentifier = "metal.daily-mix"
            content.userInfo = [Self.destinationKey: Self.destinationValue]

            var dateComponents = DateComponents()
            dateComponents.calendar = .autoupdatingCurrent
            dateComponents.day = day
            dateComponents.hour = 10
            dateComponents.minute = 0

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
