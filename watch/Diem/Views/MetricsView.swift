import SwiftUI

/// Local data, works offline. Twelve weeks gives ~12pt cells at 45mm — the full
/// year stays on the web.
struct MetricsView: View {
    @Environment(SessionStore.self) private var store

    private let now = Date.now

    /// Twelve weeks plus the alignment week. Both charts read the same window
    /// so the store aggregates the log once and hands the second one the same
    /// answer, instead of walking a quarter of a year twice per layout.
    private static let window = 7 * 12 + 7

    private struct HeatmapCell: Identifiable {
        let id: Date
        let seconds: TimeInterval?
    }

    private struct HeatmapWeek: Identifiable {
        let id: Date
        let days: [HeatmapCell]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    todaySection
                    weekSection
                    heatmapSection
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }
            .containerBackground(.black, for: .navigation)
            .navigationTitle("Metrics")
        }
    }

    // MARK: - Today

    private var todaySection: some View {
        let streak = store.streak(asOf: now)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Today").sectionLabelStyle()
                Spacer(minLength: 4)
                // The thing a study app has that a timer cannot: not what you
                // did today, but that you have kept doing it. One day is not a
                // streak — it is today, which the number below already says.
                if streak > 1 {
                    Text("\(streak) day streak")
                        .sectionLabelStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HeroNumeral(
                    measure: Format.total(store.todaySeconds(asOf: now)),
                    size: Typography.Size.title,
                    tracking: Typography.Size.titleTracking
                )
                // Wide enough to stay a separate phrase: at a tighter gap the
                // unit and the goal ran together into `m of 2h 0m`. Same
                // spelling as the numeral it sits against, too — `duration`
                // drops the padding and put `1h 05m of 2h 0m` on one line.
                Text("of \(Format.total(store.goalSeconds).text)")
                    .font(Typography.text(.caption2))
                    .foregroundStyle(.tertiary)
            }

            let entries = store.todayBySubject(asOf: now)
            if entries.isEmpty {
                Text("Nothing yet.")
                    .font(Typography.text(.footnote))
                    .foregroundStyle(.tertiary)
            } else {
                let peak = entries.map(\.seconds).max() ?? 1
                VStack(spacing: 5) {
                    ForEach(entries) { entry in
                        subjectRow(entry, peak: peak)
                    }
                }
            }
        }
    }

    private func subjectRow(_ entry: SubjectTotal, peak: TimeInterval) -> some View {
        let subject = store.subject(entry.subjectID)
        let color = Palette.subject(subject?.colorIndex)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(subject?.name ?? "Free")
                    .font(Typography.text(.footnote))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(Format.total(entry.seconds).text)
                    .font(Typography.text(.caption2))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(color)
                    .frame(width: max(2, proxy.size.width * (peak > 0 ? entry.seconds / peak : 0)))
            }
            .frame(height: 3)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - This week

    private var weekSection: some View {
        let days = weekDays()
        let peak = max(days.map(\.seconds).max() ?? 0, store.goalSeconds)
        return VStack(alignment: .leading, spacing: 6) {
            Text("This Week").sectionLabelStyle()
            GeometryReader { proxy in
                let spacing: CGFloat = 5
                // Capped, and centred in whatever is left over. Seven bars
                // stretched across the full width read as blocks rather than
                // as a chart.
                let barWidth = min(14, max(8, (proxy.size.width - spacing * 6) / 7))
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(days, id: \.day) { entry in
                        // Formatted once: the same string labels the bar and
                        // speaks it, and a `DateFormatter` is not free.
                        let initial = weekdayInitial(entry.day)
                        VStack(spacing: 3) {
                            ZStack(alignment: .bottom) {
                                Capsule()
                                    .fill(Palette.ghostTrack)
                                Capsule()
                                    .fill(
                                        entry.seconds >= store.goalSeconds
                                            ? Palette.ring
                                            : Palette.ring.opacity(0.68)
                                    )
                                    .frame(height: barHeight(entry.seconds, peak: peak))
                            }
                            .frame(width: barWidth, height: 44)
                            .clipShape(.capsule)
                            .overlay {
                                Capsule()
                                    .stroke(.white.opacity(0.04), lineWidth: 1)
                            }
                            Text(initial)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(initial)
                        .accessibilityValue(Format.duration(entry.seconds))
                    }
                }
            }
            .frame(height: 58)
        }
    }

    private func barHeight(_ seconds: TimeInterval, peak: TimeInterval) -> CGFloat {
        guard peak > 0, seconds > 0 else { return 0 }
        return max(4, 44 * CGFloat(min(seconds / peak, 1)))
    }

    // MARK: - Twelve weeks

    private var heatmapSection: some View {
        let weeks = heatmapWeeks()
        let peak = weeks.flatMap(\.days).compactMap(\.seconds).max() ?? 1
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 12)
        return VStack(alignment: .leading, spacing: 6) {
            Text("12 Weeks").sectionLabelStyle()
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<7, id: \.self) { day in
                    ForEach(weeks, id: \.id) { week in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(cellColor(week.days[day].seconds, peak: peak))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Last twelve weeks")
        }
    }

    private func cellColor(_ seconds: TimeInterval?, peak: TimeInterval) -> Color {
        guard let seconds, seconds > 0 else { return Palette.ghostTrack }
        let share = peak > 0 ? min(seconds / peak, 1) : 0
        // The ring's copper, not the Action Button orange. Both charts on this
        // screen measure the same thing, and they were measuring it in two
        // different oranges — with the heatmap using the one the palette
        // reserves for actions.
        return Palette.ring.opacity(0.25 + 0.75 * share)
    }

    // MARK: - Buckets

    /// The start of the week containing a study-day, honouring wherever the
    /// locale puts its first weekday.
    private func weekStart(of day: Date, in calendar: Calendar) -> Date? {
        let weekday = calendar.component(.weekday, from: day)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day)
    }

    private func weekDays() -> [(day: Date, seconds: TimeInterval)] {
        let calendar = Calendar.current
        let today = Day.start(of: now)
        guard let weekStart = weekStart(of: today, in: calendar) else { return [] }
        let totals = Dictionary(
            uniqueKeysWithValues: store.dailySeconds(days: Self.window, asOf: now).map { ($0.day, $0.seconds) }
        )
        return (0..<7).compactMap { index in
            guard let day = calendar.date(byAdding: .day, value: index, to: weekStart) else { return nil }
            return (day: day, seconds: totals[day] ?? 0)
        }
    }

    /// 12 columns of 7 days, oldest week first, aligned to the week start.
    private func heatmapWeeks() -> [HeatmapWeek] {
        let calendar = Calendar.current
        let today = Day.start(of: now)
        guard let thisWeekStart = weekStart(of: today, in: calendar),
              let firstWeekStart = calendar.date(byAdding: .day, value: -7 * 11, to: thisWeekStart)
        else { return [] }

        let totals = Dictionary(
            uniqueKeysWithValues: store.dailySeconds(days: Self.window, asOf: now).map { ($0.day, $0.seconds) }
        )
        return (0..<12).compactMap { week in
            guard let weekDate = calendar.date(byAdding: .day, value: week * 7, to: firstWeekStart) else {
                return nil
            }
            let days = (0..<7).compactMap { day -> HeatmapCell? in
                guard let date = calendar.date(byAdding: .day, value: week * 7 + day, to: firstWeekStart) else {
                    return nil
                }
                return HeatmapCell(id: date, seconds: date <= today ? (totals[date] ?? 0) : nil)
            }
            // The grid indexes every week by weekday, so a short one would be
            // a crash rather than a gap. Calendar arithmetic doesn't fail in
            // practice; a chart is not the place to find out it can.
            guard days.count == 7 else { return nil }
            return HeatmapWeek(id: weekDate, days: days)
        }
    }

    /// One formatter, not one per cell per redraw.
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter
    }()

    private func weekdayInitial(_ date: Date) -> String {
        Self.weekdayFormatter.string(from: date)
    }
}
