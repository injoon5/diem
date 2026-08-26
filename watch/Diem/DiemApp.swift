import SwiftUI
import SwiftData

@main
struct DiemApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = DiemContainer.store

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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .harnessed()
                .task {
                    guard !isHarness else { return }
                    SessionAlerts.install()
                    await SyncEngine.run(store: store)
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
            if phase == .active { store.refresh() }
            // Only completed intervals sync, so the background is the right
            // moment: whatever just closed is ready to go.
            guard phase == .background, !isHarness else { return }
            Task { await SyncEngine.run(store: store) }
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
