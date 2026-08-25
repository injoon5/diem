import Foundation
import SwiftData

/// The schema, versioned from the start.
///
/// Declaring it inline meant the first model change that SwiftData could not
/// migrate on its own would land on the failure path below — and that path used
/// to be silent. A version and a migration plan are what keep an install's
/// history from depending on luck.
enum DiemSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Interval.self, Subject.self] }
}

enum DiemMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [DiemSchemaV1.self] }
    /// One stage per version added. The first version has nothing to migrate
    /// from; this list is where the next one goes.
    static var stages: [MigrationStage] { [] }
}

/// One container, shared by the app and by intents running out of process.
enum DiemContainer {
    /// Whether the real store failed to open and the app is running on memory.
    ///
    /// Nothing is written to disk in that state, so a session studied now is
    /// gone at quit. The app used to fall back silently, which made a broken
    /// install look exactly like a fresh one right up until a day's work
    /// disappeared. The Start screen reads this and says so.
    nonisolated(unsafe) private(set) static var isEphemeral = false

    static let shared: ModelContainer = {
        let schema = Schema(versionedSchema: DiemSchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(SnapshotStore.appGroup)
        )
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: DiemMigrationPlan.self,
                configurations: configuration
            )
        } catch {
            isEphemeral = true
        }
        // Memory, and said so above. Kept as a `do` rather than a `try!`: a
        // force-unwrap on the recovery path of a failure already being handled
        // is the one place a crash is least excusable.
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            )
        } catch {
            // An in-memory container that cannot be built means SwiftData
            // itself is unusable, and there is nothing left to fall back to.
            fatalError("Diem could not open any model container: \(error)")
        }
    }()

    @MainActor
    static let store = SessionStore(context: ModelContext(shared))
}
