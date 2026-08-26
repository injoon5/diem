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
    /// Where the history actually ended up.
    ///
    /// The store lives in the App Group container so that it survives an app
    /// update — the app bundle is replaced on update, the container is not —
    /// and so that the widget and out-of-process intents read the same rows.
    enum Storage {
        /// The App Group container. The only case where everything works.
        case group
        /// The app's own container, on disk. The day is kept across launches
        /// and across updates, but the widget and intents cannot see it.
        case local
        /// Memory. Nothing survives quit.
        case memory
    }

    /// Where this process opened its store. Read by the Start screen, which
    /// says so when it is not `.group`.
    nonisolated(unsafe) private(set) static var storage: Storage = .group

    static let shared: ModelContainer = {
        let schema = Schema(versionedSchema: DiemSchemaV1.self)

        // The App Group store: shared, and preserved across updates.
        //
        // Asked for only once the container is known to be reachable. A
        // `ModelConfiguration` naming a group this process has no entitlement
        // for does not throw — SwiftData traps inside itself, "Unable to find
        // App Group Container in Entitlements" — so every line of recovery
        // below it was unreachable in exactly the case it was written for: a
        // build signed without the group, which is what a simulator build and
        // a re-signed one both are. `containerURL` is the same question asked
        // where a no is an answer rather than a crash.
        if FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SnapshotStore.appGroup) != nil {
            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: DiemMigrationPlan.self,
                    configurations: ModelConfiguration(
                        schema: schema,
                        groupContainer: .identifier(SnapshotStore.appGroup)
                    )
                )
            } catch {
                storage = .local
            }
        } else {
            storage = .local
        }

        // The group container is a provisioning fact, not a code one: an app
        // group missing from the profile, or dropped when the app was re-signed
        // under a different team, takes the shared store down with it. That
        // used to drop the app straight onto memory, which meant a signing
        // detail cost the user every session of the day. On-disk-but-private is
        // worse than shared and far better than gone — the day persists, and
        // only the widget goes stale.
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: DiemMigrationPlan.self,
                configurations: ModelConfiguration(schema: schema)
            )
        } catch {
            storage = .memory
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
