import SwiftUI

/// While a session is live the root *is* the Running screen — reopening
/// mid-session lands there directly, with no Start screen behind it.
struct RootView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if store.activeSessionID != nil {
                    RunningView()
                } else {
                    StartView()
                }
            }
        }
        .fullScreenCover(item: finishedBinding) { session in
            DoneView(session: session)
        }
        .tint(Palette.accent)
    }

    private var finishedBinding: Binding<Session?> {
        Binding(get: { store.finished }, set: { store.finished = $0 })
    }
}
