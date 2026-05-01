import SwiftUI

struct SourcingEditorSheet: View {
    @Environment(UpkeepStore.self) private var store

    let sourcing: Sourcing?

    @State private var title = ""
    @State private var notes = ""
    @State private var linkedItemIDs: [UUID] = []
    @State private var replacingVendorID: UUID?
    @State private var hasDecideBy = false
    @State private var decideBy = Date.now.addingTimeInterval(60 * 60 * 24 * 30)

    private var isEditing: Bool { sourcing != nil }
    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Items currently using the selected replacement-vendor — informs the user that the cascade
    /// will reassign them all on hire.
    private var cascadeItemCount: Int {
        guard let replacingVendorID else { return 0 }
        return store.items.filter { $0.vendorID == replacingVendorID }.count
    }

    var body: some View {
        EditorSheet(
            title: isEditing ? "Edit Sourcing" : "New Sourcing",
            isValid: isValid,
            saveLabel: isEditing ? "Save" : "Create",
            onSave: save
        ) {
            Section("Details") {
                LeadingTextField(label: "Title", text: $title, prompt: "e.g. Lawn service replacement")
            }

            Section("Linked to") {
                MultiItemPicker(
                    label: "For items",
                    items: store.items,
                    selection: $linkedItemIDs,
                    displayName: { $0.name },
                    subtitle: { $0.category.label },
                    placeholder: "Tie this sourcing to one or more maintenance items (optional)"
                )
                SearchablePicker(
                    label: "Replacing vendor",
                    items: store.vendors,
                    selection: $replacingVendorID,
                    displayName: { $0.name },
                    subtitle: { $0.specialty },
                    placeholder: "Replacing an existing vendor? (optional)"
                )
                if cascadeItemCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.upkeepAmber)
                        Text("\(cascadeItemCount) item\(cascadeItemCount == 1 ? "" : "s") currently use\(cascadeItemCount == 1 ? "s" : "") this vendor — all will be reassigned to the new vendor on hire.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Decide by") {
                Toggle("Set deadline", isOn: $hasDecideBy)
                if hasDecideBy {
                    LabeledContent("Date") {
                        HStack(spacing: 6) {
                            StepperDateField(selection: $decideBy)
                            CalendarPopoverButton(selection: $decideBy)
                        }
                    }
                }
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
                    .font(.body)
            }
        }
        .frame(width: 540, height: 680)
        .onAppear {
            if let sourcing {
                title = sourcing.title
                notes = sourcing.notes
                linkedItemIDs = sourcing.linkedItemIDs
                replacingVendorID = sourcing.replacingVendorID
                if let d = sourcing.decideBy {
                    hasDecideBy = true
                    decideBy = d
                }
            }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let resolvedDecideBy = hasDecideBy ? decideBy : nil
        if var existing = sourcing {
            existing.title = trimmed
            existing.notes = notes
            existing.linkedItemIDs = linkedItemIDs
            existing.replacingVendorID = replacingVendorID
            existing.decideBy = resolvedDecideBy
            store.updateSourcing(existing)
        } else {
            store.createSourcing(
                title: trimmed,
                linkedItemIDs: linkedItemIDs,
                replacingVendorID: replacingVendorID,
                decideBy: resolvedDecideBy,
                notes: notes
            )
        }
    }
}
