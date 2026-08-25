import SwiftUI

/// While a session is live the root *is* the Running screen — reopening
/// mid-session lands there directly, with no Start screen behind it.
///
/// All three screens are one navigation root rather than a screen plus a cover.
/// A cover animates in over whatever the root has already switched to, so
/// ending a session used to show a frame of the Start screen sliding under the
/// summary. One place decides what is on screen, and the change is a crossfade.
struct RootView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Screen: Equatable {
        case start
        case running
        case done(Session)

        var id: String {
            switch self {
            case .start: "start"
            case .running: "running"
            case .done(let session): "done-\(session.id)"
            }
        }
    }

    private var screen: Screen {
        if let finished = store.finished { return .done(finished) }
        return store.activeSessionID != nil ? .running : .start
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // The black belongs to the container, not to each screen, so
                // nothing shows through during the crossfade.
                Color.black.ignoresSafeArea()

                Group {
                    switch screen {
                    case .start:
                        StartView()
                    case .running:
                        RunningView()
                    case .done(let session):
                        DoneView(session: session) { store.finished = nil }
                    }
                }
                .id(screen.id)
                .transition(.opacity)
            }
            .containerBackground(.black, for: .navigation)
            // Scoped to this one value: everything below — the ring tracking
            // the crown above all — has to stay free of an inherited animation.
            .animation(Motion.screen(reduceMotion: reduceMotion), value: screen.id)
        }
        // No app-wide tint: the accent belongs to the ring and the pill fill,
        // never to text. Everything else is primary or secondary on black, so
        // the display edge disappears into the bezel.
    }
}
