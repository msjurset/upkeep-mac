import SwiftUI

@Observable
@MainActor
final class TagSuggestState {
    var selectedIndex: Int = -1
    var showSuggestions = true
    var justAccepted = false
    var isPreviewing = false
    /// Locked suggestion list while cycling; nil when not cycling
    var cyclePool: [String]?
}

struct TagSuggestField: View {
    @Environment(UpkeepStore.self) private var store
    @Binding var text: String
    @State private var isFocused = false
    @State private var state = TagSuggestState()
    @State private var eventMonitor: Any?

    private var committedTags: Set<String> {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count > 1 else { return [] }
        return Set(parts.dropLast().map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty })
    }

    private var currentPartial: String {
        guard let lastComma = text.lastIndex(of: ",") else {
            return text.trimmingCharacters(in: .whitespaces).lowercased()
        }
        return String(text[text.index(after: lastComma)...]).trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var filteredSuggestions: [String] {
        let excluded = committedTags
        let partial = currentPartial
        let all = store.allTags.filter { !excluded.contains($0.lowercased()) }
        if partial.isEmpty {
            return all
        }
        return all.filter { $0.lowercased().contains(partial) }
    }

    /// What the dropdown displays — locked cycle pool while cycling, live filter otherwise
    private var displayedSuggestions: [String] {
        guard state.showSuggestions else { return [] }
        return Array((state.cyclePool ?? filteredSuggestions).prefix(8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LeadingTextField(
                label: "Tags",
                text: $text,
                prompt: "Comma-separated: spring-prep, weekend",
                isFocused: $isFocused
            )
            .onChange(of: text) {
                if state.isPreviewing {
                    state.isPreviewing = false
                    return
                }
                // User typed — reset cycling state
                state.selectedIndex = -1
                state.showSuggestions = true
                state.justAccepted = false
                state.cyclePool = nil
            }
            .onChange(of: isFocused) {
                if isFocused {
                    installMonitor()
                } else {
                    removeMonitor()
                    state.showSuggestions = false
                    state.cyclePool = nil
                }
            }

            if isFocused && !displayedSuggestions.isEmpty {
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
        if let lastComma = text.lastIndex(of: ",") {
            text = String(text[...lastComma]) + " " + suggestion
        } else {
            text = suggestion
        }
        state.selectedIndex = -1
        state.showSuggestions = false
        state.justAccepted = true
        state.cyclePool = nil
    }

    private func previewSuggestion(_ suggestion: String) {
        state.isPreviewing = true
        if let lastComma = text.lastIndex(of: ",") {
            text = String(text[...lastComma]) + " " + suggestion
        } else {
            text = suggestion
        }
    }

    private func advanceSelection(by delta: Int) {
        // Lock the suggestion list on first cycle so previews don't change it
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

    private func installMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isFocused else { return event }

            // Tab — advance (Shift-Tab reverses), but pass through after accept
            if event.keyCode == 48 /* Tab */ {
                if state.justAccepted { return event }
                let pool = state.cyclePool ?? filteredSuggestions
                if !pool.isEmpty {
                    advanceSelection(by: event.modifierFlags.contains(.shift) ? -1 : 1)
                    return nil
                }
                return event
            }

            // Down arrow or Ctrl-J — advance
            if event.keyCode == 125 /* Down */ || (event.modifierFlags.contains(.control) && event.charactersIgnoringModifiers == "j") {
                let pool = state.cyclePool ?? filteredSuggestions
                if !pool.isEmpty {
                    advanceSelection(by: 1)
                    return nil
                }
                return event
            }

            // Up arrow or Ctrl-K — previous
            if event.keyCode == 126 /* Up */ || (event.modifierFlags.contains(.control) && event.charactersIgnoringModifiers == "k") {
                let pool = state.cyclePool ?? filteredSuggestions
                if !pool.isEmpty {
                    advanceSelection(by: -1)
                    return nil
                }
                return event
            }

            // Escape — dismiss
            if event.keyCode == 53 /* Escape */ {
                if state.showSuggestions && !displayedSuggestions.isEmpty {
                    state.showSuggestions = false
                    state.selectedIndex = -1
                    state.cyclePool = nil
                    return nil
                }
                return event
            }

            // Enter — accept or pass through
            if event.keyCode == 36 /* Return */ {
                if state.justAccepted || displayedSuggestions.isEmpty {
                    return event
                }
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
