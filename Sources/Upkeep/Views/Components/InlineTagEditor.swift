import SwiftUI

struct InlineTagEditor: View {
    @Environment(UpkeepStore.self) private var store
    let tags: [String]
    @Binding var isAddingTag: Bool
    @Binding var newTagText: String
    var onAdd: (String) -> Void
    var onRemove: ((String) -> Void)?
    var onTap: ((String) -> Void)?
    @FocusState private var fieldFocused: Bool

    private var suggestions: [String] {
        let existing = Set(tags.map { $0.lowercased() })
        let query = newTagText.lowercased()
        let all = store.allTags
        if query.isEmpty {
            return all.filter { !existing.contains($0.lowercased()) }
        }
        return all.filter {
            $0.lowercased().contains(query) && !existing.contains($0.lowercased())
        }
    }

    var body: some View {
        FlowLayout(spacing: 5) {
            ForEach(tags, id: \.self) { tag in
                Button {
                    onTap?(tag)
                } label: {
                    StyledTag(name: tag)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if let onRemove {
                        Button("Remove Tag", role: .destructive) {
                            onRemove(tag)
                        }
                    }
                    Button("Show all with this tag") {
                        onTap?(tag)
                    }
                }
            }

            if isAddingTag {
                tagInputField
            } else {
                Button {
                    isAddingTag = true
                    newTagText = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        fieldFocused = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.upkeepAmber)
                        .frame(width: 22, height: 22)
                        .background(Color.upkeepAmber.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Add tag")
            }
        }
    }

    private var tagInputField: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                TextField("tag name", text: $newTagText)
                    .textFieldStyle(.plain)
                    .font(.caption2.weight(.medium))
                    .frame(width: 90)
                    .focused($fieldFocused)
                    .onSubmit { commitTag() }
                    .onExitCommand { cancelAdd() }

                Button {
                    commitTag()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.upkeepAmber)
                }
                .buttonStyle(.plain)
                .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)

                Button {
                    cancelAdd()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.upkeepAmber.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.upkeepAmber.opacity(0.3), lineWidth: 0.5))

            if !suggestions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions.prefix(8), id: \.self) { suggestion in
                            Button {
                                newTagText = suggestion
                                commitTag()
                            } label: {
                                Text(suggestion)
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 150)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.separator, lineWidth: 0.5)
                )
                .padding(.top, 2)
            }
        }
    }

    private func commitTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed)
        newTagText = ""
        isAddingTag = false
    }

    private func cancelAdd() {
        newTagText = ""
        isAddingTag = false
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Styled Tag

struct StyledTag: View {
    let name: String
    var color: Color = .upkeepAmber
    var compact: Bool = false

    var body: some View {
        Text(name)
            .font(compact ? .system(size: 9, weight: .medium) : .caption2.weight(.medium))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 2 : 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
