import SwiftUI

struct VendorsContainerView: View {
    @Environment(UpkeepStore.self) private var store
    @Binding var showNewVendorSheet: Bool
    @Binding var showNewSourcingSheet: Bool

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            Picker("", selection: $store.vendorsTab) {
                ForEach(UpkeepStore.VendorsTab.allCases, id: \.self) { tab in
                    Text(tab.label).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.top, 8)

            switch store.vendorsTab {
            case .vendors:
                VendorListView(showNewVendorSheet: $showNewVendorSheet)
            case .sourcings:
                SourcingListView(showNewSourcingSheet: $showNewSourcingSheet)
            }
        }
        .navigationTitle("Vendors")
        .onChange(of: store.vendorsTab) { _, newTab in
            switch newTab {
            case .vendors: store.selectedSourcingID = nil
            case .sourcings: store.selectedVendorID = nil
            }
        }
    }
}
