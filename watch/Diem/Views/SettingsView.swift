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
                            // The same spelling the screen behind this link
                            // shows. `duration` drops the padding, so the row
                            // read `2h 0m` against the numeral's `2h 00m`.
                            Text(Format.total(Settings.shared.dailyGoalSeconds).text)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Subjects") {
                    // By name here, not by recency. The store hands them back
                    // most-recently-touched first, which is right in the picker
                    // and wrong in a list you are managing: adding one put it at
                    // the far end from the button you just pressed, and renaming
                    // or recolouring one moved it out from under your thumb.
                    ForEach(store.subjects(includeArchived: true).sortedByName()) { subject in
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
            // `NameField` dismisses itself, which clears this binding — setting
            // it here as well dismissed a sheet that was already going.
            .sheet(isPresented: $addingSubject) {
                NameField(title: "New Subject", text: $newSubjectName) { name in
                    store.addSubject(name: name)
                }
            }
        }
    }
}

/// One number, scrubbed with the crown.
private struct GoalView: View {
    @Environment(SessionStore.self) private var store

    @State private var step: Double
    @FocusState private var crownFocused: Bool
    /// Waits for the crown to settle before telling the widgets.
    @State private var republish: Task<Void, Never>?

    /// Seeded at init, not in `onAppear`. Assigning the stored goal after the
    /// first render would register as a crown movement and fire a detent the
    /// user never made.
    init(minutes: Int) {
        _step = State(initialValue: Double(GoalScrub.step(forMinutes: minutes)))
    }

    private var minutes: Int { GoalScrub.minutes(forStep: Int(step.rounded())) }

    var body: some View {
        VStack(spacing: 2) {
            Spacer(minLength: 0)
            // Title, not hero: this screen carries a navigation bar, and
            // `12h 45m` at display size would run into both edges.
            HeroNumeral(
                measure: Format.total(Double(minutes) * 60),
                size: Typography.Size.title,
                tracking: Typography.Size.titleTracking
            )
            // Sits directly under the numeral and one step quieter than a
            // section header — it labels the number, it is not a heading.
            Text("per day")
                .sectionLabelStyle(.tertiary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.black, for: .navigation)
        .focusable(true)
        .focused($crownFocused)
        // No `by:` stride, the same finding the duration crown already
        // carries: a detented binding hands back whole steps on its own, and
        // the stride on top of that is what made this one feel notched twice.
        // The value comes back continuous and the *reading* is rounded.
        .digitalCrownRotation(
            $step,
            from: Double(GoalScrub.minStep),
            through: Double(GoalScrub.maxStep),
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: false
        )
        .onChange(of: Int(step.rounded())) { old, new in
            guard old != new else { return }
            Haptics.crownDetent()
            Settings.shared.dailyGoalMinutes = GoalScrub.minutes(forStep: new)
            // The goal is half of every gauge the widgets draw, and it lives
            // outside the interval log that normally triggers a republish — but
            // a detent is not a decision. One pass of the crown is forty-seven
            // of them, and republishing each one writes the snapshot file and
            // wakes `chronod` forty-seven times for a number the user is still
            // choosing. The ring on this screen reads the setting directly, so
            // nothing on screen waits for this.
            republish?.cancel()
            republish = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                store.refreshSnapshot()
            }
        }
        .onAppear { crownFocused = true }
        // Leaving early is a settled crown too. Publishing twice is free — an
        // unchanged snapshot is never written.
        .onDisappear {
            republish?.cancel()
            store.refreshSnapshot()
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

    /// Sized to the target, not to the swatch: what the eye reads is a 24pt
    /// circle, what the thumb gets is the whole cell.
    private let columns = [GridItem(.adaptive(minimum: 34), spacing: 4)]

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

            // A ten-swatch grid is not a list row. Inside one it kept the
            // row's inset and rounded fill, which boxed the swatches into a
            // pill and left them a couple of points from the edges of it; the
            // grid takes the width of the screen instead.
            Section("Color") {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(0..<Palette.subjectCount, id: \.self) { index in
                        Button {
                            store.update(subject, colorIndex: index)
                            Haptics.crownDetent()
                        } label: {
                            Circle()
                                .fill(Palette.subjects[index])
                                .frame(width: 24, height: 24)
                                .overlay {
                                    if subject.colorIndex == index {
                                        // Around the swatch rather than on its
                                        // rim: a 2pt stroke on a 24pt circle
                                        // eats an eighth of the colour it is
                                        // meant to be marking.
                                        Circle()
                                            .stroke(.white, lineWidth: 2)
                                            .padding(-3)
                                    }
                                }
                                .frame(width: 34, height: 34)
                                .contentShape(.circle)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                .listRowBackground(Color.clear)
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
            }
        }
    }
}

private struct NameField: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    @Binding var text: String
    var onCommit: (String) -> Void

    /// The sheet exists to be typed into. Without this it opens on an empty
    /// field with Save disabled and nothing focused, so the first tap does
    /// nothing but reach the control the sheet was opened for.
    @FocusState private var typing: Bool

    var body: some View {
        // Presented as a bare sheet, the title had nothing to draw in — so the
        // one thing that says whether this is a new subject or a rename never
        // appeared.
        NavigationStack {
            VStack(spacing: 8) {
                TextField(title, text: $text)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($typing)
                    .onSubmit(commit)
                Button("Save", action: commit)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 8)
            .navigationTitle(title)
            .onAppear { typing = true }
        }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onCommit(trimmed)
        dismiss()
    }
}
