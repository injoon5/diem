import SwiftUI
import WidgetKit

/// Every family: glanceable in under a second, legible in monochrome, no
/// live-ticking seconds.
struct TodayComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SnapshotStore.widgetKind, provider: SnapshotProvider()) { entry in
            TodayComplicationView(snapshot: entry.snapshot, now: entry.date)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Study time against your daily goal.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

struct TodayComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: DiemSnapshot
    var now: Date = .now

    private var today: String { snapshot.compactToday(asOf: now) }
    private var progress: Double { snapshot.progress(asOf: now) }

    var body: some View {
        switch family {
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

        case .accessoryRectangular:
            // Label, hero number, goal progress. The one family laid out by
            // hand rather than handed to the system, so the bar is drawn the
            // way the ring is instead of as a stock capacity gauge: one thin
            // track, one fill, and a lap over the top past the goal.
            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY")
                    .font(.system(.caption2, design: .default))
                    .foregroundStyle(.secondary)
                Text(today)
                    .font(Typography.numeral(22))
                    .monospacedDigit()
                    .widgetAccentable()
                GoalBar(lap: snapshot.lap(asOf: now))
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Today")
            .accessibilityValue("\(today) of \(Format.duration(snapshot.goalSec))")

        case .accessoryInline:
            // No control over font or colour here — only the string is ours.
            Text(snapshot.inlineToday(asOf: now))

        default:
            Text(today)
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
                        .fill(Palette.ring.opacity(0.42))
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
