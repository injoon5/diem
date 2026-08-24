import SwiftUI
import WidgetKit

/// Every family: glanceable in under a second, legible in monochrome, no
/// live-ticking seconds.
struct TodayComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SnapshotStore.widgetKind, provider: SnapshotProvider()) { entry in
            TodayComplicationView(snapshot: entry.snapshot)
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

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: snapshot.progress) {
                Text(snapshot.compactToday)
            } currentValueLabel: {
                Text(snapshot.compactToday)
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
                    Gauge(value: snapshot.progress) {
                        Text(snapshot.compactToday)
                    }
                }

        case .accessoryRectangular:
            // Label, hero number, goal progress.
            VStack(alignment: .leading, spacing: 1) {
                Text("TODAY")
                    .font(.system(.caption2, design: .default))
                    .foregroundStyle(.secondary)
                Text(snapshot.compactToday)
                    .font(Typography.numeral(22))
                    .monospacedDigit()
                    .widgetAccentable()
                Gauge(value: snapshot.progress) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .accessoryInline:
            // No control over font or colour here — only the string is ours.
            Text(snapshot.inlineToday)

        default:
            Text(snapshot.compactToday)
        }
    }
}
