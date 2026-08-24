import SwiftUI

struct ProceduresContainerView: View {
    @Environment(UpkeepStore.self) private var store

    @State private var selectedPhase: ProcedurePhase? = nil
    @State private var showNewProcedureSheet = false
    @State private var dropTargetProcedureID: UUID?
    @State private var activePropertyIDs: Set<UUID> = []

    private var filteredProcedures: [Procedure] {
        let sorted = store.procedures.sorted(by: { $0.sortOrder < $1.sortOrder })
        let propertyFiltered = sorted.filter { proc in
            if activePropertyIDs.isEmpty { return true }
            if proc.propertyIDs.isEmpty { return true }
            return proc.propertyIDs.contains(where: { activePropertyIDs.contains($0) })
        }
        guard let selectedPhase else { return propertyFiltered }
        return propertyFiltered.filter { $0.phase == selectedPhase }
    }

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            // Conflated 1-Line Header Bar with Property Toggles, Season Dropdown & New Procedure Menu
            HStack(spacing: 12) {
                // Property Toggle Pills
                HStack(spacing: 6) {
                    ForEach(store.properties) { p in
                        let isSelected = activePropertyIDs.contains(p.id)
                        let count = countForProperty(p.id)

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if isSelected {
                                    if activePropertyIDs.count > 1 {
                                        activePropertyIDs.remove(p.id)
                                    }
                                } else {
                                    activePropertyIDs.insert(p.id)
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                PropertyIconView(p.icon, font: .caption2)
                                    .foregroundStyle(isSelected ? .white : .primary)

                                Text(p.name)
                                    .font(.caption.weight(isSelected ? .semibold : .medium))
                                    .foregroundStyle(isSelected ? .white : .primary)

                                if count > 0 {
                                    Text("\(count)")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(isSelected ? Color.white.opacity(0.25) : Color.secondary.opacity(0.12))
                                        .foregroundStyle(isSelected ? .white : .secondary)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isSelected ? Color.upkeepAmber : Color.secondary.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                    .frame(height: 18)

                // Season Dropdown Picker
                Picker("Season", selection: $selectedPhase) {
                    Text("All Seasons").tag(ProcedurePhase?.none)
                    Divider()
                    ForEach(ProcedurePhase.allCases) { phase in
                        Label(phase.label, systemImage: phase.icon).tag(Optional(phase))
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)

                Spacer()

                // New Procedure Button Menu
                Menu {
                    Button {
                        showNewProcedureSheet = true
                    } label: {
                        Label("Custom Procedure...", systemImage: "plus")
                    }

                    Divider()

                    ForEach(Procedure.builtInTemplates) { tmpl in
                        Button {
                            let firstPropID = activePropertyIDs.first ?? store.selectedPropertyID ?? store.primaryProperty?.id
                            let p = tmpl.create(firstPropID)
                            store.saveProcedure(p)
                        } label: {
                            Label(tmpl.title, systemImage: tmpl.icon)
                        }
                    }
                } label: {
                    Label("New Procedure", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            if filteredProcedures.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "checklist.checked")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.upkeepAmber.opacity(0.6))

                    Text("No procedures for selected filters")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text("Procedures help you execute multi-step workflows like winterizing your Lake House, spring openings, or seasonal home inspections.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)

                    HStack(spacing: 10) {
                        ForEach(Procedure.builtInTemplates) { tmpl in
                            Button {
                                let firstPropID = activePropertyIDs.first ?? store.selectedPropertyID ?? store.primaryProperty?.id
                                let p = tmpl.create(firstPropID)
                                store.saveProcedure(p)
                            } label: {
                                Label(tmpl.title, systemImage: tmpl.icon)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                    }
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(filteredProcedures) { proc in
                            VStack(spacing: 0) {
                                // Glowing drop indicator line when dragging over a target
                                if dropTargetProcedureID == proc.id {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.upkeepAmber)
                                            .frame(width: 6, height: 6)
                                        Rectangle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.upkeepAmber, .upkeepAmber.opacity(0.6)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(height: 3)
                                            .shadow(color: .upkeepAmber.opacity(0.8), radius: 4, x: 0, y: 0)
                                        Circle()
                                            .fill(Color.upkeepAmber)
                                            .frame(width: 6, height: 6)
                                    }
                                    .padding(.bottom, 6)
                                    .transition(.opacity.combined(with: .scale))
                                }

                                ProcedureChecklistView(procedure: proc)
                            }
                            .padding(.top, dropTargetProcedureID == proc.id ? 10 : 0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dropTargetProcedureID)
                            .draggable(proc.id.uuidString)
                            .dropDestination(for: String.self) { droppedIDs, _ in
                                dropTargetProcedureID = nil
                                guard let droppedID = droppedIDs.first,
                                      let draggedUUID = UUID(uuidString: droppedID) else { return false }
                                store.moveProcedureCard(id: draggedUUID, before: proc.id)
                                return true
                            } isTargeted: { targeted in
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    dropTargetProcedureID = targeted ? proc.id : (dropTargetProcedureID == proc.id ? nil : dropTargetProcedureID)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Procedures")
        .sheet(isPresented: $showNewProcedureSheet) {
            ProcedureEditorSheet(procedure: nil)
        }
        .onAppear {
            if activePropertyIDs.isEmpty {
                if let sel = store.selectedPropertyID {
                    activePropertyIDs = [sel]
                } else {
                    activePropertyIDs = Set(store.properties.map(\.id))
                }
            }
        }
    }

    private func countForProperty(_ propertyID: UUID) -> Int {
        store.procedures.filter { $0.propertyIDs.isEmpty || $0.propertyIDs.contains(propertyID) }.count
    }
}
