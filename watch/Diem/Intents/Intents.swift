import AppIntents
import Foundation
import SwiftData
import WatchKit

/// Subjects, as Siri and Shortcuts see them.
struct SubjectEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Subject")
    static let defaultQuery = SubjectQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct SubjectQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [SubjectEntity] {
        let wanted = Set(identifiers)
        return DiemContainer.store.subjects()
            .filter { wanted.contains($0.id) }
            .map { SubjectEntity(id: $0.id, name: $0.name) }
    }

    @MainActor
    func suggestedEntities() async throws -> [SubjectEntity] {
        DiemContainer.store.subjects().map { SubjectEntity(id: $0.id, name: $0.name) }
    }
}

/// Built before any surface that depends on it — Siri, Shortcuts, the Control on
/// the Action Button and the widget buttons all run these.
struct StartSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Studying"
    static let description = IntentDescription("Start a study session, timed or open-ended.")
    static let openAppWhenRun = false

    @Parameter(title: "Subject")
    var subject: SubjectEntity?

    @Parameter(title: "Duration", defaultUnit: .minutes)
    var duration: Measurement<UnitDuration>?

    static var parameterSummary: some ParameterSummary {
        Summary("Study \(\.$subject) for \(\.$duration)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = DiemContainer.store
        let seconds = duration.map { Int($0.converted(to: .seconds).value) }
        store.start(subjectID: subject?.id, plannedSec: seconds.flatMap { $0 > 0 ? $0 : nil })
        Haptics.start()

        let name = subject?.name
        let dialog: IntentDialog = switch (name, seconds) {
        case let (name?, seconds?): "Studying \(name) for \(Format.duration(Double(seconds)))."
        case let (name?, nil): "Studying \(name)."
        case let (nil, seconds?): "Studying for \(Format.duration(Double(seconds)))."
        default: "Studying."
        }
        return .result(dialog: dialog)
    }
}

struct PauseSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Studying"
    static let description = IntentDescription("Pause or resume the current session.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = DiemContainer.store
        guard store.activeSessionID != nil else { return .result(dialog: "Nothing is running.") }
        if store.isPaused {
            store.resume()
            return .result(dialog: "Resumed.")
        }
        store.pause()
        return .result(dialog: "Paused.")
    }
}

struct EndSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "End Studying"
    static let description = IntentDescription("End the current session.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = DiemContainer.store
        guard store.activeSessionID != nil else { return .result(dialog: "Nothing is running.") }
        // Ending from Siri or a widget must not leave a Done screen queued for
        // whenever the app is next opened. Ending from the Smart Stack card
        // with the app already on screen behind it is a different thing: that
        // ends the session the user is looking at, and it should land on the
        // summary like any other end.
        guard let session = store.end(presentingDone: Self.appIsOnScreen) else {
            Haptics.sessionAbandoned()
            return .result(dialog: "Too short to keep.")
        }
        Haptics.sessionComplete()
        return .result(dialog: "\(Format.duration(session.studiedSec)) studied.")
    }

    /// Whether this is the app, foregrounded — not the widget extension, which
    /// runs the same intent in its own process and has no screen to land on.
    @MainActor
    private static var appIsOnScreen: Bool {
        guard Bundle.main.bundleURL.pathExtension != "appex" else { return false }
        return WKApplication.shared().applicationState == .active
    }
}

struct DiemShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSessionIntent(),
            phrases: [
                "Start studying in \(.applicationName)",
                "Study with \(.applicationName)",
            ],
            shortTitle: "Start Studying",
            systemImageName: "book"
        )
        AppShortcut(
            intent: EndSessionIntent(),
            phrases: ["Stop studying in \(.applicationName)"],
            shortTitle: "End Studying",
            systemImageName: "stop.fill"
        )
    }
}
