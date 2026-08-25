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
    /// Lets the deadline alert through while the app is frontmost.
    ///
    /// A notification arriving for the frontmost app is not presented unless a
    /// delegate says so, and that used to be harmless: if the app was frontmost
    /// you were looking at the running screen, whose own haptic fires on the
    /// zero crossing. The frontmost hold changed that arithmetic — the app is
    /// now frontmost for the whole session, wrist down included, where the
    /// running screen ticks once a minute and its haptic can be a minute late.
    /// The alert that would have been on time was the one being suppressed.
    /// No stored state, so sharing one across actors is safe by inspection.
    final class Presenter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
        static let shared = Presenter()

        nonisolated func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            [.banner, .sound, .list]
        }
    }

    /// Called once, at launch.
    @MainActor
    static func install() {
        UNUserNotificationCenter.current().delegate = Presenter.shared
    }

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

    /// The one task doing the scheduling, so two of them can never race.
    ///
    /// `schedule` cancels synchronously and then adds from a task. Hold and
    /// resume in quick succession spawned two, and because both write the same
    /// identifiers the surviving request was whichever finished last — which
    /// could be the one carrying the older deadline. Each call now waits for
    /// the one before it, so the last caller wins because it is last.
    @MainActor private static var pending: Task<Void, Never>?

    /// Scheduling is what needs permission, so scheduling is what asks for it.
    ///
    /// Prompting at launch spends the one prompt the system grants before the
    /// user has started anything — and before there is any way to tell what the
    /// alert would even be for.
    @MainActor
    static func schedule(deadline: Date, subject: String?, now: Date = .now) {
        let complete = deadline.timeIntervalSince(now)
        let nudge = complete + overtimeGrace
        guard complete > 0 || nudge > 0 else {
            cancel()
            return
        }

        let previous = pending
        pending = Task { @MainActor in
            _ = await previous?.value
            let center = UNUserNotificationCenter.current()
            // Cancelled here rather than before the task: clearing the old
            // requests only to have an authorisation prompt refused would leave
            // the session with no alert at all.
            guard await isAuthorized(center) else { return }
            guard !Task.isCancelled else { return }
            center.removePendingNotificationRequests(
                withIdentifiers: [completeIdentifier, overtimeIdentifier]
            )

            if complete > 0 {
                let content = UNMutableNotificationContent()
                // The title used to be the subject and the body repeated it —
                // "Maths / Time's up on Maths." The subject is the heading; the
                // body says the one thing the heading does not.
                content.title = subject ?? "Session complete"
                content.body = "Time's up."
                content.interruptionLevel = .active
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

    @MainActor
    static func cancel() {
        pending?.cancel()
        pending = nil
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
