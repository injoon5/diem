import SwiftUI

/// The subject list, and one number.
struct SettingsView: View {
    @Environment(SessionStore.self) private var store

    @State private var newSubjectName = ""
    @State private var addingSubject = false

    var body: some View {
        NavigationStack {
            List {
                Section("Goal") {
                    NavigationLink {
                        GoalView(minutes: Settings.shared.dailyGoalMinutes)
                    } label: {
                        HStack {
                            Text("Daily")
                            Spacer()
                            Text(Format.duration(Settings.shared.dailyGoalSeconds))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Subjects") {
                    // Most-recent-first.
                    ForEach(store.subjects(includeArchived: true)) { subject in
                        NavigationLink {
                            SubjectEditor(subject: subject)
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Palette.subject(subject.colorIndex))
                                    .frame(width: 8, height: 8)
                                    .opacity(subject.archived ? 0.4 : 1)
                                Text(subject.name)
                                    .lineLimit(1)
                                    .foregroundStyle(
                                        subject.archived
                                            ? AnyShapeStyle(.secondary)
                                            : AnyShapeStyle(.primary)
                                    )
                                if subject.archived {
                                    Spacer(minLength: 4)
                                    Image(systemName: "archivebox")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }

                    Button {
                        newSubjectName = ""
                        addingSubject = true
                    } label: {
                        Label("Add Subject", systemImage: "plus")
                    }
                }

                Section {
                    NavigationLink("Pair with Web") { PairingView() }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $addingSubject) {
                NameField(title: "New Subject", text: $newSubjectName) { name in
                    store.addSubject(name: name)
                    addingSubject = false
                }
            }
        }
    }
}

/// One number, scrubbed with the crown.
private struct GoalView: View {
    @State private var step: Double

    /// Seeded at init, not in `onAppear`. Assigning the stored goal after the
    /// first render would register as a crown movement and fire a detent the
    /// user never made.
    init(minutes: Int) {
        _step = State(initialValue: Double(GoalScrub.step(forMinutes: minutes)))
    }

    private var minutes: Int { GoalScrub.minutes(forStep: Int(step.rounded())) }

    var body: some View {
        VStack(spacing: 6) {
            HeroNumeral(measure: Format.total(Double(minutes) * 60))
            Text("per day").sectionLabelStyle()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .digitalCrownRotation(
            $step,
            from: Double(GoalScrub.minStep),
            through: Double(GoalScrub.maxStep),
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: false
        )
        .onChange(of: Int(step.rounded())) { old, new in
            guard old != new else { return }
            Haptics.crownDetent()
            Settings.shared.dailyGoalMinutes = GoalScrub.minutes(forStep: new)
        }
        .navigationTitle("Goal")
    }
}

private struct SubjectEditor: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let subject: Subject
    @State private var renaming = false
    @State private var draftName = ""

    private let columns = [GridItem(.adaptive(minimum: 26), spacing: 8)]

    var body: some View {
        List {
            Section {
                Button {
                    draftName = subject.name
                    renaming = true
                } label: {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(subject.name).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }

            Section("Color") {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<Palette.subjectCount, id: \.self) { index in
                        Button {
                            store.update(subject, colorIndex: index)
                            Haptics.crownDetent()
                        } label: {
                            Circle()
                                .fill(Palette.subjects[index])
                                .frame(width: 22, height: 22)
                                .overlay {
                                    if subject.colorIndex == index {
                                        Circle().stroke(.white, lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            Section {
                Button(subject.archived ? "Unarchive" : "Archive") {
                    store.update(subject, archived: !subject.archived)
                }
                Button("Delete", role: .destructive) {
                    store.delete(subject)
                    dismiss()
                }
            } footer: {
                Text("Archiving hides a subject from the picker and keeps its history.")
            }
        }
        .navigationTitle(subject.name)
        .sheet(isPresented: $renaming) {
            NameField(title: "Rename", text: $draftName) { name in
                store.update(subject, name: name)
                renaming = false
            }
        }
    }
}

private struct NameField: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    @Binding var text: String
    var onCommit: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            TextField(title, text: $text)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit(commit)
            Button("Save", action: commit)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 8)
        .navigationTitle(title)
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onCommit(trimmed)
        dismiss()
    }
}
