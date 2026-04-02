import SwiftUI

struct QuickSearchView: View {
    @Environment(UpkeepStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [UpkeepStore.SearchResult] = []
    @State private var tagMatches: [String] = []
    @State private var activeIndex = -1
    @State private var resultActiveIndex = -1
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.upkeepAmber)

                TextField("Search items, log entries, vendors...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($fieldFocused)
                    .onSubmit { handleEnter() }
                    .onChange(of: query) { _, newValue in
                        activeIndex = -1
                        resultActiveIndex = -1
                        updateTagSuggestions()
                        debounceSearch(newValue)
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                        tagMatches = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            // Tag suggestions
            if !tagMatches.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(tagMatches.enumerated()), id: \.element) { idx, tag in
                        Button {
                            completeTag(tag)
                        } label: {
                            HStack {
                                Label("tag:\(tag)", systemImage: "tag")
                                    .font(.callout)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(idx == activeIndex ? Color.accentColor.opacity(0.2) : .clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)

                Divider()
            }

            // Results
            if results.isEmpty && !query.isEmpty && tagMatches.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("No results for \"\(query)\"")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tagMatches.isEmpty {
                ScrollViewReader { proxy in
                    List(Array(results.enumerated()), id: \.element.id) { idx, result in
                        Button {
                            selectResult(result)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: result.icon)
                                    .font(.body)
                                    .foregroundStyle(result.tint.map { Color.categoryColor($0) } ?? .upkeepAmber)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.body)
                                        .lineLimit(1)
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Text(resultKindLabel(result.kind))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(idx == resultActiveIndex ? Color.accentColor.opacity(0.2) : .clear)
                                    .padding(.horizontal, -4)
                            )
                        }
                        .buttonStyle(.plain)
                        .id(result.id)
                    }
                    .listStyle(.plain)
                    .onChange(of: resultActiveIndex) { _, newIdx in
                        if newIdx >= 0 && newIdx < results.count {
                            proxy.scrollTo(results[newIdx].id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 520, height: 400)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                fieldFocused = true
            }
        }
        .onKeyPress(.downArrow) {
            if !tagMatches.isEmpty {
                navigate(.down)
            } else if !results.isEmpty {
                resultActiveIndex = min(resultActiveIndex + 1, results.count - 1)
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if !tagMatches.isEmpty {
                navigate(.up)
            } else if !results.isEmpty {
                resultActiveIndex = max(resultActiveIndex - 1, -1)
            }
            return .handled
        }
        .onKeyPress(.tab) {
            if !tagMatches.isEmpty {
                navigate(.down)
                return .handled
            } else if !results.isEmpty {
                resultActiveIndex = resultActiveIndex < 0 ? 0 : min(resultActiveIndex + 1, results.count - 1)
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Tag Suggestions

    private func updateTagSuggestions() {
        guard let match = query.range(of: #"(?:^|\s)tag:(\S*)$"#, options: .regularExpression) else {
            tagMatches = []
            return
        }

        let token = String(query[match])
        guard let colonIdx = token.firstIndex(of: ":") else {
            tagMatches = []
            return
        }

        let partial = String(token[token.index(after: colonIdx)...]).lowercased()
        let existing = Set(query.matches(of: /tag:(\S+)/).compactMap { String($0.output.1).lowercased() })

        tagMatches = store.allTags
            .filter { tag in
                let lower = tag.lowercased()
                return (partial.isEmpty || lower.contains(partial)) && !existing.contains(lower)
            }
            .prefix(8)
            .map { $0 }
    }

    private func completeTag(_ tagName: String) {
        guard let range = query.range(of: #"(?:^|\s)tag:\S*$"#, options: .regularExpression) else { return }
        let before = query[query.startIndex..<range.lowerBound]
        let prefix = query[range].hasPrefix(" ") ? " " : ""
        query = "\(before)\(prefix)tag:\(tagName) "
        tagMatches = []
        activeIndex = -1
        debounceSearch(query)
    }

    // MARK: - Search

    private func debounceSearch(_ query: String) {
        searchTask?.cancel()
        guard !query.isEmpty else { results = []; return }

        let tagTokens = query.matches(of: /tag:(\S+)/).map { String($0.output.1).lowercased() }
        let textQuery = query
            .replacing(/tag:\S*/, with: "")
            .trimmingCharacters(in: .whitespaces)

        if textQuery.isEmpty && tagTokens.isEmpty {
            results = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            var found: [UpkeepStore.SearchResult]
            if !textQuery.isEmpty {
                found = store.search(query: textQuery)
            } else {
                found = store.items
                    .filter { item in tagTokens.allSatisfy { tag in item.tags.contains(tag) } }
                    .prefix(20)
                    .map { item in
                        UpkeepStore.SearchResult(id: item.id, kind: .item, title: item.name,
                                                  subtitle: "\(item.category.label) ~ \(item.frequencyDescription)",
                                                  icon: item.category.icon, tint: item.category)
                    }
            }

            // Filter by tags if both text and tags present
            if !textQuery.isEmpty && !tagTokens.isEmpty {
                let taggedItemIDs = Set(store.items.filter { item in
                    tagTokens.allSatisfy { tag in item.tags.contains(tag) }
                }.map(\.id))
                found = found.filter { $0.kind != .item || taggedItemIDs.contains($0.id) }
            }

            if !Task.isCancelled {
                results = found
            }
        }
    }

    // MARK: - Navigation

    private enum Direction { case down, up }

    private func navigate(_ direction: Direction) {
        guard !tagMatches.isEmpty else { return }
        switch direction {
        case .down:
            activeIndex = activeIndex < 0 ? 0 : min(activeIndex + 1, tagMatches.count - 1)
        case .up:
            activeIndex = max(activeIndex - 1, -1)
        }
    }

    private func handleEnter() {
        if !tagMatches.isEmpty {
            let idx = activeIndex >= 0 ? activeIndex : 0
            if idx < tagMatches.count {
                completeTag(tagMatches[idx])
            }
            return
        }
        if resultActiveIndex >= 0 && resultActiveIndex < results.count {
            selectResult(results[resultActiveIndex])
        } else if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            // Dismiss and apply as list filter
            store.searchQuery = query
            store.navigation = .inventoryAll
            store.selectedItemID = nil
            dismiss()
        }
    }

    private func selectResult(_ result: UpkeepStore.SearchResult) {
        switch result.kind {
        case .item:
            store.navigation = .inventoryAll
            store.selectedItemID = result.id
        case .logEntry:
            store.navigation = .log
            store.selectedLogEntryID = result.id
        case .vendor:
            store.navigation = .vendors
            store.selectedVendorID = result.id
        }
        dismiss()
    }

    private func resultKindLabel(_ kind: UpkeepStore.SearchResult.Kind) -> String {
        switch kind {
        case .item: return "Item"
        case .logEntry: return "Log"
        case .vendor: return "Vendor"
        }
    }
}

// MARK: - Search Key Monitor

struct SearchKeyMonitor: NSViewRepresentable {
    let onSearch: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = SearchKeyMonitorView()
        view.onSearch = onSearch
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? SearchKeyMonitorView)?.onSearch = onSearch
    }

    class SearchKeyMonitorView: NSView {
        var onSearch: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }

                // "/" without modifiers (only when no text field active)
                if event.charactersIgnoringModifiers == "/" &&
                   event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [] {
                    if !self.isTextFieldActive {
                        DispatchQueue.main.async { self.onSearch?() }
                        return nil
                    }
                }

                return event
            }
        }

        private var isTextFieldActive: Bool {
            guard let firstResponder = window?.firstResponder else { return false }
            return firstResponder is NSTextView || firstResponder is NSTextField
        }

        override func removeFromSuperview() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            super.removeFromSuperview()
        }
    }
}
