import Foundation
import UserNotifications

/// The tap on the wrist when a timed session reaches zero, and the one that
/// follows if it is still running half an hour later.
///
/// The in-app haptic only fires while the app is on screen, and the whole point
/// of the running session is that you can crown out and forget it. A local
/// notification scheduled at the deadline is what makes the wrist tap arrive
/// either way; it is rescheduled whenever the deadline moves and cancelled the
/// moment the session stops running.
enum SessionAlerts {
    static let completeIdentifier = "app.diem.session.complete"
    static let overtimeIdentifier = "app.diem.session.overtime"

    /// How long a session is left past its deadline before the watch asks
    /// whether it was forgotten.
    ///
    /// Overtime is a real thing to do, so this can't be eager. But a session
    /// left running is not a session — it is one the recovery pass will throw
    /// away in full once it crosses twelve hours, and the only warning was the
    /// tap at the deadline that you already missed.
    static let overtimeGrace: TimeInterval = 30 * 60

    /// Scheduling is what needs permission, so scheduling is what asks for it.
    ///
    /// Prompting at launch spends the one prompt the system grants before the
    /// user has started anything — and before there is any way to tell what the
    /// alert would even be for.
    static func schedule(deadline: Date, subject: String?, now: Date = .now) {
        cancel()
        let complete = deadline.timeIntervalSince(now)
        let nudge = complete + overtimeGrace
        guard complete > 0 || nudge > 0 else { return }

        Task {
            let center = UNUserNotificationCenter.current()
            guard await isAuthorized(center) else { return }

            if complete > 0 {
                let content = UNMutableNotificationContent()
                content.title = subject ?? "Session complete"
                content.body = subject == nil ? "Time's up." : "Time's up on \(subject!)."
                content.interruptionLevel = .timeSensitive
                await add(content, id: completeIdentifier, after: complete, to: center)
            }

            if nudge > 0 {
                let content = UNMutableNotificationContent()
                content.title = "Still studying?"
                content.body = subject == nil
                    ? "Half an hour past time, and still running."
                    : "\(subject!) is half an hour past time, and still running."
                // Quieter than the deadline: this one is a question, not the
                // thing you asked to be told.
                content.interruptionLevel = .active
                await add(content, id: overtimeIdentifier, after: nudge, to: center)
            }
        }
    }

    private static func add(
        _ content: UNMutableNotificationContent,
        id: String,
        after delay: TimeInterval,
        to center: UNUserNotificationCenter
    ) async {
        try? await center.add(
            UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            )
        )
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(
                withIdentifiers: [completeIdentifier, overtimeIdentifier]
            )
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
