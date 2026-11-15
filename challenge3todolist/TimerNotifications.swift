import Foundation
import UserNotifications

/// Local notifications for the study timer, so the user hears when a focus
/// or break phase ends even if the app is in the background.
/// Only one is ever pending: scheduling replaces the previous one.
enum TimerNotifications {
    private static let identifier = "timer.phaseEnd"

    /// Schedules the "phase finished" alert for `seconds` from now.
    /// The first time, this asks for permission and schedules only once the
    /// user has answered (iOS rejects requests added before that).
    static func schedule(after seconds: TimeInterval, endingFocus: Bool) {
        guard seconds > 0 else { return }
        let fireDate = Date.now.addingTimeInterval(seconds)

        // Returns straight away with the saved answer after the first time.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            // The user may have taken a while to answer the prompt.
            let remaining = fireDate.timeIntervalSinceNow
            guard granted, remaining > 0 else { return }

            let content = UNMutableNotificationContent()
            content.title = endingFocus ? "Focus time done" : "Break over"
            content.body = endingFocus ? "Nice work! Time for a short break." : "Ready to focus again?"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    /// Removes the pending alert (paused, cancelled or ended).
    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
