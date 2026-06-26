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
    let onUpdate: (Attachment) -> Void

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
                    Button("Paste Photo from Clipboard", systemImage: "doc.on.clipboard") {
                        pastePhotoFromClipboard()
                    }
                    .keyboardShortcut("v", modifiers: .command)
                    .disabled(!clipboardHasImage())

                    Divider()

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
                        AttachmentTile(
                            attachment: attachment,
                            url: store.attachmentURL(attachment),
                            onUpdate: onUpdate,
                            onTap: {
                                if attachment.kind == .photo {
                                    let photos = attachments.filter { $0.kind == .photo }
                                    let urls = photos.compactMap { store.attachmentURL($0) }
                                    if let idx = photos.firstIndex(where: { $0.id == attachment.id }) {
                                        ImagePreviewPresenter.present(urls: urls, initialIndex: idx)
                                    }
                                } else {
                                    open(attachment)
                                }
                            }
                        )
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
                    }
                }
            }
        }
        .onPasteCommand(of: [.image]) { providers in
            guard let provider = providers.first else { return }
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let data {
                    let tempDir = FileManager.default.temporaryDirectory
                    let tempURL = tempDir.appendingPathComponent("pasted_\(UUID().uuidString).png")
                    do {
                        try data.write(to: tempURL)
                        Task { @MainActor in
                            do {
                                let attachment = try await store.importAttachmentFile(sourceURL: tempURL, kind: .photo)
                                var customized = attachment
                                customized.title = "Pasted Photo"
                                onAdd(customized)
                                try? FileManager.default.removeItem(at: tempURL)
                            } catch {
                                store.error = "Failed to import pasted image: \(error.localizedDescription)"
                            }
                        }
                    } catch {}
                }
            }
        }
    }

    // MARK: - Clipboard Paste Helpers

    private func clipboardHasImage() -> Bool {
        let pb = NSPasteboard.general
        if pb.canReadItem(withDataConformingToTypes: [UTType.image.identifier]) {
            return true
        }
        if let fileURLs = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            return fileURLs.contains { url in
                if let type = UTType(filenameExtension: url.pathExtension) {
                    return type.conforms(to: .image)
                }
                return false
            }
        }
        return false
    }

    private func pastePhotoFromClipboard() {
        let pb = NSPasteboard.general
        
        // 1. Try file URLs first (e.g. copied from Finder)
        if let fileURLs = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let firstURL = fileURLs.first(where: { UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) == true }) {
            Task {
                do {
                    let attachment = try await store.importAttachmentFile(sourceURL: firstURL, kind: .photo)
                    onAdd(attachment)
                } catch {
                    store.error = "Failed to import pasted file: \(error.localizedDescription)"
                }
            }
            return
        }
        
        // 2. Try raw image data
        guard let imgData = pb.data(forType: .png) ?? pb.data(forType: .tiff) else {
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFilename = "pasted_image_\(UUID().uuidString).png"
        let tempURL = tempDir.appendingPathComponent(tempFilename)
        
        do {
            try imgData.write(to: tempURL)
            Task {
                do {
                    let attachment = try await store.importAttachmentFile(sourceURL: tempURL, kind: .photo)
                    var customized = attachment
                    customized.title = "Pasted Photo"
                    onAdd(customized)
                    try? FileManager.default.removeItem(at: tempURL)
                } catch {
                    store.error = "Failed to import pasted image: \(error.localizedDescription)"
                }
            }
        } catch {
            store.error = "Failed to write pasted image data: \(error.localizedDescription)"
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
    let onUpdate: (Attachment) -> Void
    let onTap: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isEditing = false
    @State private var editedCaption = ""
    @FocusState private var isCaptionFieldFocused: Bool

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
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }

            Text(attachment.title)
                .font(.caption)
                .lineLimit(2)
                .truncationMode(.middle)
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }

            if isEditing {
                TextField("Caption", text: $editedCaption)
                    .font(.caption2)
                    .textFieldStyle(.roundedBorder)
                    .focused($isCaptionFieldFocused)
                    .onSubmit { commitCaption() }
            } else {
                Text(attachment.caption.isEmpty ? "Add caption…" : attachment.caption)
                    .font(.caption2)
                    .foregroundStyle(attachment.caption.isEmpty ? Color.secondary.opacity(0.4) : Color.secondary)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        editedCaption = attachment.caption
                        isEditing = true
                        isCaptionFieldFocused = true
                    }
            }
        }
        .help(helpText)
        .onAppear(perform: loadThumbnail)
        .onChange(of: attachment.id) { loadThumbnail() }
        .onChange(of: isCaptionFieldFocused) { _, newValue in
            if !newValue && isEditing {
                commitCaption()
            }
        }
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

    private func commitCaption() {
        isEditing = false
        var updated = attachment
        updated.caption = editedCaption.trimmingCharacters(in: .whitespaces)
        onUpdate(updated)
    }
}
