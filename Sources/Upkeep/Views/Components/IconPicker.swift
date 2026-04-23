import SwiftUI

/// Emoji-picker-style SF Symbol chooser. Search matches curated catalog entries by name OR
/// alias keyword (so "carpet" finds rectangle.stack). Typing a literal SF Symbol name that
/// isn't in the catalog still previews live — click "Use '{name}'" to apply it.
struct IconPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String?
    let fallbackIcon: String
    let fallbackLabel: String

    @State private var query = ""

    private var results: [CatalogIcon] {
        IconCatalog.search(query)
    }

    private var grouped: [(IconGroup, [CatalogIcon])] {
        let src = query.isEmpty ? IconCatalog.icons : results
        var bucket: [IconGroup: [CatalogIcon]] = [:]
        for icon in src {
            bucket[icon.group, default: []].append(icon)
        }
        return IconGroup.allCases.compactMap { group in
            guard let list = bucket[group], !list.isEmpty else { return nil }
            return (group, list)
        }
    }

    /// The raw query as a candidate SF Symbol name. Shown as a "Use literal" row when
    /// the query looks like a valid symbol name and isn't already a catalog match.
    private var literalCandidate: String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // SF Symbol names use lowercase letters, digits, dots, underscores
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._")
        let trimmedLower = trimmed.lowercased()
        guard trimmedLower.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        // Only propose as literal if NSImage can resolve it (hides bogus names)
        guard NSImage(systemSymbolName: trimmedLower, accessibilityDescription: nil) != nil else { return nil }
        // Don't duplicate a catalog match
        if results.contains(where: { $0.name == trimmedLower }) { return nil }
        return trimmedLower
    }

    private let columns = Array(repeating: GridItem(.flexible(minimum: 44), spacing: 6), count: 8)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Choose Icon")
                    .font(.headline)
                Spacer()
                Button("Use Category Default") {
                    selection = nil
                    dismiss()
                }
                .controlSize(.small)
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search icons (try \"carpet\", \"light\", \"bath\"…)", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.bar)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            // Current selection preview
            HStack(spacing: 10) {
                Text("Current")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: selection ?? fallbackIcon)
                    .font(.title3)
                    .foregroundStyle(.upkeepAmber)
                    .frame(width: 28, height: 28)
                Text(selection == nil ? "\(fallbackLabel) (default)" : (selection ?? ""))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            Divider()

            // Literal candidate pill (full SF Symbol library access)
            if let literal = literalCandidate {
                HStack(spacing: 8) {
                    Image(systemName: literal)
                        .font(.title3)
                        .foregroundStyle(.upkeepAmber)
                        .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Use \"\(literal)\"")
                            .font(.callout.weight(.medium))
                        Text("From the full SF Symbols library")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("Pick") {
                        selection = literal
                        dismiss()
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.upkeepAmber.opacity(0.08))
            }

            // Grid
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: []) {
                    ForEach(grouped, id: \.0) { group, icons in
                        Section {
                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(icons) { entry in
                                    iconCell(entry.name)
                                }
                            }
                            .padding(.horizontal, 12)
                        } header: {
                            Text(group.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.top, 4)
                        }
                    }

                    if grouped.isEmpty && literalCandidate == nil {
                        VStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text("No matches for \"\(query)\"")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text("Try a different word, or browse the full library at developer.apple.com/sf-symbols")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 560, height: 520)
    }

    private func iconCell(_ name: String) -> some View {
        let isSelected = selection == name
        return Button {
            selection = name
            dismiss()
        } label: {
            Image(systemName: name)
                .font(.title2)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 44, height: 44)
                .background(isSelected ? Color.upkeepAmber : Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .help(name)
        }
        .buttonStyle(.plain)
    }
}
