import SwiftUI

/// Local data, works offline. Twelve weeks gives ~12pt cells at 45mm — the full
/// year stays on the web.
struct MetricsView: View {
    @Environment(SessionStore.self) private var store

    private let now = Date.now

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
        VStack(alignment: .leading, spacing: 6) {
            Text("Today").sectionLabelStyle()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                HeroNumeral(
                    measure: Format.total(store.todaySeconds(asOf: now)),
                    size: Typography.Size.title,
                    tracking: Typography.Size.titleTracking
                )
                Text("of \(Format.duration(store.goalSeconds))")
                    .font(Typography.text(.caption2))
                    .foregroundStyle(.secondary)
            }

            let entries = store.todayBySubject(asOf: now)
            if entries.isEmpty {
                Text("Nothing yet.")
                    .font(Typography.text(.footnote))
                    .foregroundStyle(.tertiary)
            } else {
                let peak = entries.map(\.seconds).max() ?? 1
                VStack(spacing: 5) {
                    ForEach(entries, id: \.subjectID) { entry in
                        subjectRow(entry, peak: peak)
                    }
                }
            }
        }
    }

    private func subjectRow(
        _ entry: (subjectID: UUID?, seconds: TimeInterval),
        peak: TimeInterval
    ) -> some View {
        let subject = store.subject(entry.subjectID)
        let color = subject.map { Palette.subject($0.colorIndex) } ?? Color.white.opacity(0.35)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(subject?.name ?? "Free")
                    .font(Typography.text(.footnote))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(Format.duration(entry.seconds))
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
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(days, id: \.day) { entry in
                    VStack(spacing: 3) {
                        ZStack(alignment: .bottom) {
                            Capsule().fill(Palette.ghostTrack).frame(width: 8)
                            Capsule()
                                .fill(entry.seconds >= store.goalSeconds ? Palette.accent : Palette.accent.opacity(0.55))
                                .frame(width: 8, height: barHeight(entry.seconds, peak: peak))
                        }
                        .frame(height: 44)
                        Text(weekdayInitial(entry.day))
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(weekdayInitial(entry.day))
                    .accessibilityValue(Format.duration(entry.seconds))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func barHeight(_ seconds: TimeInterval, peak: TimeInterval) -> CGFloat {
        guard peak > 0, seconds > 0 else { return 0 }
        return max(3, 44 * CGFloat(min(seconds / peak, 1)))
    }

    // MARK: - Twelve weeks

    private var heatmapSection: some View {
        let weeks = heatmapWeeks()
        let peak = weeks.flatMap { $0 }.compactMap { $0 }.max() ?? 1
        return VStack(alignment: .leading, spacing: 6) {
            Text("12 Weeks").sectionLabelStyle()
            HStack(spacing: 2) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 2) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, seconds in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(cellColor(seconds, peak: peak))
                                .frame(width: 10, height: 10)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Last twelve weeks")
        }
    }

    private func cellColor(_ seconds: TimeInterval?, peak: TimeInterval) -> Color {
        guard let seconds, seconds > 0 else { return Palette.ghostTrack }
        let share = peak > 0 ? min(seconds / peak, 1) : 0
        return Palette.accent.opacity(0.25 + 0.75 * share)
    }

    // MARK: - Buckets

    private func weekDays() -> [(day: Date, seconds: TimeInterval)] {
        let calendar = Calendar.current
        let today = Day.start(of: now)
        let weekday = calendar.component(.weekday, from: today)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        guard let weekStart = calendar.date(byAdding: .day, value: -offset, to: today) else { return [] }
        let totals = Dictionary(
            uniqueKeysWithValues: store.dailySeconds(days: 14, asOf: now).map { ($0.day, $0.seconds) }
        )
        return (0..<7).compactMap { index in
            guard let day = calendar.date(byAdding: .day, value: index, to: weekStart) else { return nil }
            return (day: day, seconds: totals[day] ?? 0)
        }
    }

    /// 12 columns of 7 days, oldest week first, aligned to the week start.
    private func heatmapWeeks() -> [[TimeInterval?]] {
        let calendar = Calendar.current
        let today = Day.start(of: now)
        let weekday = calendar.component(.weekday, from: today)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        guard let thisWeekStart = calendar.date(byAdding: .day, value: -offset, to: today),
              let firstWeekStart = calendar.date(byAdding: .day, value: -7 * 11, to: thisWeekStart)
        else { return [] }

        let totals = Dictionary(
            uniqueKeysWithValues: store.dailySeconds(days: 7 * 12 + 7, asOf: now).map { ($0.day, $0.seconds) }
        )
        return (0..<12).map { week in
            (0..<7).map { day -> TimeInterval? in
                guard let date = calendar.date(byAdding: .day, value: week * 7 + day, to: firstWeekStart),
                      date <= today
                else { return nil }
                return totals[date] ?? 0
            }
        }
    }

    private func weekdayInitial(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }
}
