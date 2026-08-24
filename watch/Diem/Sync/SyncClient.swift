import Foundation

/// The app works fully without ever pairing, so every call here is allowed to
/// fail quietly.
struct SyncClient: Sendable {
    enum Failure: Error {
        case badResponse(Int)
        case notPaired
    }

    var baseURL: URL
    var deviceToken: String

    static let defaultBaseURL = URL(string: "https://diem.app")!

    @MainActor
    static func live() -> SyncClient {
        let configured = Bundle.main.object(forInfoDictionaryKey: "DiemAPIBaseURL") as? String
        return SyncClient(
            baseURL: configured.flatMap(URL.init(string:)) ?? defaultBaseURL,
            deviceToken: Settings.shared.deviceToken
        )
    }

    /// Claims a pairing code to show on the watch.
    func pair() async throws -> PairResponse {
        try await send(
            path: "/api/pair",
            method: "POST",
            body: PairRequest(deviceToken: deviceToken),
            as: PairResponse.self
        )
    }

    /// Idempotent on interval id — resending an accepted interval is a no-op.
    func push(intervals: [IntervalDTO]) async throws -> [UUID] {
        try await send(
            path: "/api/intervals",
            method: "POST",
            body: IntervalPush(intervals: intervals),
            as: IntervalPushResponse.self
        ).accepted
    }

    func pullIntervals(since cursor: String?) async throws -> IntervalPage {
        var path = "/api/intervals"
        if let cursor { path += "?since=\(cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor)" }
        return try await send(path: path, method: "GET", body: Optional<Never>.none, as: IntervalPage.self)
    }

    func pullSubjects() async throws -> [SubjectDTO] {
        try await send(path: "/api/subjects", method: "GET", body: Optional<Never>.none, as: SubjectPage.self).subjects
    }

    /// Last-write-wins on `updatedAt`.
    func push(subjects: [SubjectDTO]) async throws {
        _ = try await send(
            path: "/api/subjects",
            method: "POST",
            body: SubjectPush(subjects: subjects),
            as: SubjectPage.self
        )
    }

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body?,
        as: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue(deviceToken, forHTTPHeaderField: "X-Diem-Device")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder.diem.encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw status == 401 ? Failure.notPaired : Failure.badResponse(status)
        }
        return try JSONDecoder.diem.decode(Response.self, from: data)
    }
}

/// Push completed intervals, pull subjects. Nothing else crosses the wire.
@MainActor
enum SyncEngine {
    static func run(store: SessionStore, client: SyncClient = .live()) async {
        let pending = store.unsyncedIntervals()
        if !pending.isEmpty {
            do {
                let accepted = try await client.push(intervals: pending.map(\.dto))
                store.markSynced(accepted)
            } catch {
                return  // Offline is the normal case; try again next launch.
            }
        }
        do {
            let local = store.subjects(includeArchived: true).map(\.dto)
            if !local.isEmpty { try await client.push(subjects: local) }
            store.merge(subjects: try await client.pullSubjects())
        } catch {
            return
        }
    }
}
