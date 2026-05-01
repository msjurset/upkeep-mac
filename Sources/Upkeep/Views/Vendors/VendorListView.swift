import SwiftUI

struct VendorListView: View {
    @Environment(UpkeepStore.self) private var store
    @Binding var showNewVendorSheet: Bool

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Toggle(isOn: $store.showInactiveVendors) {
                    Text("Show inactive")
                        .font(.caption)
                }
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .help("Include vendors flagged as inactive (e.g. former vendors replaced via a search)")

                Spacer()
                addButton { showNewVendorSheet = true }
                    .help("New vendor")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            List(selection: $store.selectedVendorID) {
                ForEach(Array(store.visibleVendors.enumerated()), id: \.element.id) { index, vendor in
                    VendorRow(vendor: vendor)
                        .tag(vendor.id)
                        .listRowBackground(index.isMultiple(of: 2) ? Color.clear : Color.alternatingRow)
                        .listRowSeparator(.hidden)
                        .contextMenu {
                            Button("Find a Replacement…") {
                                store.recordHistory()
                                store.createSourcing(
                                    title: "Replace \(vendor.name)",
                                    replacingVendorID: vendor.id
                                )
                                store.vendorsTab = .sourcings
                            }
                            if !vendor.phone.isEmpty {
                                Button("Copy Phone") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(vendor.phone, forType: .string)
                                }
                            }
                            if !vendor.email.isEmpty {
                                Button("Copy Email") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(vendor.email, forType: .string)
                                }
                            }
                            Button(vendor.isActive ? "Mark Inactive" : "Mark Active") {
                                var updated = vendor
                                updated.isActive.toggle()
                                store.updateVendor(updated, actionName: vendor.isActive ? "Mark Inactive" : "Mark Active")
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                store.deleteVendor(id: vendor.id)
                            }
                        }
                }
            }
            .listStyle(.inset)
        }
        .overlay {
            if store.visibleVendors.isEmpty {
                EmptyListOverlay(
                    icon: "person.2",
                    title: store.vendors.isEmpty ? "No vendors" : "No active vendors",
                    message: store.vendors.isEmpty
                        ? "Add service providers and contractors"
                        : "Toggle \"Show inactive\" to see all",
                    buttonLabel: "Add Vendor"
                ) { showNewVendorSheet = true }
            }
        }
    }
}

struct VendorRow: View {
    let vendor: Vendor

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.circle.fill")
                .font(.title3)
                .foregroundStyle(.upkeepAmber)
                .opacity(vendor.isActive ? 1.0 : 0.5)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(vendor.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(vendor.isActive ? .primary : .secondary)
                    if !vendor.isActive {
                        Text("Inactive")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().strokeBorder(.separator))
                    }
                }

                HStack(spacing: 6) {
                    if !vendor.specialty.isEmpty {
                        Text(vendor.specialty)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if !vendor.phone.isEmpty {
                        Text(vendor.phone)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .opacity(vendor.isActive ? 1.0 : 0.7)
    }
}
