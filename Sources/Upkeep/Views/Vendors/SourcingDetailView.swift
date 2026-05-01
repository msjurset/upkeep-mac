import SwiftUI

struct SourcingDetailView: View {
    @Environment(UpkeepStore.self) private var store
    let sourcing: Sourcing
    @State private var showEditSourcingSheet = false
    @State private var showAddCandidateSheet = false
    @State private var editCandidate: Candidate?
    @State private var showHireSheet = false
    @State private var showCancelSheet = false
    @State private var cancelReason = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(20)

                Divider()

                metadata
                    .padding(20)

                if !sourcing.notes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        MarkdownNotesView(text: sourcing.notes)
                    }
                    .padding(20)
                }

                if !sourcing.cancelReason.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cancel Reason")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(sourcing.cancelReason)
                            .font(.body)
                    }
                    .padding(20)
                }

                Divider()

                candidatesSection
                    .padding(20)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if sourcing.isOpen {
                    Button {
                        showHireSheet = true
                    } label: {
                        Label("Hire…", systemImage: "checkmark.seal")
                    }
                    .help("Close this sourcing by hiring a candidate")
                    .disabled(!hasHireableCandidate)

                    Button {
                        showCancelSheet = true
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                    .help("Close this sourcing without hiring")
                }

                Button {
                    showEditSourcingSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showEditSourcingSheet) {
            SourcingEditorSheet(sourcing: sourcing)
        }
        .sheet(isPresented: $showAddCandidateSheet) {
            CandidateEditorSheet(sourcingID: sourcing.id, candidate: nil)
        }
        .sheet(item: $editCandidate) { candidate in
            CandidateEditorSheet(sourcingID: sourcing.id, candidate: candidate)
        }
        .sheet(isPresented: $showHireSheet) {
            HireSheet(sourcing: sourcing)
        }
        .sheet(isPresented: $showCancelSheet) {
            cancelSheet
        }
        .confirmationDialog("Delete this sourcing?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                store.deleteSourcing(id: sourcing.id)
                store.selectedSourcingID = nil
            }
        } message: {
            Text("This permanently removes the sourcing and its candidate snapshot. Vendor records already promoted from this sourcing are not affected.")
        }
    }

    private var hasHireableCandidate: Bool {
        sourcing.candidates.contains { $0.status.reachedQuoted }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 36))
                    .foregroundStyle(iconColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sourcing.title)
                        .font(.title2.weight(.semibold))
                    Text(statusLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var statusLabel: String {
        switch sourcing.status {
        case .open:
            if let decideBy = sourcing.decideBy {
                return "Open — decide by \(decideBy.shortDate)"
            }
            return "Open"
        case .decided:
            if let hired = sourcing.hiredCandidate {
                return "Decided — hired \(hired.name)"
            }
            return "Decided"
        case .cancelled:
            return "Cancelled"
        }
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

    @ViewBuilder
    private var metadata: some View {
        VStack(alignment: .leading, spacing: 10) {
            let linkedItems = sourcing.linkedItemIDs.compactMap { id in
                store.items.first { $0.id == id }
            }
            if !linkedItems.isEmpty {
                ForEach(Array(linkedItems.enumerated()), id: \.element.id) { idx, item in
                    Button {
                        store.recordHistory()
                        store.navigation = .inventoryAll
                        store.selectedItemID = item.id
                    } label: {
                        metadataRow(
                            icon: "wrench.and.screwdriver",
                            label: idx == 0 ? "For items" : "",
                            value: item.name,
                            isLink: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            if let replacingID = sourcing.replacingVendorID,
               let v = store.vendors.first(where: { $0.id == replacingID }) {
                Button {
                    store.recordHistory()
                    store.vendorsTab = .vendors
                    store.selectedVendorID = v.id
                } label: {
                    metadataRow(icon: "arrow.triangle.swap", label: "Replacing", value: v.name, isLink: true)
                }
                .buttonStyle(.plain)

                let count = store.itemsAffectedOnHire(sourcing).count
                if count > 0 && sourcing.isOpen {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        Text("Hiring will reassign \(count) item\(count == 1 ? "" : "s") to the new vendor.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            if sourcing.linkedItemIDs.isEmpty && sourcing.replacingVendorID == nil {
                metadataRow(icon: "magnifyingglass", label: "Standalone", value: "Not tied to an item or existing vendor")
            }
        }
    }

    private func metadataRow(icon: String, label: String, value: String, isLink: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.upkeepAmber)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.body)
                .foregroundStyle(isLink ? .upkeepAmber : .primary)
            if isLink {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    private var candidatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Candidates")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                if sourcing.isOpen {
                    Button {
                        showAddCandidateSheet = true
                    } label: {
                        Label("Add Candidate", systemImage: "plus")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if sourcing.candidates.isEmpty {
                Text("No candidates yet — add the people you're considering")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    candidateHeaderRow
                    Divider()
                    ForEach(sortedCandidates) { candidate in
                        candidateRow(candidate)
                        Divider()
                    }
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator.opacity(0.3)))
            }
        }
    }

    private var sortedCandidates: [Candidate] {
        sourcing.candidates.sorted { $0.status.sortOrder < $1.status.sortOrder }
    }

    private var candidateHeaderRow: some View {
        HStack(spacing: 8) {
            Text("Name").font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Source").font(.caption).foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text("Status").font(.caption).foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text("Quote").font(.caption).foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text("Files").font(.caption).foregroundStyle(.secondary)
                .frame(width: 50, alignment: .center)
            Spacer().frame(width: 24)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func candidateRow(_ candidate: Candidate) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(candidate.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if !candidate.phone.isEmpty || !candidate.email.isEmpty {
                    Text(candidate.phone.isEmpty ? candidate.email : candidate.phone)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(candidate.source.isEmpty ? "—" : candidate.source)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)

            statusPill(candidate.status)
                .frame(width: 100, alignment: .leading)

            Text(quoteString(candidate.quoteAmount))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)

            Text(candidate.attachments.isEmpty ? "—" : "\(candidate.attachments.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .center)

            Menu {
                Button("Edit…") { editCandidate = candidate }
                if sourcing.isOpen {
                    Divider()
                    ForEach(CandidateStatus.allCases, id: \.self) { status in
                        Button(status.label) {
                            var updated = candidate
                            updated.status = status
                            store.updateCandidate(updated, in: sourcing.id, actionName: "Set Status")
                        }
                        .disabled(candidate.status == status || status == .hired)
                    }
                    Divider()
                    Button("Remove", role: .destructive) {
                        store.removeCandidate(candidate.id, from: sourcing.id)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 24)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(sourcing.hiredCandidateID == candidate.id ? Color.green.opacity(0.08) : .clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            editCandidate = candidate
        }
    }

    private func statusPill(_ status: CandidateStatus) -> some View {
        Text(status.label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(statusTint(status).opacity(0.18)))
            .foregroundStyle(statusTint(status))
    }

    private func statusTint(_ status: CandidateStatus) -> Color {
        switch status {
        case .notContacted: .secondary
        case .contacted: .blue
        case .quoted: .upkeepAmber
        case .declined: .red
        case .hired: .green
        }
    }

    private func quoteString(_ amount: Decimal?) -> String {
        guard let amount else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "—"
    }

    private var cancelSheet: some View {
        EditorSheet(
            title: "Cancel Sourcing",
            saveLabel: "Cancel Sourcing",
            onSave: {
                store.cancelSourcing(sourcing.id, reason: cancelReason.trimmingCharacters(in: .whitespaces))
            }
        ) {
            Section {
                Text("Closes this sourcing without hiring anyone. Useful if you decided not to do the work, or want to revisit later.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("Reason (optional)") {
                TextEditor(text: $cancelReason)
                    .frame(minHeight: 80)
                    .font(.body)
            }
        }
        .frame(width: 440, height: 320)
    }
}
