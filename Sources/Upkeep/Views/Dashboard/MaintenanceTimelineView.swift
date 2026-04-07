import SwiftUI

// MARK: - MaintenanceTimelineView

/// A horizontal scrollable timeline showing completed maintenance (left of "Now")
/// and upcoming/overdue items (right of "Now"). The view centers on the "Now" divider
/// on first appearance.
///
/// **Scrolling is handled three ways:**
/// 1. Click-and-drag anywhere in the timeline (`.simultaneousGesture`)
/// 2. Mouse wheel / trackpad via a local `NSEvent` monitor (`TimelineScrollWheelView`)
/// 3. Arrow buttons at the leading/trailing edges that page by half the viewport width
///
/// **Layout approach:**
/// The content is an `HStack` with `.fixedSize()` (wider than the viewport), shifted by
/// `.offset(x: -scrollOffset)`, then constrained to the viewport via `.frame(width: vw)`
/// and `.clipped()`. Arrow overlays are added *after* clipping so they anchor to viewport
/// edges rather than content edges.
///
/// **Stable identity:**
/// `TimelineEntry.id` is derived from the underlying log/item UUID (not regenerated per
/// render) so SwiftUI can diff correctly, enabling smooth drag updates and arrow animations.
struct MaintenanceTimelineView: View {
    @Environment(UpkeepStore.self) private var store

    // MARK: Layout Constants

    /// Width of each pill (completed entry or upcoming item).
    private let pillWidth: CGFloat = 160
    /// Spacing between adjacent items in the HStack (also used for edge padding).
    private let pillSpacing: CGFloat = 22
    /// Width of the "Now" divider column.
    private let nowDividerWidth: CGFloat = 40
    /// Width of the hollow end-of-line terminal dots.
    private let terminalWidth: CGFloat = 20
    /// Total height of the timeline widget.
    private let timelineHeight: CGFloat = 130
    /// Y-offset from the top of the frame to the center of timeline dots and the
    /// horizontal connecting line. All vertical positioning derives from this value —
    /// changing it shifts the dots, line, and terminal markers together.
    private let dotCenterY: CGFloat = 30

    // MARK: Scroll State

    /// Current horizontal scroll offset (0 = scrolled to the start).
    @State private var scrollOffset: CGFloat = 0
    /// Snapshot of `scrollOffset` at drag start, used to compute translation deltas.
    @State private var dragStartOffset: CGFloat = 0
    /// Cached viewport width for arrow-paging calculations.
    @State private var viewWidth: CGFloat = 0
    /// Guards one-time scroll-to-center on first appearance.
    @State private var hasScrolledToNow = false

    // MARK: Body

    @ViewBuilder
    var body: some View {
        let entries = timelineEntries
        // The now-divider is always present; show only when there's real content beside it.
        if entries.count > 1 {
            GeometryReader { geo in
                let vw = geo.size.width
                let cw = contentWidth(entries: entries)
                let maxOffset = max(0, cw - vw)

                timelineContent(entries: entries)
                    // Let the HStack take its natural (wider-than-viewport) width.
                    .fixedSize(horizontal: true, vertical: false)
                    // Shift content left by scrollOffset to simulate horizontal scrolling.
                    .offset(x: -scrollOffset)
                    // Constrain the visible area to the viewport and clip overflow.
                    .frame(width: vw, height: timelineHeight, alignment: .topLeading)
                    .clipped()
                    // Make the entire clipped rectangle draggable, not just the pills.
                    .contentShape(Rectangle())
                    // Use .simultaneousGesture so pill Button taps still fire on click
                    // while drags (>5px movement) pan the timeline.
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                scrollOffset = clamp(dragStartOffset - value.translation.width, max: maxOffset)
                            }
                            .onEnded { _ in
                                dragStartOffset = scrollOffset
                            }
                    )
                    // Arrows are overlays on the *clipped* frame so they sit at viewport edges.
                    .overlay(alignment: .leading) {
                        scrollArrow(direction: .left, maxOffset: maxOffset)
                            .padding(.leading, 4)
                    }
                    .overlay(alignment: .trailing) {
                        scrollArrow(direction: .right, maxOffset: maxOffset)
                            .padding(.trailing, 4)
                    }
                    // NSView background establishes bounds for the local scroll-wheel monitor.
                    .background {
                        TimelineScrollWheelView { deltaX in
                            let proposed = scrollOffset - deltaX
                            scrollOffset = clamp(proposed, max: maxOffset)
                            dragStartOffset = scrollOffset
                        }
                    }
                    .onAppear {
                        viewWidth = vw
                        scrollToNow(entries: entries, viewWidth: vw, maxOffset: maxOffset)
                    }
                    .onChange(of: geo.size.width) { _, newWidth in
                        viewWidth = newWidth
                        let newMax = max(0, cw - newWidth)
                        scrollOffset = min(scrollOffset, newMax)
                        dragStartOffset = scrollOffset
                    }
            }
            .frame(height: timelineHeight)
        }
    }

    // MARK: - Layout Calculations

    private func entryWidth(_ entry: TimelineEntry) -> CGFloat {
        entry.kind == .nowDivider ? nowDividerWidth : pillWidth
    }

    /// Total width of the scrollable content: terminal + entries + terminal.
    /// Must mirror the HStack layout exactly (items + inter-item gaps + edge padding + terminals).
    private func contentWidth(entries: [TimelineEntry]) -> CGFloat {
        let itemWidths = entries.reduce(CGFloat(0)) { $0 + entryWidth($1) }
        let gaps = CGFloat(entries.count - 1) * pillSpacing
        let edges = pillSpacing * 2           // .padding(.horizontal, pillSpacing)
        let terminals = (terminalWidth + pillSpacing) * 2  // dot + gap on each end
        return itemWidths + gaps + edges + terminals
    }

    /// X-coordinate of the now-divider's center within the content, for initial scroll centering.
    private func nowDividerCenter(entries: [TimelineEntry]) -> CGFloat {
        // Start after: edge padding + leading terminal + gap
        var x: CGFloat = pillSpacing + terminalWidth + pillSpacing
        for entry in entries {
            let w = entryWidth(entry)
            if entry.kind == .nowDivider { return x + w / 2 }
            x += w + pillSpacing
        }
        return x
    }

    /// Centers the viewport on the "Now" divider on first appearance (no animation).
    private func scrollToNow(entries: [TimelineEntry], viewWidth: CGFloat, maxOffset: CGFloat) {
        guard !hasScrolledToNow else { return }
        let center = nowDividerCenter(entries: entries)
        scrollOffset = clamp(center - viewWidth / 2, max: maxOffset)
        dragStartOffset = scrollOffset
        hasScrolledToNow = true
    }

    private func clamp(_ value: CGFloat, max maxVal: CGFloat) -> CGFloat {
        max(0, min(value, maxVal))
    }

    // MARK: - Timeline Content

    /// The full-width HStack: [terminal] [entries...] [terminal], with a horizontal line behind it.
    private func timelineContent(entries: [TimelineEntry]) -> some View {
        HStack(alignment: .top, spacing: pillSpacing) {
            terminalDot

            ForEach(entries) { entry in
                if entry.kind == .nowDivider {
                    nowDivider
                } else {
                    timelinePill(entry: entry)
                        .frame(width: pillWidth)
                }
            }

            terminalDot
        }
        .padding(.horizontal, pillSpacing)
        .frame(height: timelineHeight, alignment: .top)
        .background(alignment: .topLeading) {
            // Horizontal connecting line, vertically centered on dotCenterY.
            Rectangle()
                .fill(.separator.opacity(0.6))
                .frame(height: 3)
                .offset(y: dotCenterY - 1.5)
        }
    }

    // MARK: - Terminal Dot

    /// Hollow circle at each end of the timeline indicating no further content.
    private var terminalDot: some View {
        VStack(spacing: 0) {
            // Push the circle down to align its center with dotCenterY.
            Spacer().frame(height: dotCenterY - 5)

            ZStack {
                // Opaque disc to mask the line behind the dot.
                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(width: 14, height: 14)
                Circle()
                    .strokeBorder(.separator.opacity(0.5), lineWidth: 2)
                    .frame(width: 10, height: 10)
            }
            .frame(height: 10)

            Spacer(minLength: 0)
        }
        .frame(width: terminalWidth, height: timelineHeight)
    }

    // MARK: - Pill

    /// A single timeline entry: date label, colored dot on the line, and a tinted pill card.
    /// Clicking navigates to the log entry (completed) or inventory item (upcoming/overdue).
    private func timelinePill(entry: TimelineEntry) -> some View {
        let isCompleted = entry.kind == .completed
        let isOverdue = entry.kind == .overdue
        let tint = entry.categoryColor

        return VStack(spacing: 0) {
            // Date label above the dot — height sized to place the dot center at dotCenterY.
            Text(entry.dateText)
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(isOverdue ? .upkeepRed : .secondary)
                .lineLimit(1)
                .frame(height: dotCenterY - 11)

            // Colored dot sitting on the horizontal timeline line.
            ZStack {
                // Opaque disc masks the line behind the dot.
                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(isOverdue ? Color.upkeepRed : tint)
                    .frame(width: 8, height: 8)
            }
            .frame(height: 14)
            .padding(.bottom, 6)

            // Pill card body.
            Button {
                navigateTo(entry)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: entry.icon)
                            .font(.system(size: 9))
                            .foregroundStyle(tint)
                        Text(entry.title)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }

                    if let subtitle = entry.subtitle {
                        Text(subtitle)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background {
                    // Opaque base prevents the timeline line from showing through,
                    // then a translucent category tint is layered on top.
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .windowBackgroundColor))
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isCompleted ? tint.opacity(0.08) : isOverdue ? Color.upkeepRed.opacity(0.08) : tint.opacity(0.06))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isOverdue ? Color.upkeepRed.opacity(0.3) : tint.opacity(isCompleted ? 0.2 : 0.15),
                            lineWidth: 0.5
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Now Divider

    /// Amber "Now" marker at the boundary between completed history and future items.
    private var nowDivider: some View {
        VStack(spacing: 0) {
            Text("Now")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.upkeepAmber)
                .frame(height: dotCenterY - 11)

            ZStack {
                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(Color.upkeepAmber)
                    .frame(width: 10, height: 10)
            }
            .frame(height: 14)
            .padding(.bottom, 6)

            Rectangle()
                .fill(Color.upkeepAmber.opacity(0.3))
                .frame(width: 1, height: 40)

            Spacer(minLength: 0)
        }
        .frame(width: nowDividerWidth, height: timelineHeight)
    }

    // MARK: - Scroll Arrows

    private enum ArrowDirection { case left, right }

    /// Translucent paging arrow that scrolls by half the viewport width per click.
    /// Fades to near-invisible and disables hit testing when no further scrolling is possible.
    private func scrollArrow(direction: ArrowDirection, maxOffset: CGFloat) -> some View {
        let enabled = canScroll(direction: direction, maxOffset: maxOffset)
        return Button {
            withAnimation(.easeInOut(duration: 0.35)) {
                let half = viewWidth / 2
                if direction == .left {
                    scrollOffset = max(0, scrollOffset - half)
                } else {
                    scrollOffset = min(maxOffset, scrollOffset + half)
                }
                dragStartOffset = scrollOffset
            }
        } label: {
            Image(systemName: direction == .left ? "chevron.left" : "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 0.7 : 0.15)
        .allowsHitTesting(enabled)
    }

    /// A 1px tolerance avoids floating-point edge cases at the scroll bounds.
    private func canScroll(direction: ArrowDirection, maxOffset: CGFloat) -> Bool {
        switch direction {
        case .left: return scrollOffset > 1
        case .right: return scrollOffset < maxOffset - 1
        }
    }

    // MARK: - Navigation

    /// Clicking a pill navigates to the relevant detail view.
    private func navigateTo(_ entry: TimelineEntry) {
        switch entry.kind {
        case .completed:
            if let logID = entry.logEntryID {
                store.selectedLogEntryID = logID
                store.navigation = .log
            }
        case .upcoming, .overdue:
            if let itemID = entry.itemID {
                store.selectedItemID = itemID
                store.navigation = .inventoryAll
            }
        case .nowDivider:
            break
        }
    }

    // MARK: - Data Assembly

    /// Builds the ordered timeline: completed log entries (oldest-first) → Now → overdue → upcoming.
    private var timelineEntries: [TimelineEntry] {
        var entries: [TimelineEntry] = []

        // Past: completed log entries, oldest to newest (reading left-to-right).
        let completed = store.logEntries
            .sorted { $0.completedDate < $1.completedDate }

        for log in completed {
            let itemName = log.itemID.flatMap { id in store.items.first { $0.id == id }?.name }
            entries.append(TimelineEntry(
                kind: .completed,
                stableID: "log-\(log.id.uuidString)",
                title: log.title,
                subtitle: itemName ?? log.performedBy,
                date: log.completedDate,
                icon: log.category.icon,
                categoryColor: Color.categoryColor(log.category),
                logEntryID: log.id,
                itemID: log.itemID
            ))
        }

        // Center divider
        entries.append(TimelineEntry(
            kind: .nowDivider,
            stableID: "now-divider",
            title: "",
            subtitle: nil,
            date: .now,
            icon: "",
            categoryColor: .clear,
            logEntryID: nil,
            itemID: nil
        ))

        // Future: overdue items first (sorted by due date), then upcoming items.
        let overdueItems = store.overdueItems
            .sorted { store.nextDueDate(for: $0) < store.nextDueDate(for: $1) }
        let upcomingItems = store.upcomingItems
            .sorted { store.nextDueDate(for: $0) < store.nextDueDate(for: $1) }

        for item in overdueItems {
            entries.append(TimelineEntry(
                kind: .overdue,
                stableID: "item-\(item.id.uuidString)",
                title: item.name,
                subtitle: item.frequencyDescription,
                date: store.nextDueDate(for: item),
                icon: item.category.icon,
                categoryColor: Color.categoryColor(item.category),
                logEntryID: nil,
                itemID: item.id
            ))
        }

        for item in upcomingItems {
            entries.append(TimelineEntry(
                kind: .upcoming,
                stableID: "item-\(item.id.uuidString)",
                title: item.name,
                subtitle: item.frequencyDescription,
                date: store.nextDueDate(for: item),
                icon: item.category.icon,
                categoryColor: Color.categoryColor(item.category),
                logEntryID: nil,
                itemID: item.id
            ))
        }

        return entries
    }
}

// MARK: - TimelineEntry

/// Lightweight value type unifying completed log entries and upcoming maintenance items
/// into a single timeline sequence. Uses a stable string ID derived from the underlying
/// data model's UUID so SwiftUI can track identity across re-renders.
private struct TimelineEntry: Identifiable {
    enum Kind: Equatable {
        case completed  // Past: a LogEntry that was performed
        case nowDivider // Center marker separating past from future
        case overdue    // Future: a MaintenanceItem past its due date
        case upcoming   // Future: a MaintenanceItem not yet due
    }

    let kind: Kind
    let stableID: String
    let title: String
    let subtitle: String?
    let date: Date
    let icon: String
    let categoryColor: Color
    let logEntryID: UUID?   // Non-nil for .completed entries
    let itemID: UUID?       // Non-nil for .completed (if linked), .overdue, .upcoming

    var id: String { stableID }

    var dateText: String { date.shortDate }
}

// MARK: - TimelineScrollWheelView

/// An `NSViewRepresentable` placed as a `.background` to establish a frame for
/// bounds-checking scroll wheel events. It installs a **local event monitor** that
/// intercepts `scrollWheel` events before the parent `ScrollView` (the dashboard)
/// can consume them, enabling horizontal scrolling over the timeline area.
///
/// **Trackpad vs. mouse wheel behavior:**
/// - Trackpad (precise deltas): horizontal swipes scroll the timeline; vertical swipes
///   pass through so the dashboard `ScrollView` can scroll normally.
/// - Mouse wheel (discrete deltas): vertical wheel is mapped to horizontal timeline scroll
///   since the timeline has no vertical axis.
private struct TimelineScrollWheelView: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> TimelineScrollWheelNSView {
        let view = TimelineScrollWheelNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: TimelineScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
    }

    final class TimelineScrollWheelNSView: NSView {
        var onScroll: ((CGFloat) -> Void)?
        private var scrollMonitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil, scrollMonitor == nil else { return }

            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, self.window != nil else { return event }
                let loc = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(loc) else { return event }

                if event.hasPreciseScrollingDeltas {
                    // Trackpad: only claim horizontal-dominant swipes.
                    if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY),
                       abs(event.scrollingDeltaX) > 0.5 {
                        self.onScroll?(event.scrollingDeltaX)
                        return nil // consumed
                    }
                    return event // vertical trackpad → dashboard scroll
                } else {
                    // Mouse wheel: map vertical to horizontal.
                    if abs(event.scrollingDeltaY) > 0.1 {
                        self.onScroll?(event.scrollingDeltaY)
                        return nil
                    }
                    return event
                }
            }
        }

        override func removeFromSuperview() {
            if let m = scrollMonitor {
                NSEvent.removeMonitor(m)
                scrollMonitor = nil
            }
            super.removeFromSuperview()
        }
    }
}
