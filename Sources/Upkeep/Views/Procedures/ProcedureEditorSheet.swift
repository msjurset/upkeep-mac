import SwiftUI

struct ProcedureEditorSheet: View {
    @Environment(UpkeepStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let procedure: Procedure?

    @State private var selectedTemplateID: String? = nil
    @State private var name = ""
    @State private var phase: ProcedurePhase = .winterization
    @State private var selectedPropertyIDs: Set<UUID> = []
    @State private var steps: [EditableStep] = []
    @State private var newStepText = ""
    @State private var newStepNotes = ""
    @State private var notes = ""

    struct EditableStep: Identifiable {
        let id: UUID
        var text: String
        var notes: String
    }

    private var isNew: Bool { procedure == nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !steps.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isNew ? "New Procedure" : "Edit Procedure")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            Form {
                if isNew {
                    Section("Start from Template") {
                        Picker("Template", selection: $selectedTemplateID) {
                            Text("Custom Procedure (Blank)").tag(String?.none)
                            Divider()
                            ForEach(Procedure.builtInTemplates) { tmpl in
                                Label(tmpl.title, systemImage: tmpl.icon).tag(Optional(tmpl.id))
                            }
                        }
                        .onChange(of: selectedTemplateID) { _, newID in
                            if let newID, let tmpl = Procedure.builtInTemplates.first(where: { $0.id == newID }) {
                                let firstPropID = selectedPropertyIDs.first ?? store.selectedPropertyID ?? store.primaryProperty?.id
                                let p = tmpl.create(firstPropID)
                                name = p.name
                                phase = p.phase
                                steps = p.steps.sorted(by: { $0.sortOrder < $1.sortOrder }).map {
                                    EditableStep(id: UUID(), text: $0.text, notes: $0.notes ?? "")
                                }
                            }
                        }
                    }
                }

                Section("Procedure Details") {
                    LeadingTextField(label: "Procedure Name", text: $name, prompt: "e.g. Northern Lake House Winterization")

                    Picker("Phase", selection: $phase) {
                        ForEach(ProcedurePhase.allCases) { p in
                            Label(p.label, systemImage: p.icon).tag(p)
                        }
                    }
                }

                Section("Applicable Properties") {
                    ForEach(store.properties) { p in
                        Toggle(isOn: Binding(
                            get: { selectedPropertyIDs.contains(p.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedPropertyIDs.insert(p.id)
                                } else {
                                    selectedPropertyIDs.remove(p.id)
                                }
                            }
                        )) {
                            Label(p.name, systemImage: p.icon)
                        }
                    }
                }

                Section("Steps (\(steps.count))") {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        HStack(spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .frame(width: 20, alignment: .trailing)

                            VStack(alignment: .leading, spacing: 2) {
                                TextField("Step description", text: $steps[index].text)
                                    .font(.callout)
                                TextField("Notes / details (optional)", text: $steps[index].notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                steps.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onMove { from, to in
                        steps.move(fromOffsets: from, toOffset: to)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Add a step...", text: $newStepText)
                            .font(.callout)
                            .onSubmit { addStep() }

                        HStack {
                            TextField("Optional notes for step", text: $newStepNotes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Add Step") { addStep() }
                                .font(.caption)
                                .disabled(newStepText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding(.top, 4)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 50)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if !isNew, let procID = procedure?.id {
                    Button("Delete Procedure", role: .destructive) {
                        store.deleteProcedure(id: procID)
                        dismiss()
                    }
                }

                Spacer()

                Button(isNew ? "Create Procedure" : "Save Changes") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .tint(.upkeepAmber)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 520, height: 660)
        .onAppear {
            if let procedure {
                name = procedure.name
                phase = procedure.phase
                selectedPropertyIDs = Set(procedure.propertyIDs)
                notes = procedure.notes
                steps = procedure.steps.sorted(by: { $0.sortOrder < $1.sortOrder }).map {
                    EditableStep(id: $0.id, text: $0.text, notes: $0.notes ?? "")
                }
            } else {
                if let selProp = store.selectedPropertyID {
                    selectedPropertyIDs = [selProp]
                }
            }
        }
    }

    private func addStep() {
        let trimmed = newStepText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        steps.append(EditableStep(id: UUID(), text: trimmed, notes: newStepNotes.trimmingCharacters(in: .whitespaces)))
        newStepText = ""
        newStepNotes = ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !steps.isEmpty else { return }

        let procSteps = steps.enumerated().map { index, step in
            ProcedureStep(
                id: step.id,
                text: step.text,
                notes: step.notes.isEmpty ? nil : step.notes,
                sortOrder: index
            )
        }

        var proc = procedure ?? Procedure(name: trimmedName, phase: phase)
        proc.name = trimmedName
        proc.phase = phase
        proc.propertyIDs = Array(selectedPropertyIDs)
        proc.steps = procSteps
        proc.notes = notes

        store.saveProcedure(proc)
        dismiss()
    }
}
