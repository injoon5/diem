import AppIntents
import SwiftUI
import WidgetKit

/// The Smart Stack card. Nothing here depends on the app being foregrounded —
/// crown out and this holds the session.
///
/// The provider claims relevance while a session is running, which is what
/// surfaces this in the stack on its own rather than only after being added by
/// hand. Points-of-interest relevance for the start card — the one at known
/// study locations — is still not wired.
struct SessionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: SnapshotStore.sessionWidgetKind,
            provider: SnapshotProvider(claimsRelevance: true)
        ) { entry in
            SessionWidgetView(snapshot: entry.snapshot, now: entry.date)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Session")
        .description("The running session, with an End button.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct SessionWidgetView: View {
    let snapshot: DiemSnapshot
    var now: Date = .now

    var body: some View {
        if let session = snapshot.session {
            HStack(alignment: .center, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.subjectName ?? "Free")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    count(for: session)
                        .font(Typography.numeral(22))
                        .monospacedDigit()
                        .widgetAccentable()
                }
                Spacer(minLength: 0)
                // The same App Intent the app runs. Sized as a target rather
                // than as a glyph: at its own size the icon is a few points
                // across on a card that also opens the app when missed.
                Button(intent: EndSessionIntent()) {
                    Image(systemName: "stop.fill")
                        .frame(width: 30, height: 30)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End session")
            }
        } else {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("TODAY").font(.caption2).foregroundStyle(.secondary)
                    Text(snapshot.compactToday(asOf: now))
                        .font(Typography.numeral(22))
                        .monospacedDigit()
                        .widgetAccentable()
                }
                Spacer(minLength: 0)
                Button(intent: StartSessionIntent()) {
                    Image(systemName: "play.fill")
                        .frame(width: 30, height: 30)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start studying")
            }
        }
    }

    /// System-rendered, so a live count costs no refresh budget.
    @ViewBuilder
    private func count(for session: DiemSnapshot.Live) -> some View {
        if session.isPaused {
            // Held where it stopped, in the shape it stopped in. This branch
            // used to show studied time while the branch above it showed time
            // remaining, so pausing a 25-minute session ten minutes in swapped
            // `15:00` for `10m` — a different number measuring a different
            // thing, in the same place on the same card.
            Text(
                Format.count(
                    remaining: session.plannedSec.map { Double($0) - session.pausedElapsedSec },
                    elapsed: session.pausedElapsedSec,
                    plannedSec: session.plannedSec
                ).value
            )
        } else if let deadline = session.deadline, deadline > now {
            Text(timerInterval: session.countingFrom...deadline, countsDown: true)
        } else if let deadline = session.deadline {
            // Past the deadline the session hasn't ended, it has rolled into
            // overtime. A countdown frozen at zero would say the opposite.
            HStack(spacing: 0) {
                Text("+")
                Text(timerInterval: deadline...deadline.addingTimeInterval(24 * 3600), countsDown: false)
            }
        } else {
            Text(
                timerInterval: session.countingFrom...session.countingFrom.addingTimeInterval(24 * 3600),
                countsDown: false
            )
        }
    }
}
