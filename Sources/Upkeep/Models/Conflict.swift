import Foundation

struct Conflict: Identifiable {
    enum EntityKind: String { case item, vendor }

    let id: UUID
    let entityID: UUID
    let kind: EntityKind
    let entityName: String
    let ourVersion: Int
    let theirVersion: Int
    let theirModifiedBy: UUID?
    let detectedAt: Date = .now
}
