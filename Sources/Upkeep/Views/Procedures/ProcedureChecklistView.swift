import SwiftUI

struct ProcedureChecklistView: View {
    @Environment(UpkeepStore.self) private var store
    let procedure: Procedure

    @State private var isEditing = false
    @State private var addingStep = false
    @State private var newStepText = ""
    @State private var newStepOrder = ""
    @State private var dropTargetStepID: UUID?
    @State private var editingStepID: UUID?
    @State private var editStepText = ""
    @State private var editStepNotes = ""
    @State private var showLogSheet = false
    @State private var showEditProcedureSheet = false
    @State private var procedureCostString = ""
    @State private var performedBy = "Self"

    private var sortedSteps: [ProcedureStep] {
        procedure.steps.sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack(alignment: .center, spacing: 8) {
                if procedure.isCollapsed {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(width: 14)
                }

                Button {
                    store.toggleProcedureCollapse(procedureID: procedure.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: procedure.isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(width: 12)

                        Image(systemName: procedure.phase.icon)
                            .font(.subheadline)
                            .foregroundStyle(procedure.phase.color)

                        Text(procedure.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if store.selectedPropertyID == nil {
                            ForEach(procedure.propertyIDs, id: \.self) { propID in
                                if let prop = store.properties.first(where: { $0.id == propID }) {
                                    HStack(spacing: 3) {
                                        PropertyIconView(prop.icon, font: .caption2)
                                        Text(prop.name)
                                    }
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.upkeepAmber)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.upkeepAmber.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                // Progress indicator
                HStack(spacing: 8) {
                    Text("\(procedure.completedCount)/\(procedure.steps.count) steps")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    ProgressView(value: procedure.progress)
                        .tint(procedure.progress >= 1.0 ? .upkeepGreen : procedure.phase.color)
                        .frame(width: 60)
                }

                // Edit toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isEditing.toggle()
                        if !isEditing { addingStep = false }
                    }
                } label: {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
                        .font(.callout)
                        .foregroundStyle(isEditing ? .upkeepGreen : .secondary)
                }
                .buttonStyle(.plain)
                .help(isEditing ? "Done editing" : "Edit steps")

                // Menu actions
                Menu {
                    Button {
                        showEditProcedureSheet = true
                    } label: {
                        Label("Edit Procedure & Properties...", systemImage: "slider.horizontal.3")
                    }

                    Button {
                        withAnimation { isEditing.toggle() }
                    } label: {
                        Label(isEditing ? "Done Editing Steps" : "Edit Steps Inline", systemImage: "pencil")
                    }

                    Button {
                        showLogSheet = true
                    } label: {
                        Label("Log Run to Journal", systemImage: "square.and.pencil")
                    }

                    Button {
                        store.resetProcedure(procedureID: procedure.id)
                    } label: {
                        Label("Reset All Steps", systemImage: "arrow.counterclockwise")
                    }

                    Divider()

                    Button(role: .destructive) {
                        store.deleteProcedure(id: procedure.id)
                    } label: {
                        Label("Delete Procedure", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(procedure.phase.color.opacity(0.06))

            // Steps section
            if !procedure.isCollapsed {
                VStack(spacing: 0) {
                    ForEach(Array(sortedSteps.enumerated()), id: \.element.id) { index, step in
                        VStack(spacing: 0) {
                            // Drop indicator line for drag-and-drop step reordering
                            if isEditing && dropTargetStepID == step.id {
                                Rectangle()
                                    .fill(procedure.phase.color)
                                    .frame(height: 2)
                                    .padding(.horizontal, 12)
                            }

                            HStack(alignment: .top, spacing: 10) {
                                // Drag handle vs Step number
                                if isEditing {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 20, alignment: .center)
                                } else {
                                    Text("\(index + 1)")
                                        .font(.caption2.monospacedDigit().weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 20, alignment: .trailing)
                                }

                                // Checkbox toggle
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                        store.toggleProcedureStep(procedureID: procedure.id, stepID: step.id)
                                    }
                                } label: {
                                    Image(systemName: step.isComplete ? "checkmark.square.fill" : "square")
                                        .font(.title3)
                                        .foregroundStyle(step.isComplete ? Color.upkeepGreen : Color.secondary)
                                }
                                .buttonStyle(.plain)

                                // Step text & notes
                                if editingStepID == step.id {
                                    VStack(alignment: .leading, spacing: 4) {
                                        TextField("Step description", text: $editStepText)
                                            .font(.callout)
                                            .textFieldStyle(.roundedBorder)
                                            .onSubmit { saveStepEdit(step: step) }

                                        TextField("Notes / details (optional)", text: $editStepNotes)
                                            .font(.caption)
                                            .textFieldStyle(.roundedBorder)
                                            .foregroundStyle(.secondary)

                                        HStack(spacing: 8) {
                                            Button("Save") { saveStepEdit(step: step) }
                                                .font(.caption2.weight(.medium))
                                                .foregroundStyle(Color.upkeepAmber)

                                            Button("Cancel") { editingStepID = nil }
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(step.text)
                                            .font(.callout)
                                            .strikethrough(step.isComplete)
                                            .foregroundStyle(step.isComplete ? .tertiary : .primary)

                                        if let notes = step.notes, !notes.isEmpty {
                                            Text(notes)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .onTapGesture(count: 2) {
                                        editStepText = step.text
                                        editStepNotes = step.notes ?? ""
                                        editingStepID = step.id
                                    }
                                }

                                Spacer()

                                if isEditing {
                                    Button(role: .destructive) {
                                        store.removeProcedureStep(procedureID: procedure.id, stepID: step.id)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.red.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(index.isMultiple(of: 2) ? Color.secondary.opacity(0.03) : Color.clear)
                            .if(isEditing) { view in
                                view
                                    .draggable(step.id.uuidString)
                                    .dropDestination(for: String.self) { droppedIDs, _ in
                                        dropTargetStepID = nil
                                        guard let droppedID = droppedIDs.first,
                                              let draggedUUID = UUID(uuidString: droppedID) else { return false }
                                        store.moveProcedureStep(procedureID: procedure.id, stepID: draggedUUID, before: step.id)
                                        return true
                                    } isTargeted: { targeted in
                                        dropTargetStepID = targeted ? step.id : (dropTargetStepID == step.id ? nil : dropTargetStepID)
                                    }
                            }
                        }
                    }

                    // Inline add step (edit mode)
                    if isEditing {
                        if addingStep {
                            HStack(spacing: 8) {
                                TextField("#", text: $newStepOrder)
                                    .font(.caption.monospacedDigit())
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 32)

                                TextField("New step...", text: $newStepText)
                                    .font(.callout)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit { commitNewStep() }

                                Button("Add") { commitNewStep() }
                                    .font(.caption)
                                    .disabled(newStepText.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(procedure.phase.color.opacity(0.04))
                        } else {
                            Button {
                                addingStep = true
                                newStepText = ""
                                newStepOrder = "\(procedure.steps.count + 1)"
                            } label: {
                                Label("Add Step", systemImage: "plus.circle")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(procedure.phase.color)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                    }

                    // Bottom completion footer
                    if procedure.completedCount > 0 && !isEditing {
                        Divider()
                        HStack {
                            if procedure.isFullyCompleted {
                                Label("All steps completed!", systemImage: "checkmark.seal.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.upkeepGreen)
                            } else {
                                Text("\(procedure.completedCount) of \(procedure.steps.count) steps done")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                showLogSheet = true
                            } label: {
                                Label("Log to Journal", systemImage: "square.and.pencil")
                                    .font(.caption.weight(.medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(procedure.phase.color)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.03))
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator.opacity(0.4), lineWidth: 1))
        .sheet(isPresented: $showLogSheet) {
            logProcedureSheet
        }
        .sheet(isPresented: $showEditProcedureSheet) {
            ProcedureEditorSheet(procedure: procedure)
        }
    }

    private func saveStepEdit(step: ProcedureStep) {
        let trimmed = editStepText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.updateProcedureStep(
            procedureID: procedure.id,
            stepID: step.id,
            text: trimmed,
            notes: editStepNotes.isEmpty ? nil : editStepNotes
        )
        editingStepID = nil
    }

    private func commitNewStep() {
        let trimmed = newStepText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let targetPosition = max(1, Int(newStepOrder) ?? (procedure.steps.count + 1))
        let insertIndex = min(targetPosition - 1, procedure.steps.count)

        store.addProcedureStep(
            procedureID: procedure.id,
            text: trimmed,
            atPosition: insertIndex
        )

        newStepText = ""
        newStepOrder = "\(procedure.steps.count + 1)"
    }

    private var logProcedureSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Log Procedure to Journal")
                    .font(.headline)
                Spacer()
                Button("Cancel") { showLogSheet = false }
            }
            .padding(16)

            Divider()

            Form {
                Section("Log Summary") {
                    LabeledContent("Procedure", value: procedure.name)
                    LabeledContent("Steps Completed", value: "\(procedure.completedCount) / \(procedure.steps.count)")
                    LeadingTextField(label: "Performed by", text: $performedBy)
                    LeadingTextField(label: "Cost (Optional)", text: $procedureCostString, prompt: "e.g. 150.00")
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Save Log Entry") {
                    let cost = Decimal.fromCurrencyInput(procedureCostString)
                    store.finishAndLogProcedure(procedureID: procedure.id, cost: cost, performedBy: performedBy)
                    showLogSheet = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.upkeepAmber)
            }
            .padding(16)
        }
        .frame(width: 420, height: 320)
    }
}

// MARK: - View Extension for conditional modifier

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
