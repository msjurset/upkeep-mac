import SwiftUI

struct VendorEditorSheet: View {
    @Environment(UpkeepStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let vendor: Vendor?

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""
    @State private var specialty = ""
    @State private var notes = ""

    private var isEditing: Bool { vendor != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Edit Vendor" : "New Vendor")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    TextField("Specialty", text: $specialty, prompt: Text("e.g. HVAC repair, plumbing"))
                        .textFieldStyle(.roundedBorder)
                }

                Section("Contact") {
                    TextField("Phone", text: $phone)
                        .textFieldStyle(.roundedBorder)
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                    TextField("Website", text: $website)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                        .font(.body)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button(isEditing ? "Save" : "Add Vendor") {
                    save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.upkeepAmber)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 440, height: 460)
        .onAppear {
            if let vendor {
                name = vendor.name
                phone = vendor.phone
                email = vendor.email
                website = vendor.website
                specialty = vendor.specialty
                notes = vendor.notes
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if var existing = vendor {
            existing.name = trimmedName
            existing.phone = phone
            existing.email = email
            existing.website = website
            existing.specialty = specialty
            existing.notes = notes
            store.updateVendor(existing)
        } else {
            store.createVendor(
                name: trimmedName, phone: phone, email: email,
                website: website, specialty: specialty, notes: notes
            )
        }
    }
}
