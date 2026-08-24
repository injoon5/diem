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
                    await SessionAlerts.requestAuthorization()
                    await SyncEngine.run(store: store)
                }
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
