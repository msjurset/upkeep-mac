import SwiftUI

struct VendorEditorSheet: View {
    @Environment(UpkeepStore.self) private var store

    let vendor: Vendor?

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""
    @State private var location = ""
    @State private var specialty = ""
    @State private var tagsString = ""
    @State private var acctMgrName = ""
    @State private var acctMgrPhone = ""
    @State private var acctMgrEmail = ""
    @State private var notes = ""

    private var isEditing: Bool { vendor != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        EditorSheet(
            title: isEditing ? "Edit Vendor" : "New Vendor",
            isValid: isValid,
            saveLabel: isEditing ? "Save" : "Add Vendor",
            onSave: save
        ) {
            Section("Details") {
                    LeadingTextField(label: "Name", text: $name)
                    LeadingTextField(label: "Specialty", text: $specialty, prompt: "e.g. HVAC repair, plumbing")
                    TagSuggestField(text: $tagsString)
                }

                Section("Contact") {
                    LeadingTextField(label: "Phone", text: $phone)
                    LeadingTextField(label: "Email", text: $email)
                    LeadingTextField(label: "Website", text: $website)
                    LeadingTextField(label: "Location", text: $location, prompt: "Google Maps link or Plus Code URL")
                    HStack {
                        Spacer()
                        ContactsImportButton { selection in
                            if name.isEmpty { name = selection.name }
                            if phone.isEmpty { phone = selection.phone }
                            if email.isEmpty { email = selection.email }
                        }
                    }
                }

                Section("Account Manager") {
                    LeadingTextField(label: "Name", text: $acctMgrName)
                    LeadingTextField(label: "Phone", text: $acctMgrPhone)
                    LeadingTextField(label: "Email", text: $acctMgrEmail)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                        .font(.body)
                }
        }
        .frame(width: 440, height: 620)
        .onAppear {
            if let vendor {
                name = vendor.name
                phone = vendor.phone
                email = vendor.email
                website = vendor.website
                location = vendor.location
                specialty = vendor.specialty
                tagsString = vendor.tags.joined(separator: ", ")
                acctMgrName = vendor.accountManager.name
                acctMgrPhone = vendor.accountManager.phone
                acctMgrEmail = vendor.accountManager.email
                notes = vendor.notes
            }
        }
    }

    private var parsedTags: [String] {
        tagsString.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if var existing = vendor {
            existing.name = trimmedName
            existing.phone = phone
            existing.email = email
            existing.website = website
            existing.location = location
            existing.specialty = specialty
            existing.tags = parsedTags
            existing.accountManager = AccountManager(name: acctMgrName, phone: acctMgrPhone, email: acctMgrEmail)
            existing.notes = notes
            store.updateVendor(existing)
        } else {
            store.createVendor(
                name: trimmedName, phone: phone, email: email,
                website: website, location: location,
                specialty: specialty, tags: parsedTags,
                accountManager: AccountManager(name: acctMgrName, phone: acctMgrPhone, email: acctMgrEmail),
                notes: notes
            )
        }
    }
}
