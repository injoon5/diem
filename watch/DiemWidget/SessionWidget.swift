import AppIntents
import SwiftUI
import WidgetKit

/// The Smart Stack card. Nothing here depends on the app being foregrounded —
/// crown out and this holds the session.
///
/// Not wired yet: the `RelevanceConfiguration` that floats this to the top of
/// the stack on session start, and points-of-interest relevance for surfacing
/// the start card at known study locations. Both want confirming against the
/// watchOS 27 SDK before being written in.
struct SessionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SnapshotStore.sessionWidgetKind, provider: SnapshotProvider()) { entry in
            SessionWidgetView(snapshot: entry.snapshot)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Session")
        .description("The running session, with an End button.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct SessionWidgetView: View {
    let snapshot: DiemSnapshot

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
                // The same App Intent the app runs.
                Button(intent: EndSessionIntent()) {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End session")
            }
        } else {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("TODAY").font(.caption2).foregroundStyle(.secondary)
                    Text(snapshot.compactToday)
                        .font(Typography.numeral(22))
                        .monospacedDigit()
                        .widgetAccentable()
                }
                Spacer(minLength: 0)
                Button(intent: StartSessionIntent()) {
                    Image(systemName: "play.fill")
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
            Text(Format.duration(session.pausedElapsedSec))
        } else if let deadline = session.deadline {
            Text(timerInterval: session.countingFrom...deadline, countsDown: true)
        } else {
            Text(
                timerInterval: session.countingFrom...session.countingFrom.addingTimeInterval(24 * 3600),
                countsDown: false
            )
        }
    }
}
