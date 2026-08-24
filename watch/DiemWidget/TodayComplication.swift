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
            // Label, hero number, goal progress.
            VStack(alignment: .leading, spacing: 1) {
                Text("TODAY")
                    .font(.system(.caption2, design: .default))
                    .foregroundStyle(.secondary)
                Text(today)
                    .font(Typography.numeral(22))
                    .monospacedDigit()
                    .widgetAccentable()
                Gauge(value: progress) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .accessoryInline:
            // No control over font or colour here — only the string is ours.
            Text(snapshot.inlineToday(asOf: now))

        default:
            Text(today)
        }
    }
}
