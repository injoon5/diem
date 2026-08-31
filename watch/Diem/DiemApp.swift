import SwiftUI
import SwiftData
import WatchKit

@main
struct DiemApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = DiemContainer.store
    /// Only so that a background refresh has somewhere to land.
    @WKApplicationDelegateAdaptor(DiemAppDelegate.self) private var delegate

    /// The layout harness is a screen to look at, and nothing more. It must not
    /// ask for notification permission — a dialog is what the screen under it
    /// would otherwise be photographed through — and it must never sync: the
    /// session it puts on the clock never happened, and syncing is how a made-up
    /// forty-seven minutes would end up on the server as real study.
    private var isHarness: Bool {
        #if DEBUG
        LayoutHarness.isOn
        #else
        false
        #endif
    }

    /// Cheap enough to ask on every activation: a one-row fetch and a defaults
    /// read, and no network. `limit: 1` because this is a yes or no — the
    /// default of two hundred is for the pass that has to send them.
    private var hasUnsyncedWork: Bool {
        !store.unsyncedIntervals(limit: 1).isEmpty || !Settings.shared.deletedIntervalIDs.isEmpty
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .harnessed()
                .task {
                    guard !isHarness else { return }
                    SessionAlerts.install()
                    SyncScheduler.shared.request()
                }
                // A running session keeps the app: the wrist raise comes back
                // to the clock that is counting, not to the watch face.
                .staysFrontmost(whileSessionRuns: store)
        }
        .modelContainer(DiemContainer.shared)
        .onChange(of: scenePhase) { _, phase in
            // Coming back is the moment to stop trusting what this process
            // remembers. A session started or ended from the Smart Stack card,
            // Siri or the Action Button was written by another process, and
            // nothing arrives from that side — the app used to come back to a
            // stopped clock labelled "Paused" for a session that had ended.
            if phase == .active {
                store.refresh()
                // A session ended from the Smart Stack card, Siri or the Action
                // Button was written by a process with no sync layer in it at
                // all, so coming back is the first chance anything has to send
                // it. Only when there is something to send: an ordinary wrist
                // raise into the app should not cost a round trip.
                if hasUnsyncedWork { SyncScheduler.shared.request() }
            }
            // Backgrounding closes nothing by itself, but whatever the last
            // screen closed is ready to go by now.
            guard phase == .background else { return }
            SyncScheduler.shared.request()
        }
    }
}

/// The app has no need of a delegate beyond this: watchOS hands a scheduled
/// background refresh to one, and there is nowhere else to receive it.
final class DiemAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            guard let refresh = task as? WKApplicationRefreshBackgroundTask else {
                // Snapshot and connectivity tasks land here too, and holding
                // one open is how an app gets its background time taken away.
                task.setTaskCompletedWithSnapshot(false)
                continue
            }
            Task { @MainActor in
                await SyncScheduler.shared.runBackgroundPass()
                refresh.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}

private extension View {
    /// Debug builds launched with `-DiemHarness` come up on a screen that would
    /// otherwise take three quarters of an hour to reach. Nothing here is
    /// compiled into a release, and nothing happens without the argument.
    @ViewBuilder
    func harnessed() -> some View {
        #if DEBUG
        if LayoutHarness.showsNumeral {
            NumeralHarness()
        } else {
            self
            .overlay { if LayoutHarness.showsCentreLine { CentreLine() } }
            .task {
                LayoutHarness.announce()
                LayoutHarness.seed(DiemContainer.store)
            }
        }
        #else
        self
        #endif
    }
}
