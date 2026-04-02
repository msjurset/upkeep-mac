import SwiftUI

struct ConflictBanner: View {
    @Environment(UpkeepStore.self) private var store

    var body: some View {
        if !store.conflicts.isEmpty {
            VStack(spacing: 0) {
                ForEach(store.conflicts) { conflict in
                    ConflictRow(conflict: conflict)
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct ConflictRow: View {
    @Environment(UpkeepStore.self) private var store
    let conflict: Conflict

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("\"\(conflict.entityName)\" was changed")
                    .font(.callout.weight(.medium))

                let who = store.memberName(for: conflict.theirModifiedBy) ?? "Someone"
                Text("\(who) updated this \(conflict.kind.rawValue) (v\(conflict.ourVersion) → v\(conflict.theirVersion))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Keep theirs") {
                withAnimation {
                    store.acceptTheirVersion(conflict: conflict)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Keep mine") {
                withAnimation {
                    store.revertToOurVersion(conflict: conflict)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.upkeepAmber)
            .controlSize(.small)

            Button {
                withAnimation {
                    store.dismissConflict(id: conflict.id)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(12)
    }
}
