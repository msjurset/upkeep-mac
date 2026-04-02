import SwiftUI

struct VendorDetailView: View {
    @Environment(UpkeepStore.self) private var store
    let vendor: Vendor
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.upkeepAmber)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(vendor.name)
                                .font(.title2.weight(.semibold))
                            if !vendor.specialty.isEmpty {
                                Text(vendor.specialty)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(20)

                // Contact info
                if vendor.hasContactInfo {
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Contact")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        if !vendor.phone.isEmpty {
                            contactRow(icon: "phone", label: "Phone", value: vendor.phone)
                        }
                        if !vendor.email.isEmpty {
                            contactRow(icon: "envelope", label: "Email", value: vendor.email)
                        }
                        if !vendor.website.isEmpty {
                            contactRow(icon: "globe", label: "Website", value: vendor.website)
                        }
                    }
                    .padding(20)
                }

                // Notes
                if !vendor.notes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(vendor.notes)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .padding(20)
                }

                // Linked items
                let linkedItems = store.items(for: vendor.id)
                if !linkedItems.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Assigned Items")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        ForEach(linkedItems) { item in
                            Button {
                                store.navigation = .inventoryAll
                                store.selectedItemID = item.id
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: item.category.icon)
                                        .foregroundStyle(Color.categoryColor(item.category))
                                    Text(item.name)
                                        .font(.body)
                                    Spacer()
                                    let days = store.daysUntilDue(item)
                                    DueDateBadge(daysUntilDue: days)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator.opacity(0.3)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            VendorEditorSheet(vendor: vendor)
        }
        .confirmationDialog("Delete \"\(vendor.name)\"?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                store.deleteVendor(id: vendor.id)
                store.selectedVendorID = nil
            }
        } message: {
            Text("This will permanently remove this vendor.")
        }
    }

    private func contactRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.upkeepAmber)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
    }
}
