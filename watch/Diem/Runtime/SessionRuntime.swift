import SwiftUI
import WatchKit

/// Holds the app frontmost for as long as a session is live.
///
/// A watchOS app is put away the moment the wrist drops, and the raise that
/// follows lands on the watch face rather than on whatever was in the middle of
/// happening. The system Timer is the exception everyone has felt: while it is
/// counting, the raise comes back to the count. An extended runtime session is
/// the public way to ask for that, and the `mindfulness` type is the one that
/// runs *frontmost* rather than in the background — which is the property
/// wanted here. Nothing needs to happen while the screen is off. The screen
/// needs to come back to the clock that is already running.
///
/// The system's rules, and what each costs here:
///
/// - **A session can only be started while the app is active.** So this is
///   driven off the scene phase as much as off the session: one started from
///   Siri, the Action Button or the Smart Stack card claims the foreground when
///   the app is next opened, because there is no earlier moment it could.
/// - **An hour is the limit.** Study sessions run longer, so an expiry that
///   arrives while the app is still frontmost claims the next hour immediately.
/// - **Crowning out ends it** (`resignedFrontmost`). That is the user leaving on
///   purpose, and it is not a thing to fight — the system would refuse anyway.
///   The app gives the foreground up until it is opened again.
///
/// Which is the same bargain the Timer makes. Stay in the app and it holds;
/// leave it deliberately and it lets go.
@MainActor
final class SessionRuntime: NSObject {
    static let shared = SessionRuntime()

    /// The runtime session being held, while one is.
    private var runtime: WKExtendedRuntimeSession?
    /// Whether a study session is live at all — running or paused.
    private var isWanted = false
    /// The user crowned out of a session this was holding. Asking straight back
    /// for the foreground they just left is both rude and futile.
    private var hasResigned = false
    /// Consecutive refusals. The system says no for reasons this side can't
    /// see, and a retry loop against a standing no is the worst thing to do to
    /// a watch battery.
    private var refusals = 0
    /// A start can land in the sliver between the scene going active and the
    /// application state following it, and a start from anywhere but `.active`
    /// is refused. One short retry covers that; three says stop asking.
    private var retry: Task<Void, Never>?

    private static let maxRefusals = 3
    private static let retryDelay: Duration = .milliseconds(750)

    private override init() { super.init() }

    /// The one entry point. Both halves are needed because neither decides
    /// anything alone: a live session is what makes the foreground worth
    /// holding, and being active is the only state it can be claimed from.
    func update(isLive: Bool, isForeground: Bool) {
        isWanted = isLive
        guard isLive else {
            // The session is over. Hand the foreground back, and clear the
            // refusals with it: the next session is a new ask, not a
            // continuation of the one the system turned down.
            hasResigned = false
            refusals = 0
            stop()
            return
        }
        // A wrist drop is not a decision, and a frontmost session survives one.
        // Only the delegate knows whether the session actually went away, so a
        // phase that isn't `.active` is a moment to do nothing in rather than a
        // reason to let go.
        guard isForeground else { return }
        // Opening the app again is the user asking for it back.
        hasResigned = false
        refusals = 0
        start()
    }

    private func start() {
        retry?.cancel()
        retry = nil
        guard isWanted, !hasResigned, refusals < Self.maxRefusals, runtime == nil else { return }
        guard WKApplication.shared().applicationState == .active else {
            scheduleRetry()
            return
        }
        let session = WKExtendedRuntimeSession()
        // The delegate has to be set before the start: a session that fails to
        // start reports it the same way one that ends does, and this is the
        // only thing listening.
        session.delegate = self
        runtime = session
        session.start()
    }

    private func stop() {
        retry?.cancel()
        retry = nil
        guard let runtime else { return }
        // Cleared first, so the invalidation this causes is recognised as ours
        // and doesn't come back round as something to recover from.
        self.runtime = nil
        runtime.invalidate()
    }

    private func scheduleRetry() {
        guard refusals < Self.maxRefusals else { return }
        refusals += 1
        retry = Task { [weak self] in
            try? await Task.sleep(for: Self.retryDelay)
            guard !Task.isCancelled else { return }
            self?.start()
        }
    }
}

extension SessionRuntime: WKExtendedRuntimeSessionDelegate {
    /// Delegate callbacks arrive on the main thread. Stated rather than hopped
    /// to, so the state below is touched in the same turn it was told about.
    nonisolated func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession) {
        MainActor.assumeIsolated { refusals = 0 }
    }

    nonisolated func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {
        // Nothing to wind down — the session's whole job is the foreground, and
        // there is only one of those to hold. The next hour is claimed once
        // this one has actually gone, below.
    }

    nonisolated func extendedRuntimeSession(
        _ session: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: (any Error)?
    ) {
        MainActor.assumeIsolated {
            guard runtime === session else { return }
            runtime = nil
            switch reason {
            case .expired:
                // An hour gone with the session still running: claim the next.
                // If the wrist is down this is refused and the app goes the way
                // of any other — the retry is bounded, and the next time the
                // app is opened picks the hold back up.
                start()
            case .resignedFrontmost:
                hasResigned = true
            case .none:
                // Ours. `stop()` has already cleared everything behind it.
                break
            default:
                // `error`, `sessionInProgress`, `suppressedBySystem`: a no from
                // the system, for a reason this side can't act on. Counted, and
                // tried once or twice more in case it was the launch race.
                scheduleRetry()
            }
        }
    }
}

extension View {
    /// Holds the app frontmost while a session is live — what makes a wrist
    /// raise mid-session land on the running clock rather than the watch face.
    func staysFrontmost(whileSessionRuns store: SessionStore) -> some View {
        modifier(FrontmostWhileLive(store: store))
    }
}

/// Takes the store rather than a `Bool` so that the read that decides happens
/// in a view body, where observation is doing the watching. Handed the answer
/// from a `Scene` body instead, the whole thing turns on whether scene bodies
/// re-run for an observable change — a bet with a silent failure behind it.
private struct FrontmostWhileLive: ViewModifier {
    let store: SessionStore
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        let isLive = store.activeSessionID != nil
        return content
            // `initial` carries as much as the change does: a session started
            // from Siri or a widget is already live by the time the app has a
            // scene to claim the foreground with.
            .onChange(of: isLive, initial: true) { _, _ in sync(isLive) }
            .onChange(of: scenePhase, initial: true) { _, _ in sync(isLive) }
    }

    // Stated rather than inherited: `ViewModifier` is `@preconcurrency`, and
    // what a conformance to it infers for the rest of the type is not something
    // worth depending on.
    @MainActor
    private func sync(_ isLive: Bool) {
        SessionRuntime.shared.update(isLive: isLive, isForeground: scenePhase == .active)
    }
}
