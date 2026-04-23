import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Reusable attachments UI block for items and log entries.
/// Parent owns persistence; this view only surfaces file pickers and tile layout.
struct AttachmentsSection: View {
    @Environment(UpkeepStore.self) private var store
    let attachments: [Attachment]
    let onAdd: (Attachment) -> Void
    let onRemove: (UUID) -> Void

    @State private var showLinkEntry = false
    @State private var linkURL = ""
    @State private var linkTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Attachments")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("Add Photo…", systemImage: "photo") { pickPhoto() }
                    Button("Add PDF (copy into upkeep)…", systemImage: "doc.richtext") { pickPDFCopy() }
                    Button("Add PDF (link, don't copy)…", systemImage: "doc.badge.arrow.up") { pickPDFLink() }
                    Button("Add Link (URL)…", systemImage: "link") {
                        linkURL = ""
                        linkTitle = ""
                        showLinkEntry = true
                    }
                } label: {
                    Label("Attach", systemImage: "paperclip")
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .popover(isPresented: $showLinkEntry) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Link")
                            .font(.headline)
                        TextField("https://…", text: $linkURL)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 280)
                        TextField("Title (optional)", text: $linkTitle)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 280)
                        HStack {
                            Spacer()
                            Button("Cancel") { showLinkEntry = false }
                            Button("Add") { commitLink() }
                                .buttonStyle(.borderedProminent)
                                .tint(.upkeepAmber)
                                .disabled(linkURL.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding(12)
                }
            }

            if attachments.isEmpty {
                HStack {
                    Spacer()
                    Text("No attachments")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 10)], spacing: 10) {
                    ForEach(attachments) { attachment in
                        AttachmentTile(attachment: attachment, url: store.attachmentURL(attachment))
                            .contextMenu {
                                Button("Open") { open(attachment) }
                                if attachment.kind != .link && attachment.kind != .pdfLink {
                                    Button("Reveal in Finder") { reveal(attachment) }
                                }
                                Divider()
                                Button("Remove", role: .destructive) {
                                    onRemove(attachment.id)
                                }
                            }
                            .onTapGesture { open(attachment) }
                    }
                }
            }
        }
    }

    // MARK: - Open / Reveal

    private func open(_ attachment: Attachment) {
        guard let url = store.attachmentURL(attachment) else { return }
        NSWorkspace.shared.open(url)
    }

    private func reveal(_ attachment: Attachment) {
        guard let url = store.attachmentURL(attachment) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Pickers

    private func pickPhoto() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                let attachment = try await store.importAttachmentFile(sourceURL: url, kind: .photo)
                onAdd(attachment)
            } catch {
                store.error = "Failed to import photo: \(error.localizedDescription)"
            }
        }
    }

    private func pickPDFCopy() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                let attachment = try await store.importAttachmentFile(sourceURL: url, kind: .pdf)
                onAdd(attachment)
            } catch {
                store.error = "Failed to import PDF: \(error.localizedDescription)"
            }
        }
    }

    private func pickPDFLink() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) }
        let attachment = Attachment(
            kind: .pdfLink,
            title: url.lastPathComponent,
            path: url.path,
            sizeBytes: size
        )
        onAdd(attachment)
    }

    private func commitLink() {
        let trimmed = linkURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let title = linkTitle.trimmingCharacters(in: .whitespaces)
        let attachment = Attachment(
            kind: .link,
            title: title.isEmpty ? trimmed : title,
            url: trimmed
        )
        onAdd(attachment)
        showLinkEntry = false
    }
}

// MARK: - Tile

private struct AttachmentTile: View {
    let attachment: Attachment
    let url: URL?

    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
                    .aspectRatio(4.0/3.0, contentMode: .fit)

                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: attachment.iconName)
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text(attachment.kindLabel)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Text(attachment.title)
                .font(.caption)
                .lineLimit(2)
                .truncationMode(.middle)
            if !attachment.caption.isEmpty {
                Text(attachment.caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .help(helpText)
        .onAppear(perform: loadThumbnail)
        .onChange(of: attachment.id) { loadThumbnail() }
    }

    private var helpText: String {
        switch attachment.kind {
        case .link: attachment.url ?? attachment.title
        case .pdfLink: attachment.path ?? attachment.title
        default: attachment.title
        }
    }

    private func loadThumbnail() {
        guard attachment.kind == .photo, let url else {
            thumbnail = nil
            return
        }
        Task.detached {
            if let img = NSImage(contentsOf: url) {
                await MainActor.run { self.thumbnail = img }
            }
        }
    }
}
