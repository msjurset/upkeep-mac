import SwiftUI

struct SourcingListView: View {
    @Environment(UpkeepStore.self) private var store
    @Binding var showNewSourcingSheet: Bool

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            HStack {
                Spacer()
                addButton { showNewSourcingSheet = true }
                    .help("New sourcing")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            List(selection: $store.selectedSourcingID) {
                ForEach(Array(sortedSourcings.enumerated()), id: \.element.id) { index, sourcing in
                    SourcingRow(sourcing: sourcing)
                        .tag(sourcing.id)
                        .listRowBackground(index.isMultiple(of: 2) ? Color.clear : Color.alternatingRow)
                        .listRowSeparator(.hidden)
                        .contextMenu {
                            if sourcing.isOpen {
                                Button("Cancel Sourcing") {
                                    store.cancelSourcing(sourcing.id)
                                }
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                store.deleteSourcing(id: sourcing.id)
                            }
                        }
                }
            }
            .listStyle(.inset)
        }
        .overlay {
            if store.sourcings.isEmpty {
                EmptyListOverlay(
                    icon: "magnifyingglass",
                    title: "No sourcing in progress",
                    message: "Track bids and vendor candidates before assigning",
                    buttonLabel: "New Sourcing"
                ) { showNewSourcingSheet = true }
            }
        }
    }

    /// Open first (by decideBy ascending if set, else updatedAt desc),
    /// then cancelled/decided by updatedAt desc.
    private var sortedSourcings: [Sourcing] {
        let open = store.sourcings.filter(\.isOpen).sorted { a, b in
            switch (a.decideBy, b.decideBy) {
            case let (lhs?, rhs?): return lhs < rhs
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.updatedAt > b.updatedAt
            }
        }
        let closed = store.sourcings.filter { !$0.isOpen }.sorted { $0.updatedAt > $1.updatedAt }
        return open + closed
    }
}

struct SourcingRow: View {
    @Environment(UpkeepStore.self) private var store
    let sourcing: Sourcing

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(sourcing.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(sourcing.isOpen ? .primary : .secondary)
                    if sourcing.status == .decided {
                        Text("Decided")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.green.opacity(0.2)))
                    } else if sourcing.status == .cancelled {
                        Text("Cancelled")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.red.opacity(0.2)))
                    } else if sourcing.daysSinceLastActivity >= 30 {
                        Text("Stale")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.orange.opacity(0.2)))
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    Text("\(sourcing.candidates.count) candidate\(sourcing.candidates.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    VStack(alignment: .leading, spacing: 1) {
                        if let decideBy = sourcing.decideBy, sourcing.isOpen {
                            Text("Decide by \(decideBy.shortDate)")
                                .lineLimit(1)
                        }
                        if let replacingID = sourcing.replacingVendorID,
                           let v = store.vendors.first(where: { $0.id == replacingID }) {
                            Text("Replacing \(v.name)")
                                .lineLimit(1)
                        } else {
                            let linkedNames = sourcing.linkedItemIDs.compactMap { id in
                                store.items.first { $0.id == id }?.name
                            }
                            if !linkedNames.isEmpty {
                                Text(linkedNames.count == 1
                                    ? linkedNames[0]
                                    : "\(linkedNames[0]) +\(linkedNames.count - 1) more")
                                    .lineLimit(1)
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .opacity(sourcing.isOpen ? 1.0 : 0.7)
    }

    private var iconName: String {
        switch sourcing.status {
        case .open: "magnifyingglass.circle.fill"
        case .decided: "checkmark.circle.fill"
        case .cancelled: "xmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch sourcing.status {
        case .open: .upkeepAmber
        case .decided: .green
        case .cancelled: .secondary
        }
    }
}
