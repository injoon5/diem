import SwiftUI

/// A local list. Picking the subject already running is a no-op upstream, so
/// the count never breaks.
struct SubjectPicker: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var selection: UUID?
    var onPick: (UUID?) -> Void

    var body: some View {
        let subjects = store.subjects()
        // Its own stack, the way `SettingsView` and `MetricsView` carry theirs.
        // Presented as a bare sheet the title below has nothing to draw in, so
        // the picker arrived unlabelled.
        NavigationStack {
            List {
                // A footer, not a second section: the hint is a note about
                // the list, and in a section of its own it drew as a row —
                // inset, filled, and looking like something to tap.
                Section {
                    ForEach(subjects) { subject in
                        row(name: subject.name, colorIndex: subject.colorIndex, id: subject.id)
                    }
                    row(name: "Free", colorIndex: nil, id: nil)
                } footer: {
                    if subjects.isEmpty {
                        Text("Add subjects in Settings.")
                    }
                }
            }
            .navigationTitle("Subject")
        }
    }

    private func row(name: String, colorIndex: Int?, id: UUID?) -> some View {
        let isSelected = id == selection
        return Button {
            onPick(id)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(Palette.subject(colorIndex))
                    .frame(width: 8, height: 8)
                Text(name).font(Typography.text(.body))
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            // 44, not 40. The rest of the app is careful about this — every
            // circle control is 44 and the subject button pads itself to 44 —
            // and this list was the one place under it.
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // The checkmark is decorative, so which subject is currently chosen was
        // sighted-only. Spoken as a trait rather than as more label text, so
        // VoiceOver announces it the way it announces every other selection.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
