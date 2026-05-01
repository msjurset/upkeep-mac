import SwiftUI

struct CandidateEditorSheet: View {
    @Environment(UpkeepStore.self) private var store

    let sourcingID: UUID
    let candidate: Candidate?

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var source = ""
    @State private var status: CandidateStatus = .notContacted
    @State private var hasQuote = false
    @State private var quoteString = ""
    @State private var notes = ""

    private var isEditing: Bool { candidate != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Live candidate from the store, used to reflect attachment changes (which save
    /// immediately) without waiting for the form to close.
    private var liveCandidate: Candidate? {
        guard let candidate else { return nil }
        return store.sourcings
            .first { $0.id == sourcingID }?
            .candidates
            .first { $0.id == candidate.id }
    }

    var body: some View {
        EditorSheet(
            title: isEditing ? "Edit Candidate" : "New Candidate",
            isValid: isValid,
            saveLabel: isEditing ? "Save" : "Add Candidate",
            onSave: save
        ) {
            Section("Details") {
                LeadingTextField(label: "Name", text: $name)
                LeadingTextField(label: "Phone", text: $phone)
                LeadingTextField(label: "Email", text: $email)
                LeadingTextField(label: "Source", text: $source, prompt: "e.g. Tom across the street, Nextdoor")
                HStack {
                    Spacer()
                    ContactsImportButton { selection in
                        if name.isEmpty { name = selection.name }
                        if phone.isEmpty { phone = selection.phone }
                        if email.isEmpty { email = selection.email }
                    }
                }
            }

            Section("Status") {
                Picker("Status", selection: $status) {
                    ForEach(CandidateStatus.allCases.filter { $0 != .hired }, id: \.self) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .help("Hired status is set by closing the search")
            }

            Section("Quote") {
                Toggle("Quote received", isOn: $hasQuote)
                if hasQuote {
                    LeadingTextField(label: "Amount", text: $quoteString, prompt: "e.g. 1200")
                }
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
                    .font(.body)
            }

            if let candidate {
                Section {
                    AttachmentsSection(
                        attachments: liveCandidate?.attachments ?? candidate.attachments,
                        onAdd: { att in
                            store.addAttachmentToCandidate(
                                sourcingID: sourcingID,
                                candidateID: candidate.id,
                                att
                            )
                        },
                        onRemove: { id in
                            store.removeAttachmentFromCandidate(
                                sourcingID: sourcingID,
                                candidateID: candidate.id,
                                attachmentID: id
                            )
                        }
                    )
                }
            }
        }
        .frame(width: 480, height: 720)
        .onAppear {
            if let candidate {
                name = candidate.name
                phone = candidate.phone
                email = candidate.email
                source = candidate.source
                status = candidate.status == .hired ? .quoted : candidate.status
                notes = candidate.notes
                if let q = candidate.quoteAmount {
                    hasQuote = true
                    quoteString = "\(q)"
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let resolvedQuote: Decimal? = hasQuote
            ? Decimal(string: quoteString.trimmingCharacters(in: .whitespaces))
            : nil

        if var existing = candidate {
            existing.name = trimmedName
            existing.phone = phone
            existing.email = email
            existing.source = source
            existing.status = status
            existing.quoteAmount = resolvedQuote
            existing.notes = notes
            store.updateCandidate(existing, in: sourcingID)
        } else {
            let new = Candidate(
                name: trimmedName, phone: phone, email: email, source: source,
                status: status, quoteAmount: resolvedQuote, notes: notes
            )
            store.addCandidate(to: sourcingID, new)
        }
    }
}
