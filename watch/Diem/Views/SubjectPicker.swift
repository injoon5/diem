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
                Section {
                    ForEach(subjects) { subject in
                        row(name: subject.name, colorIndex: subject.colorIndex, id: subject.id)
                    }
                    row(name: "Free", colorIndex: nil, id: nil)
                }
                if subjects.isEmpty {
                    Section {
                        Text("Add subjects in Settings.")
                            .font(Typography.text(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Subject")
        }
    }

    private func row(name: String, colorIndex: Int?, id: UUID?) -> some View {
        Button {
            onPick(id)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(colorIndex == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Palette.subject(colorIndex)))
                    .frame(width: 8, height: 8)
                Text(name).font(Typography.text(.body))
                Spacer(minLength: 0)
                if id == selection {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 40)
        }
        .buttonStyle(.plain)
    }
}
