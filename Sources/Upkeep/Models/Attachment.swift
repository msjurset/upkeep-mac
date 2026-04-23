import Foundation

/// A file or link attached to a MaintenanceItem or LogEntry.
///
/// Storage strategy:
/// - `.photo` / `.pdf`: file data is copied into the shared attachments/ directory. `filename` is set.
/// - `.pdfLink`: only the absolute local path is stored. `path` is set.
/// - `.link`: a URL (website, cloud file). `url` is set.
struct Attachment: Codable, Identifiable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case photo
        case pdf
        case pdfLink
        case link
    }

    var id: UUID
    var kind: Kind
    var title: String
    var caption: String
    var filename: String?
    var path: String?
    var url: String?
    var addedAt: Date
    var sizeBytes: Int64?

    init(id: UUID = UUID(), kind: Kind, title: String, caption: String = "",
         filename: String? = nil, path: String? = nil, url: String? = nil,
         addedAt: Date = .now, sizeBytes: Int64? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.caption = caption
        self.filename = filename
        self.path = path
        self.url = url
        self.addedAt = addedAt
        self.sizeBytes = sizeBytes
    }

    var isFileBacked: Bool { kind == .photo || kind == .pdf }
    var isExternal: Bool { kind == .pdfLink || kind == .link }

    var iconName: String {
        switch kind {
        case .photo: "photo"
        case .pdf, .pdfLink: "doc.richtext"
        case .link: "link"
        }
    }

    var kindLabel: String {
        switch kind {
        case .photo: "Photo"
        case .pdf: "PDF"
        case .pdfLink: "PDF (link)"
        case .link: "Link"
        }
    }
}
