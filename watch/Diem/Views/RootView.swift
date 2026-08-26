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
                .harnessDimmed()
            }
            // Said once, at the top, over whatever is below it. A store that
            // could not be opened leaves the app running on memory: it comes up
            // with no subjects and no history, which is indistinguishable from
            // a fresh install right up until the day's work disappears at quit.
            // Falling back was the right call; falling back quietly was not.
            // The private on-disk store is the milder version of the same
            // thing: the day is kept, the complication is the part that stops.
            // An overlay, not a safe-area inset. An inset takes its height out
            // of the screen below it, and the screen below it is a ring sized
            // to the space it is given — so saying anything up here quietly
            // shrank the ring, and the same session drew at two diameters
            // depending on how the store had opened. The banner carries its own
            // ground for exactly this reason: it can sit over the arc.
            .overlay(alignment: .top) {
                switch DiemContainer.storage {
                case .group:
                    EmptyView()
                case .local:
                    // The day is safe; only the shared half is not. Said in the
                    // same place and quieter, because nothing is being lost.
                    StatusBanner(
                        // Short enough to set on one line at full size. The
                        // long spelling of this truncated at "not updati…",
                        // and a truncated warning is worse than a terse one.
                        "Complication stale",
                        urgent: false,
                        spoken: "Diem is saving, but cannot reach the shared container, "
                            + "so the complication is not updating."
                    )
                case .memory:
                    StatusBanner(
                        // The app's own name, on its own screen, was the word
                        // that pushed this past the width of the pill.
                        "Not saving — reopen",
                        urgent: true,
                        spoken: "Diem could not open its history and is not saving. "
                            + "Reopen the app."
                    )
                }
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

/// What the app says when it is running on less than it should be.
///
/// One view for both, because they are the same sentence at two volumes and
/// they were drifting apart as two copies of five modifiers.
///
/// **A sentence, set as one.** These used to take `sectionLabelStyle` —
/// uppercase, tracked, the style the app uses for `PAUSED` and for the section
/// headings that are one or two words. Twenty-five characters of tracked
/// uppercase is half again as wide as the same words in sentence case, so it
/// took a `minimumScaleFactor` of 0.7 to fit, and a tracked caption at seventy
/// percent is not small type but a smudge. Given two lines to wrap into
/// instead, it pushed the whole Running screen down until the ring closed over
/// the clock. Sentence case fits on one line at full size, which is the only
/// version of this that is both legible and out of the way.
///
/// **On a ground of its own.** The Running screen deliberately draws its ring
/// fourteen points past its own bounds to reach the bezel, so a bare line of
/// text here has an arc running through it — which is where a message about
/// losing data is least legible. The capsule is invisible against the black it
/// usually sits on and shows up exactly where something is passing behind.
///
/// **The urgent one is a filled pill, not orange words.** The accent is never
/// on text anywhere else in this app, and a warning is the last place to make
/// the exception: orange type on black is the weakest way to draw the colour
/// and the loudest way to break the rule. Filled, it is the same pill the
/// Start button is.
private struct StatusBanner: View {
    private let message: String
    private let urgent: Bool
    private let spoken: String

    init(_ message: String, urgent: Bool, spoken: String) {
        self.message = message
        self.urgent = urgent
        self.spoken = spoken
    }

    var body: some View {
        Text(message)
            .font(Typography.text(.caption))
            .foregroundStyle(urgent ? AnyShapeStyle(.black) : AnyShapeStyle(.secondary))
            // One line. Wrapping is what took the height that the screen below
            // needs, and a caption has room for this sentence without it.
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                urgent ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(.black.opacity(0.85)),
                in: .capsule
            )
            .padding(.horizontal, 8)
            .accessibilityLabel(spoken)
    }
}
