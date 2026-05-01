import SwiftUI
import AppKit

/// Single-select autocomplete picker. Shows current selection in the field; typing filters
/// the dropdown; Tab/↓ cycle forward, Shift-Tab/↑ backward, Enter commits, Esc dismisses.
/// `×` button clears the selection.
struct SearchablePicker<T: Identifiable>: View where T.ID == UUID {
    let label: String
    let items: [T]
    @Binding var selection: UUID?
    let displayName: (T) -> String
    var subtitle: ((T) -> String)? = nil
    var placeholder: String = "Type to search…"

    @State private var query = ""
    @State private var isFocused = false
    @State private var state = SearchablePickerState()
    @State private var eventMonitor: Any?
    @State private var isProgrammaticEdit = false
    @State private var pickerFrame: CGRect = .zero

    private var selectedItem: T? {
        guard let selection else { return nil }
        return items.first { $0.id == selection }
    }

    private var filteredItems: [T] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        // If query exactly matches the selected item's display name, show all items
        // (the user just opened a previously-selected field — they probably want to browse).
        if let sel = selectedItem, query == displayName(sel) {
            return items
        }
        if trimmed.isEmpty { return items }
        return items.filter { displayName($0).lowercased().contains(trimmed) }
    }

    private var displayedItems: [T] {
        guard state.showSuggestions else { return [] }
        return Array(filteredItems.prefix(8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                LeadingTextFieldCore(
                    text: $query,
                    prompt: placeholder,
                    isFocused: $isFocused
                )
                if selection != nil {
                    Button {
                        clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .help("Clear selection")
                }
            }
            .onChange(of: query) { _, _ in
                if isProgrammaticEdit { return }
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
                    // If user typed but didn't commit, restore the selected item's display name
                    let display = selectedItem.map(displayName) ?? ""
                    if query != display {
                        isProgrammaticEdit = true
                        query = display
                        DispatchQueue.main.async { isProgrammaticEdit = false }
                    }
                }
            }
            .onChange(of: selection) { _, _ in
                // Selection changed externally — reflect it in the field if we're not focused
                if !isFocused {
                    let display = selectedItem.map(displayName) ?? ""
                    if query != display {
                        isProgrammaticEdit = true
                        query = display
                        DispatchQueue.main.async { isProgrammaticEdit = false }
                    }
                }
            }
            .onAppear {
                let display = selectedItem.map(displayName) ?? ""
                if query != display {
                    isProgrammaticEdit = true
                    query = display
                    DispatchQueue.main.async { isProgrammaticEdit = false }
                }
            }

            if isFocused && !displayedItems.isEmpty {
                suggestionsDropdown
            }
        }
        .background(GeometryReader { geo in
            Color.clear
                .preference(key: PickerFramePreferenceKey.self, value: geo.frame(in: .global))
        })
        .onPreferenceChange(PickerFramePreferenceKey.self) { newFrame in
            pickerFrame = newFrame
        }
        .onDisappear { removeMonitor() }
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
                            HStack(spacing: 6) {
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
                                Spacer()
                                if item.id == selection {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.upkeepAmber)
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
        selection = item.id
        isProgrammaticEdit = true
        query = displayName(item)
        state.showSuggestions = false
        state.selectedIndex = -1
        DispatchQueue.main.async { isProgrammaticEdit = false }
    }

    private func clear() {
        selection = nil
        isProgrammaticEdit = true
        query = ""
        state.showSuggestions = false
        DispatchQueue.main.async { isProgrammaticEdit = false }
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
            // On click-release: dismiss only if the click landed OUTSIDE the picker frame
            // (field + dropdown). Inside-picker clicks are handled by the field/buttons themselves.
            // Watching mouseUp (not Down) lets the dropdown row's button finish its tap.
            if event.type == .leftMouseUp {
                if state.showSuggestions, let window = event.window {
                    let contentHeight = window.contentView?.bounds.height ?? 0
                    // SwiftUI .global has origin at top-left; AppKit window coords at bottom-left.
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

            // Tab — advance (Shift-Tab reverses)
            if event.keyCode == 48 {
                let pool = filteredItems
                if !pool.isEmpty {
                    advance(by: event.modifierFlags.contains(.shift) ? -1 : 1)
                    return nil
                }
                return event
            }

            // Down arrow or Ctrl-J
            if event.keyCode == 125 || (event.modifierFlags.contains(.control) && event.charactersIgnoringModifiers == "j") {
                let pool = filteredItems
                if !pool.isEmpty {
                    advance(by: 1)
                    return nil
                }
                return event
            }

            // Up arrow or Ctrl-K
            if event.keyCode == 126 || (event.modifierFlags.contains(.control) && event.charactersIgnoringModifiers == "k") {
                let pool = filteredItems
                if !pool.isEmpty {
                    advance(by: -1)
                    return nil
                }
                return event
            }

            // Escape — dismiss dropdown
            if event.keyCode == 53 {
                if state.showSuggestions {
                    state.showSuggestions = false
                    state.selectedIndex = -1
                    return nil
                }
                return event
            }

            // Enter — commit highlighted
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

@Observable
@MainActor
final class SearchablePickerState {
    var selectedIndex: Int = -1
    var showSuggestions = false
}

private struct PickerFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
