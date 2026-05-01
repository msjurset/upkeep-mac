import SwiftUI
import Contacts
import ContactsUI
import AppKit

/// A snapshot of the fields we copy in from a chosen Contacts entry.
struct ContactSelection: Sendable {
    var name: String
    var phone: String
    var email: String
}

/// A small "Pick from Contacts…" button that opens the system contact picker as a popover
/// anchored to itself. On selection, calls `onSelect` with the contact's name + primary
/// phone + primary email. CNContactPicker shows the picker UI without needing the app to
/// hold contacts permission — the user explicitly hands one contact over.
struct ContactsImportButton: View {
    let onSelect: (ContactSelection) -> Void
    var label: String = "Pick from Contacts…"

    @State private var triggerOpen = false

    var body: some View {
        Button {
            triggerOpen = true
        } label: {
            Label(label, systemImage: "person.crop.circle.badge.plus")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .background(ContactPickerHost(triggerOpen: $triggerOpen, onSelect: onSelect))
    }
}

private struct ContactPickerHost: NSViewRepresentable {
    @Binding var triggerOpen: Bool
    let onSelect: (ContactSelection) -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        context.coordinator.anchor = v
        return v
    }

    func updateNSView(_ view: NSView, context: Context) {
        if triggerOpen && !context.coordinator.isOpen {
            context.coordinator.open()
            DispatchQueue.main.async { triggerOpen = false }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    @MainActor
    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: (ContactSelection) -> Void
        weak var anchor: NSView?
        var isOpen = false
        var picker: CNContactPicker?

        init(onSelect: @escaping (ContactSelection) -> Void) {
            self.onSelect = onSelect
        }

        func open() {
            guard let anchor else { return }
            let picker = CNContactPicker()
            picker.delegate = self
            picker.displayedKeys = [
                CNContactPhoneNumbersKey,
                CNContactEmailAddressesKey
            ]
            self.picker = picker
            isOpen = true
            picker.showRelative(to: anchor.bounds, of: anchor, preferredEdge: .maxY)
        }

        nonisolated func contactPicker(_ picker: CNContactPicker, didSelect contact: CNContact) {
            let name = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
            let email = (contact.emailAddresses.first?.value as String?) ?? ""
            let sel = ContactSelection(name: name, phone: phone, email: email)
            Task { @MainActor [weak self] in
                self?.isOpen = false
                self?.onSelect(sel)
            }
        }

        nonisolated func contactPickerDidClose(_ picker: CNContactPicker) {
            Task { @MainActor [weak self] in
                self?.isOpen = false
            }
        }
    }
}
