import SwiftUI

/// Elapsed time, then a per-subject breakdown when the session had more than one
/// interval. Stays until tapped.
struct DoneView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let session: Session

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(session.isComplete ? "Complete" : "Ended")
                    .sectionLabelStyle()

                HeroNumeral(measure: Format.total(session.studiedSec))

                if session.intervalCount > 1 {
                    VStack(spacing: 4) {
                        ForEach(session.bySubject, id: \.subjectID) { entry in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(swatch(entry.subjectID))
                                    .frame(width: 6, height: 6)
                                Text(store.subject(entry.subjectID)?.name ?? "Free")
                                    .font(Typography.text(.footnote))
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(Format.duration(entry.seconds))
                                    .font(Typography.text(.footnote))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 2)
                }

                VStack(spacing: 6) {
                    GlassPill(title: "Again", systemImage: "arrow.clockwise") { again() }
                    Button("Discard", role: .destructive) { discard() }
                        .font(Typography.text(.footnote))
                    Button("Done") { dismiss() }
                        .font(Typography.text(.footnote))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 6)
        }
        .containerBackground(.black, for: .navigation)
        .onAppear {
            if session.isComplete {
                Haptics.sessionComplete()
            } else {
                Haptics.stop()
            }
        }
    }

    private func swatch(_ id: UUID?) -> AnyShapeStyle {
        guard let subject = store.subject(id) else { return AnyShapeStyle(.tertiary) }
        return AnyShapeStyle(Palette.subject(subject.colorIndex))
    }

    /// Same duration, and whatever was being studied when it ended — not
    /// whichever subject happened to take the most of the session.
    private func again() {
        let subjectID = session.lastSubjectID
        store.finished = nil
        store.start(subjectID: subjectID, plannedSec: session.plannedSec)
        Haptics.start()
        dismiss()
    }

    private func discard() {
        store.discard(sessionID: session.id)
        Haptics.sessionAbandoned()
        dismiss()
    }
}
