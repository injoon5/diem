import SwiftUI
import SwiftData

@main
struct DiemApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = DiemContainer.store

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task {
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
            guard phase == .background else { return }
            Task { await SyncEngine.run(store: store) }
        }
    }
}
