import Foundation
import UserNotifications

/// The tap on the wrist when a timed session reaches zero.
///
/// The in-app haptic only fires while the app is on screen, and the whole point
/// of the running session is that you can crown out and forget it. A local
/// notification scheduled at the deadline is what makes the wrist tap arrive
/// either way; it is rescheduled whenever the deadline moves and cancelled the
/// moment the session stops running.
enum SessionAlerts {
    static let identifier = "app.diem.session.complete"

    /// Scheduling is what needs permission, so scheduling is what asks for it.
    ///
    /// Prompting at launch spends the one prompt the system grants before the
    /// user has started anything — and before there is any way to tell what the
    /// alert would even be for.
    static func schedule(at date: Date, subject: String?) {
        cancel()
        let delay = date.timeIntervalSinceNow
        guard delay > 0 else { return }

        Task {
            let center = UNUserNotificationCenter.current()
            guard await isAuthorized(center) else { return }

            let content = UNMutableNotificationContent()
            content.title = subject ?? "Session complete"
            content.body = subject == nil ? "Time's up." : "Time's up on \(subject!)."
            content.interruptionLevel = .timeSensitive

            try? await center.add(
                UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(
                        timeInterval: delay,
                        repeats: false
                    )
                )
            )
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private static func isAuthorized(_ center: UNUserNotificationCenter) async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            // Declined once is an answer. The in-app haptic still fires.
            return false
        default:
            return true
        }
    }
}
