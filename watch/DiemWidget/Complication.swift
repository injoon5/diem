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
                .containerBackground(for: .widget) {
                    SmartStackCard(tint: DiemComplicationView.cardTint(for: entry.snapshot))
                }
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

    /// The colour every progress surface here is drawn in: the same copper the
    /// ring uses in the app, so the gauge on the face and the bar on the card
    /// are the app's reading rather than the system's default fill.
    ///
    /// It survives only where the system lets it. A complication is handed a
    /// rendering mode: `.fullColor` — the Smart Stack, the gallery, and faces
    /// that render complications in colour — draws exactly what is asked for,
    /// while `.accented` flattens the whole view into two groups and paints
    /// them in the *face's* tint, whatever colour was asked for. That is what
    /// `widgetAccentable()` decides: the numeral and the fill are in the
    /// accented group, the `TODAY` label and the ghost track are not. So the
    /// colour is stated once, unconditionally, and each mode takes what it can
    /// use — there is no branch here, because there is nothing to decide.
    private var progressTint: Color { Palette.ring }

    /// What the Smart Stack card is tinted with: the subject being studied, or
    /// the day's copper when nothing is running.
    ///
    /// The same rule the app's own surfaces follow — a session is the colour of
    /// its subject, free time is the absence of one — so the card in the stack
    /// and the ring on the wrist are the same session in two places. It is a
    /// `static` on the view rather than a property because the card is applied
    /// to the container, one level outside the view it belongs to.
    static func cardTint(for snapshot: DiemSnapshot) -> Color {
        guard let session = snapshot.session else { return Palette.ring }
        return Palette.subject(session.subjectColorIndex)
    }

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
            // The app's copper, so a stock gauge reads as this app's progress
            // rather than as the system's.
            .tint(progressTint)
            .widgetAccentable()

        case .accessoryCorner:
            Image(systemName: "book.fill")
                .font(.title3)
                .widgetAccentable()
                .widgetLabel {
                    Gauge(value: progress) {
                        Text(today)
                    }
                    .tint(progressTint)
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
            GoalBar(lap: snapshot.lap(asOf: now), color: progressTint)
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

/// The card the Smart Stack draws this widget on.
///
/// Clear glass rather than regular: the stack scrolls its cards over the watch
/// face, and the clear variant is the one that lets what is behind it keep
/// moving through — a card that reads as a pane over the face rather than as an
/// opaque tile sitting on top of it. Regular glass frosts that away, which on a
/// widget the size of a stamp is most of what makes the stack feel like depth
/// rather than a list.
///
/// The tint is carried at low strength on purpose. It is there to say whose
/// card this is at a glance, from the corner of the eye, before any of the text
/// is read; at full strength it would be a coloured tile with white writing on
/// it, and the numeral — the one thing on the card worth reading — would be
/// competing with its own background for contrast.
///
/// Nothing here guards against the watch face: a container background is
/// removable by default, and the face removes it. On a face the complication is
/// drawn straight onto the dial with no card at all, which is the only correct
/// answer there, so this view simply never appears.
private struct SmartStackCard: View {
    var tint: Color

    var body: some View {
        Color.clear
            .glassEffect(.clear.tint(tint.opacity(0.30)), in: .containerRelative)
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
    /// The same colour the gauges take, handed down rather than looked up, so
    /// the four families cannot end up drawing the day in two coppers.
    var color: Color = Palette.ring
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let filled = proxy.size.width * lap.fraction
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.ghostTrack)

                if lap.isLapped {
                    Capsule()
                        .fill(Palette.lapped(color))
                        .widgetAccentable()
                }

                if filled > 0 {
                    Capsule()
                        .fill(color)
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
