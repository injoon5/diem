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
                .task { await SyncEngine.run(store: store) }
                // A running session keeps the app: the wrist raise comes back
                // to the clock that is counting, not to the watch face.
                .staysFrontmost(whileSessionRuns: store)
        }
        .modelContainer(DiemContainer.shared)
        .onChange(of: scenePhase) { _, phase in
            // Only completed intervals sync, so the background is the right
            // moment: whatever just closed is ready to go.
            guard phase == .background else { return }
            Task { await SyncEngine.run(store: store) }
        }
    }
}
