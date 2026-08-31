import Foundation
import WatchKit

/// The one door every sync in the app goes through.
///
/// Sync is fire-and-forget at every call site — nothing in the product is gated
/// on it and no screen reports it — so a pass that fails has nowhere to report
/// to and nobody to try it again. That is what this is for. A session that ends
/// in a lift or a tunnel used to sit unsynced until the next launch, which for
/// the last session of the night meant the next morning.
@MainActor
final class SyncScheduler {
    static let shared = SyncScheduler()
    private init() {}

    /// The pass in flight, if there is one. Coalescing rather than queueing:
    /// ending a session and then discarding it is one sync, not two.
    private var driver: Task<Void, Never>?
    /// Something changed while a pass was running or backing off, so whatever
    /// that pass sent is already out of date.
    private var pending = false

    /// Sync now, and keep trying if it fails.
    func request() {
        guard !Self.isHarness else { return }
        guard driver == nil else {
            pending = true
            return
        }
        driver = Task { [weak self] in
            await self?.drive()
            self?.driver = nil
        }
    }

    /// One pass, no ladder — the system is the retry here, and a refresh that
    /// fails books the next one. This is what a background refresh runs.
    func runBackgroundPass() async {
        guard !Self.isHarness else { return }
        if await SyncEngine.run(store: DiemContainer.store) == false {
            scheduleBackgroundRefresh()
        }
    }

    /// Half a minute, two minutes, five. Long enough that a lift or a platform
    /// is over by the second attempt, short enough that walking back into
    /// signal syncs while the app is still up.
    private static let backoff: [Duration] = [.zero, .seconds(30), .seconds(120), .seconds(300)]

    private func drive() async {
        repeat {
            pending = false
            if await attempt() == false { scheduleBackgroundRefresh() }
        } while pending
    }

    /// Returns whether any attempt got through.
    private func attempt() async -> Bool {
        for delay in Self.backoff {
            if delay > .zero {
                do { try await Task.sleep(for: delay) } catch { return false }
            }
            if await SyncEngine.run(store: DiemContainer.store) { return true }
        }
        return false
    }

    /// The last resort, and the only part of this that survives the app being
    /// closed: watchOS wakes the app for a refresh whether or not anyone is
    /// looking at it. A quarter of an hour out — the system decides when it
    /// actually fires, and asking for sooner does not make it sooner.
    private func scheduleBackgroundRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: .now + 15 * 60,
            userInfo: nil,
            scheduledCompletion: { _ in }
        )
    }

    /// The harness must never sync: the forty-seven minutes it puts on the
    /// clock never happened, and syncing is how they would land on the server
    /// as real study. Checked here rather than at each call site, so there is
    /// one door to hold shut rather than four.
    private static var isHarness: Bool {
        #if DEBUG
        LayoutHarness.isOn
        #else
        false
        #endif
    }
}
