import SwiftUI

struct HireSheet: View {
    @Environment(UpkeepStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let sourcing: Sourcing

    @State private var winnerID: UUID?
    @State private var savedNoShows: Set<UUID> = []

    private var hireableCandidates: [Candidate] {
        sourcing.candidates.filter { $0.status.reachedQuoted }
    }

    private var noShowCandidates: [Candidate] {
        sourcing.candidates.filter { !$0.status.reachedQuoted }
    }

    private var cascadeItems: [MaintenanceItem] {
        store.itemsAffectedOnHire(sourcing)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Hire a Candidate")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select the winning candidate. The winner becomes an active vendor. Quoted losers become inactive vendors automatically — you'll still find them in the Vendors tab with \"Show inactive\" on.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if !cascadeItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.swap")
                                    .foregroundStyle(.upkeepAmber)
                                Text("\(cascadeItems.count) item\(cascadeItems.count == 1 ? "" : "s") will be reassigned to the winner")
                                    .font(.callout.weight(.medium))
                            }
                            ForEach(cascadeItems) { item in
                                HStack(spacing: 6) {
                                    Image(systemName: item.effectiveIcon)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(item.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 22)
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.upkeepAmber.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.upkeepAmber.opacity(0.3)))
                    }

                    Text("Hireable candidates")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if hireableCandidates.isEmpty {
                        Text("No candidates have reached \"Quoted\" yet. Update at least one candidate's status before hiring.")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(hireableCandidates) { candidate in
                                HireRow(
                                    candidate: candidate,
                                    isSelected: winnerID == candidate.id
                                )
                                .onTapGesture { winnerID = candidate.id }
                            }
                        }
                    }

                    if !noShowCandidates.isEmpty {
                        Divider()
                        Text("Save no-shows as inactive vendors anyway?")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("By default, candidates that didn't reach \"Quoted\" stay only in the search snapshot. Tick to also create an inactive Vendor record for any of them.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        VStack(spacing: 4) {
                            ForEach(noShowCandidates) { candidate in
                                HStack {
                                    Toggle(isOn: Binding(
                                        get: { savedNoShows.contains(candidate.id) },
                                        set: { isOn in
                                            if isOn { savedNoShows.insert(candidate.id) }
                                            else { savedNoShows.remove(candidate.id) }
                                        }
                                    )) {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(candidate.name)
                                                .font(.body)
                                            Text(candidate.status.label)
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button("Hire") {
                    guard let winnerID else { return }
                    store.hireCandidate(winnerID, in: sourcing.id, extraSavedCandidateIDs: savedNoShows)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.upkeepAmber)
                .disabled(winnerID == nil)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 540, height: 560)
    }
}

private struct HireRow: View {
    let candidate: Candidate
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.name)
                    .font(.body.weight(.medium))
                HStack(spacing: 6) {
                    Text(candidate.status.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let q = candidate.quoteAmount {
                        Text("$\(q.description)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    if !candidate.source.isEmpty {
                        Text(candidate.source)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.green.opacity(0.08) : .clear))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.green : Color.separator, lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(Rectangle())
    }
}

private extension Color {
    static var separator: Color { Color(nsColor: .separatorColor) }
}
