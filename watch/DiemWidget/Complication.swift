import AppIntents
import SwiftUI
import WidgetKit

/// One card for the day: the total while nothing is running, the session while
/// something is.
///
/// This was two widgets — a Today complication and a Session card for the Smart
/// Stack — which is two entries in the gallery, two things to install, and a
/// stack that could hold both at once: one card reading `1h 30m` and the card
/// under it counting the session that half of it came from. They read the same
/// snapshot and answer the same question, so they are one card, and which
/// reading it shows is the session's business rather than the user's.
///
/// Every family: glanceable in under a second, legible in monochrome, and no
/// live-ticking seconds anywhere the day's total is what's being shown.
struct DiemComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SnapshotStore.widgetKind, provider: SnapshotProvider()) { entry in
            DiemComplicationView(snapshot: entry.snapshot, now: entry.date)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Study time against your daily goal, and the session while one runs.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

struct DiemComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: DiemSnapshot
    var now: Date = .now

    private var today: String { snapshot.compactToday(asOf: now) }
    private var progress: Double { snapshot.progress(asOf: now) }

    var body: some View {
        switch family {
        // The small families stay on the day's total whatever is running,
        // because the total already counts it: a session in its tenth minute is
        // ten minutes of the number on the face. Four characters and a gauge
        // have room for one reading, and the one that survives being glanced at
        // is the one that answers "how much have I done today".
        case .accessoryCircular:
            Gauge(value: progress) {
                Text(today)
            } currentValueLabel: {
                Text(today)
                    .font(Typography.numeral(15))
                    .monospacedDigit()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()

        case .accessoryCorner:
            Image(systemName: "book.fill")
                .font(.title3)
                .widgetAccentable()
                .widgetLabel {
                    Gauge(value: progress) {
                        Text(today)
                    }
                }

        // The one family with room for two things at once, and the one the
        // Smart Stack shows — so this is where the card switches. Laid out by
        // hand rather than handed to the system, so the goal bar is drawn the
        // way the ring is instead of as a stock capacity gauge: one thin track,
        // one fill, and a lap over the top past the goal.
        //
        // The bar stays under both readings. It is the day either way, and a
        // card that kept it for one state and dropped it for the other would
        // change shape every time a session started.
        case .accessoryRectangular:
            // The reading takes the width it is given and the button takes
            // the 30 points it asks for, so the two states hang their control
            // off the same edge. The intents are the ones the app runs, sized
            // as targets rather than as glyphs: at its own size the icon is a
            // few points across on a card that also opens the app when missed.
            HStack(alignment: .center, spacing: 6) {
                if let session = snapshot.session {
                    running(session)
                    button(intent: EndSessionIntent(), icon: "stop.fill", label: "End session")
                } else {
                    total
                    button(intent: StartSessionIntent(), icon: "play.fill", label: "Start studying")
                }
            }

        case .accessoryInline:
            // No control over font or colour here — only the string is ours.
            Text(snapshot.inlineToday(asOf: now))

        default:
            Text(today)
        }
    }

    /// The day, banked and running together.
    private var total: some View {
        column {
            Text("TODAY")
                .font(.system(.caption2, design: .default))
                .foregroundStyle(.secondary)
            // `compactToday` exists because a circular complication fits four
            // characters; spending that thrift here left the card saying `1.5h`
            // for a total the app was calling `1h 30m`.
            Text(Format.total(snapshot.today(asOf: now)).text)
                .font(Typography.numeral(22))
                .monospacedDigit()
                .widgetAccentable()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today")
        .accessibilityValue(
            "\(Format.duration(snapshot.today(asOf: now))) of \(Format.duration(snapshot.goalSec))"
        )
    }

    /// The session, over the same day it is filling in.
    private func running(_ session: DiemSnapshot.Live) -> some View {
        column {
            Text(session.subjectName ?? "Free")
                // The same face the `TODAY` label uses: it is the same line of
                // the same card, and only the word in it changes.
                .font(.system(.caption2, design: .default))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            count(for: session)
                .font(Typography.numeral(22))
                .monospacedDigit()
                .widgetAccentable()
        }
        .accessibilityElement(children: .combine)
    }

    /// Label, hero number, goal bar — the shape both readings are poured into.
    private func column(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            content()
            GoalBar(lap: snapshot.lap(asOf: now))
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func button(intent: some AppIntent, icon: String, label: String) -> some View {
        Button(intent: intent) {
            Image(systemName: icon)
                .frame(width: 30, height: 30)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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

/// The goal bar: the ring's reading in a straight line.
///
/// A stock `accessoryLinearCapacity` gauge is a chunky full-height bar with no
/// notion of going past full — at 100% and at 200% it draws the same thing.
/// This is the ring's vocabulary instead. The ghost track is always the full
/// width, the fill runs over it, and past the goal the completed pass stays
/// behind at the same dimmed strength the ring uses while the overflow runs
/// over the top.
private struct GoalBar: View {
    let lap: Lap
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let filled = proxy.size.width * lap.fraction
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.ghostTrack)

                if lap.isLapped {
                    Capsule()
                        .fill(Palette.lapped(Palette.ring))
                        .widgetAccentable()
                }

                if filled > 0 {
                    Capsule()
                        .fill(Palette.ring)
                        // Never thinner than it is tall: a capsule narrower
                        // than its own cap radius draws as a sliver rather
                        // than as the round end the ring has.
                        .frame(width: max(height, filled))
                        .widgetAccentable()
                }
            }
        }
        .frame(height: height)
    }
}
