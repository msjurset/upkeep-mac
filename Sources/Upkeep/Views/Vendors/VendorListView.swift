import SwiftUI

struct VendorListView: View {
    @Environment(UpkeepStore.self) private var store
    @Binding var showNewVendorSheet: Bool

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            HStack {
                Spacer()
                addButton { showNewVendorSheet = true }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            List(selection: $store.selectedVendorID) {
                ForEach(store.vendors) { vendor in
                    VendorRow(vendor: vendor)
                        .tag(vendor.id)
                        .contextMenu {
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
                            Divider()
                            Button("Delete", role: .destructive) {
                                store.deleteVendor(id: vendor.id)
                            }
                        }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .overlay {
            if store.vendors.isEmpty {
                EmptyListOverlay(
                    icon: "person.2",
                    title: "No vendors",
                    message: "Add service providers and contractors",
                    buttonLabel: "Add Vendor"
                ) { showNewVendorSheet = true }
            }
        }
        .navigationTitle("Vendors")
    }
}

struct VendorRow: View {
    let vendor: Vendor

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.circle.fill")
                .font(.title3)
                .foregroundStyle(.upkeepAmber)

            VStack(alignment: .leading, spacing: 3) {
                Text(vendor.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

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
    }
}
