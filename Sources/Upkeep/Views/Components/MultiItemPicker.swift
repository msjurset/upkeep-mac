import SwiftUI
import AppKit

/// Multi-select autocomplete picker. Selected items render as chips above the field;
/// each chip has its own × to remove. The autocomplete field below adds new items —
/// committing keeps the dropdown open so you can keep adding.
/// Tab/↓ cycle forward, Shift-Tab/↑ backward, Enter commits highlighted, Esc dismisses.
struct MultiItemPicker<T: Identifiable>: View where T.ID == UUID {
    let label: String
    let items: [T]
    @Binding var selection: [UUID]
    let displayName: (T) -> String
    var subtitle: ((T) -> String)? = nil
    var placeholder: String = "Type to add another…"

    @State private var query = ""
    @State private var isFocused = false
    @State private var state = SearchablePickerState()
    @State private var eventMonitor: Any?
    @State private var pickerFrame: CGRect = .zero

    private var selectedItems: [T] {
        selection.compactMap { id in items.first { $0.id == id } }
    }

    /// Items not already selected, filtered by the current query.
    private var filteredItems: [T] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        let unselected = items.filter { !selection.contains($0.id) }
        if trimmed.isEmpty { return unselected }
        return unselected.filter { displayName($0).lowercased().contains(trimmed) }
    }

    private var displayedItems: [T] {
        guard state.showSuggestions else { return [] }
        return Array(filteredItems.prefix(8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !selectedItems.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(selectedItems) { item in
                        chip(for: item)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                LeadingTextFieldCore(
                    text: $query,
                    prompt: placeholder,
                    isFocused: $isFocused
                )
                .onChange(of: query) { _, _ in
                    state.selectedIndex = -1
                    state.showSuggestions = isFocused
                }
                .onChange(of: isFocused) { _, focused in
                    if focused {
                        installMonitor()
                        state.showSuggestions = true
                        state.selectedIndex = -1
                    } else {
                        removeMonitor()
                        state.showSuggestions = false
                        state.selectedIndex = -1
                    }
                }

                if isFocused && !displayedItems.isEmpty {
                    suggestionsDropdown
                }
            }
        }
        .background(GeometryReader { geo in
            Color.clear
                .preference(key: MultiPickerFramePreferenceKey.self, value: geo.frame(in: .global))
        })
        .onPreferenceChange(MultiPickerFramePreferenceKey.self) { newFrame in
            pickerFrame = newFrame
        }
        .onDisappear { removeMonitor() }
    }

    private func chip(for item: T) -> some View {
        HStack(spacing: 4) {
            Text(displayName(item))
                .font(.caption)
                .lineLimit(1)
            Button {
                remove(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Remove \(displayName(item))")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(.upkeepAmber.opacity(0.15)))
        .overlay(Capsule().strokeBorder(.upkeepAmber.opacity(0.4)))
    }

    private var suggestionsDropdown: some View {
        let pool = displayedItems
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(pool.enumerated()), id: \.element.id) { index, item in
                        Button {
                            commit(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(displayName(item))
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                                if let sub = subtitle?(item), !sub.isEmpty {
                                    Text(sub)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                            .background(index == state.selectedIndex ? Color.accentColor.opacity(0.2) : .clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
            }
            .frame(maxHeight: 180)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator, lineWidth: 0.5))
            .padding(.top, 2)
            .onChange(of: state.selectedIndex) { _, idx in
                if idx >= 0 {
                    proxy.scrollTo(idx, anchor: .center)
                }
            }
        }
    }

    private func commit(_ item: T) {
        selection.append(item.id)
        query = ""
        state.selectedIndex = -1
        // Keep dropdown open so user can keep adding
        state.showSuggestions = isFocused
    }

    private func remove(_ item: T) {
        selection.removeAll { $0 == item.id }
    }

    private func advance(by delta: Int) {
        let pool = filteredItems
        guard !pool.isEmpty else { return }
        let count = min(pool.count, 8)
        state.showSuggestions = true
        if state.selectedIndex < 0 {
            state.selectedIndex = delta > 0 ? 0 : count - 1
        } else {
            state.selectedIndex = (state.selectedIndex + delta + count) % count
        }
    }

    private func installMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseUp]) { event in
            if event.type == .leftMouseUp {
                if state.showSuggestions, let window = event.window {
                    let contentHeight = window.contentView?.bounds.height ?? 0
                    let mouseLoc = CGPoint(
                        x: event.locationInWindow.x,
                        y: contentHeight - event.locationInWindow.y
                    )
                    if !pickerFrame.contains(mouseLoc) {
                        DispatchQueue.main.async {
                            state.showSuggestions = false
                            window.makeFirstResponder(nil)
                        }
                    }
                }
                return event
            }

            guard isFocused else { return event }

            if event.keyCode == 48 {
                let pool = filteredItems
                if !pool.isEmpty {
                    advance(by: event.modifierFlags.contains(.shift) ? -1 : 1)
                    return nil
                }
                return event
            }
            if event.keyCode == 125 || (event.modifierFlags.contains(.control) && event.charactersIgnoringModifiers == "j") {
                let pool = filteredItems
                if !pool.isEmpty { advance(by: 1); return nil }
                return event
            }
            if event.keyCode == 126 || (event.modifierFlags.contains(.control) && event.charactersIgnoringModifiers == "k") {
                let pool = filteredItems
                if !pool.isEmpty { advance(by: -1); return nil }
                return event
            }
            if event.keyCode == 53 {
                if state.showSuggestions {
                    state.showSuggestions = false
                    state.selectedIndex = -1
                    return nil
                }
                return event
            }
            if event.keyCode == 36 {
                let pool = displayedItems
                if state.selectedIndex >= 0 && state.selectedIndex < pool.count {
                    commit(pool[state.selectedIndex])
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

private struct MultiPickerFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
