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

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    static func schedule(at date: Date, subject: String?) {
        cancel()
        let delay = date.timeIntervalSinceNow
        guard delay > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = subject ?? "Session complete"
        content.body = subject == nil ? "Time's up." : "Time's up on \(subject!)."
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
