import SwiftUI

@Observable
@MainActor
private final class InlineTagSuggestState {
    var selectedIndex: Int = -1
    var showSuggestions = true
    var isPreviewing = false
    var cyclePool: [String]?
}

struct InlineTagEditor: View {
    @Environment(UpkeepStore.self) private var store
    let tags: [String]
    @Binding var isAddingTag: Bool
    @Binding var newTagText: String
    var onAdd: (String) -> Void
    var onRemove: ((String) -> Void)?
    var onTap: ((String) -> Void)?
    @FocusState private var fieldFocused: Bool
    @State private var state = InlineTagSuggestState()
    @State private var eventMonitor: Any?

    private var filteredSuggestions: [String] {
        let existing = Set(tags.map { $0.lowercased() })
        let query = newTagText.lowercased()
        let all = store.allTags.filter { !existing.contains($0.lowercased()) }
        if query.isEmpty {
            return all
        }
        return all.filter { $0.lowercased().contains(query) }
    }

    private var displayedSuggestions: [String] {
        guard state.showSuggestions else { return [] }
        return Array((state.cyclePool ?? filteredSuggestions).prefix(8))
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
                    state.selectedIndex = -1
                    state.showSuggestions = true
                    state.cyclePool = nil
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
                    .onSubmit {
                        if state.selectedIndex >= 0 && state.selectedIndex < displayedSuggestions.count {
                            acceptSuggestion(displayedSuggestions[state.selectedIndex])
                        } else {
                            commitTag()
                        }
                    }
                    .onExitCommand { cancelAdd() }
                    .onChange(of: newTagText) {
                        if state.isPreviewing {
                            state.isPreviewing = false
                            return
                        }
                        state.selectedIndex = -1
                        state.showSuggestions = true
                        state.cyclePool = nil
                    }
                    .onChange(of: fieldFocused) {
                        if fieldFocused {
                            installMonitor()
                        } else {
                            removeMonitor()
                        }
                    }

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

            if !displayedSuggestions.isEmpty {
                suggestionsDropdown
            }
        }
        .onDisappear { removeMonitor() }
    }

    private var suggestionsDropdown: some View {
        let items = displayedSuggestions
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, suggestion in
                        Button {
                            acceptSuggestion(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.callout)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(index == state.selectedIndex ? Color.accentColor.opacity(0.2) : .clear)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
            }
            .frame(maxHeight: 150)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator, lineWidth: 0.5))
            .padding(.top, 2)
            .onChange(of: state.selectedIndex) {
                if state.selectedIndex >= 0 {
                    proxy.scrollTo(state.selectedIndex, anchor: .center)
                }
            }
        }
    }

    private func acceptSuggestion(_ suggestion: String) {
        state.isPreviewing = true
        newTagText = suggestion
        commitTag()
    }

    private func previewSuggestion(_ suggestion: String) {
        state.isPreviewing = true
        newTagText = suggestion
    }

    private func advanceSelection(by delta: Int) {
        if state.cyclePool == nil {
            let pool = Array(filteredSuggestions.prefix(8))
            guard !pool.isEmpty else { return }
            state.cyclePool = pool
        }
        let pool = state.cyclePool!
        let count = pool.count
        state.showSuggestions = true
        let newIndex: Int
        if state.selectedIndex < 0 {
            newIndex = delta > 0 ? 0 : count - 1
        } else {
            newIndex = (state.selectedIndex + delta + count) % count
        }
        state.selectedIndex = newIndex
        previewSuggestion(pool[newIndex])
    }

    private func commitTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed)
        newTagText = ""
        isAddingTag = false
        removeMonitor()
    }

    private func cancelAdd() {
        newTagText = ""
        isAddingTag = false
        removeMonitor()
    }

    private func installMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard fieldFocused else { return event }

            if event.keyCode == 48 /* Tab */ {
                let pool = state.cyclePool ?? filteredSuggestions
                if !pool.isEmpty {
                    advanceSelection(by: event.modifierFlags.contains(.shift) ? -1 : 1)
                    return nil
                }
                return event
            }

            if event.keyCode == 125 /* Down */ || (event.modifierFlags.contains(.control) && event.charactersIgnoringModifiers == "j") {
                let pool = state.cyclePool ?? filteredSuggestions
                if !pool.isEmpty {
                    advanceSelection(by: 1)
                    return nil
                }
                return event
            }

            if event.keyCode == 126 /* Up */ || (event.modifierFlags.contains(.control) && event.charactersIgnoringModifiers == "k") {
                let pool = state.cyclePool ?? filteredSuggestions
                if !pool.isEmpty {
                    advanceSelection(by: -1)
                    return nil
                }
                return event
            }

            if event.keyCode == 53 /* Escape */ {
                if state.showSuggestions && !displayedSuggestions.isEmpty {
                    state.showSuggestions = false
                    state.selectedIndex = -1
                    state.cyclePool = nil
                    return nil
                }
                return event
            }

            if event.keyCode == 36 /* Return */ {
                let pool = displayedSuggestions
                if state.selectedIndex >= 0 && state.selectedIndex < pool.count {
                    acceptSuggestion(pool[state.selectedIndex])
                    return nil
                }
                return event
            }

            return event
        }
    }

    private func removeMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
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
