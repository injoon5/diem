import Foundation

// Hand-written mirror of the server schema. ISO8601 with fractional seconds on
// the wire in both directions.

struct IntervalDTO: Codable, Hashable, Identifiable {
    var id: UUID
    var sessionId: UUID
    var subjectId: UUID?
    var startedAt: Date
    var endedAt: Date?
    var plannedSec: Int?
}

struct SubjectDTO: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var colorIndex: Int
    var archived: Bool
    var updatedAt: Date
    var deletedAt: Date?
}

struct PairRequest: Codable { var deviceToken: String }
struct PairResponse: Codable { var code: String; var expiresAt: Date }

struct IntervalPush: Codable { var intervals: [IntervalDTO] }
struct IntervalPushResponse: Codable { var accepted: [UUID] }
struct IntervalPage: Codable { var intervals: [IntervalDTO]; var cursor: String? }
struct SubjectPush: Codable { var subjects: [SubjectDTO] }
struct SubjectPage: Codable { var subjects: [SubjectDTO] }

extension JSONDecoder {
    static let diem: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = ISO8601.parse(raw) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Bad date: \(raw)")
                )
            }
            return date
        }
        return decoder
    }()
}

extension JSONEncoder {
    static let diem: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601.string(from: date))
        }
        return encoder
    }()
}

enum ISO8601 {
    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func string(from date: Date) -> String { withFraction.string(from: date) }

    static func parse(_ raw: String) -> Date? {
        withFraction.date(from: raw) ?? plain.date(from: raw)
    }
}

extension Interval {
    var dto: IntervalDTO {
        IntervalDTO(
            id: id,
            sessionId: sessionID,
            subjectId: subjectID,
            startedAt: startedAt,
            endedAt: endedAt,
            plannedSec: plannedSec
        )
    }
}

extension Subject {
    var dto: SubjectDTO {
        SubjectDTO(
            id: id,
            name: name,
            colorIndex: colorIndex,
            archived: archived,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }
}
