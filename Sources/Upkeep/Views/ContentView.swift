import SwiftUI

struct ContentView: View {
    @Environment(UpkeepStore.self) private var store
    @Environment(\.undoManager) private var undoManager
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showNewItemSheet = false
    @State private var showNewLogEntrySheet = false
    @State private var showNewVendorSheet = false
    @State private var showNewSourcingSheet = false
    @State private var showQuickSearch = false
    @State private var toastMessage: String?
    @State private var toastUndoAction: (() -> Void)?

    var body: some View {
        @Bindable var store = store
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $store.navigation)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } content: {
            if store.navigation == .dashboard || store.navigation == .homeProfile {
                Color.clear
                    .navigationSplitViewColumnWidth(min: 0, ideal: 0, max: 0)
            } else {
                ContentListView(
                    showNewItemSheet: $showNewItemSheet,
                    showNewLogEntrySheet: $showNewLogEntrySheet,
                    showNewVendorSheet: $showNewVendorSheet,
                    showNewSourcingSheet: $showNewSourcingSheet
                )
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 500)
            }
        } detail: {
            DetailView()
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    store.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!store.canGoBack)
                .keyboardShortcut("[", modifiers: .command)
                .help("Back")

                Button {
                    store.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!store.canGoForward)
                .keyboardShortcut("]", modifiers: .command)
                .help("Forward")
            }
        }
        .onAppear {
            store.undoManager = undoManager
            store.loadAll()
        }
        .onChange(of: undoManager) { _, newValue in
            store.undoManager = newValue
        }
        .onChange(of: store.navigation) { oldVal, newVal in
            // Skip the auto-clearing when restoring a navigation snapshot — back/forward
            // need to preserve the recorded selection state.
            if store.isApplyingHistory { return }
            let oldSection = sidebarSection(oldVal)
            let newSection = sidebarSection(newVal)
            if oldSection != newSection {
                if newSection != "inventory" {
                    store.selectedItemID = nil
                    store.searchQuery = ""
                }
                if newSection != "vendors" {
                    store.selectedVendorID = nil
                    store.selectedSourcingID = nil
                }
                if newSection != "log" { store.selectedLogEntryID = nil }
                columnVisibility = .all
            }
        }
        .sheet(isPresented: $showNewItemSheet) {
            ItemEditorSheet(item: nil)
        }
        .sheet(isPresented: $showNewLogEntrySheet) {
            LogEntrySheet(entry: nil, itemID: nil)
        }
        .sheet(isPresented: $showNewVendorSheet) {
            VendorEditorSheet(vendor: nil)
        }
        .sheet(isPresented: $showNewSourcingSheet) {
            SourcingEditorSheet(sourcing: nil)
        }
        .sheet(isPresented: $showQuickSearch) {
            QuickSearchView()
        }
        .keyboardShortcut("n", modifiers: .command) {
            showNewItemSheet = true
        }
        .keyboardShortcut("n", modifiers: [.command, .shift]) {
            showNewLogEntrySheet = true
        }
        .keyboardShortcut("k", modifiers: .command) {
            showQuickSearch = true
        }
        .keyboardShortcut("f", modifiers: .command) {
            showQuickSearch = true
        }
        .background(SearchKeyMonitor { showQuickSearch = true })
        .frame(minWidth: 1000, minHeight: 550)
        .overlay(alignment: .top) {
            ConflictBanner()
                .animation(.easeInOut, value: store.conflicts.count)
        }
        .overlay(alignment: .bottom) {
            if let message = toastMessage {
                UndoToast(
                    message: message,
                    onUndo: {
                        toastUndoAction?()
                        toastMessage = nil
                    },
                    onDismiss: { toastMessage = nil }
                )
                .padding(20)
            }
        }
        .overlay(alignment: .top) {
            if let error = store.error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.callout)
                    Spacer()
                    Button("Dismiss") {
                        store.error = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(radius: 4)
                .padding()
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: store.error)
            }
        }
    }

    private func sidebarSection(_ item: NavigationItem?) -> String {
        switch item {
        case .dashboard: return "dashboard"
        case .inventoryUpcoming, .inventoryOverdue, .inventoryIdeas, .inventoryAll, .itemDetail: return "inventory"
        case .log, .logEntryDetail: return "log"
        case .vendors, .vendorDetail: return "vendors"
        case .homeProfile: return "home"
        case nil: return ""
        }
    }
}

// MARK: - Content List

struct ContentListView: View {
    @Environment(UpkeepStore.self) private var store
    @Binding var showNewItemSheet: Bool
    @Binding var showNewLogEntrySheet: Bool
    @Binding var showNewVendorSheet: Bool
    @Binding var showNewSourcingSheet: Bool

    var body: some View {
        switch store.navigation {
        case .inventoryUpcoming:
            ItemListView(items: store.filteredUpcomingItems, title: "Upcoming", showNewItemSheet: $showNewItemSheet)
                .accessibilityIdentifier("list.items")
        case .inventoryOverdue:
            ItemListView(items: store.filteredOverdueItems, title: "Overdue", showNewItemSheet: $showNewItemSheet)
                .accessibilityIdentifier("list.items")
        case .inventoryIdeas:
            ItemListView(items: store.filteredIdeaItems, title: "Ideas", showNewItemSheet: $showNewItemSheet)
                .accessibilityIdentifier("list.items")
        case .inventoryAll:
            ItemListView(items: store.filteredAllItems, title: "All Items", showNewItemSheet: $showNewItemSheet)
                .accessibilityIdentifier("list.items")
        case .log, .logEntryDetail:
            LogView(showNewLogEntrySheet: $showNewLogEntrySheet)
                .accessibilityIdentifier("list.log")
        case .vendors, .vendorDetail:
            VendorsContainerView(
                showNewVendorSheet: $showNewVendorSheet,
                showNewSourcingSheet: $showNewSourcingSheet
            )
            .accessibilityIdentifier("list.vendors")
        default:
            Text("Select a section")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Detail

struct DetailView: View {
    @Environment(UpkeepStore.self) private var store

    var body: some View {
        switch store.navigation {
        case .dashboard:
            DashboardView()
                .accessibilityIdentifier("detail.dashboard")
        case .inventoryUpcoming, .inventoryOverdue, .inventoryIdeas, .inventoryAll, .itemDetail:
            if let item = store.selectedItem {
                ItemDetailView(item: item)
                    .accessibilityIdentifier("detail.item")
            } else {
                EmptyDetailView(icon: "wrench.and.screwdriver", message: "Select an item to view details")
                    .accessibilityIdentifier("detail.empty.item")
            }
        case .log, .logEntryDetail:
            if let entry = store.selectedLogEntry {
                LogEntryDetailView(entry: entry)
                    .accessibilityIdentifier("detail.logEntry")
            } else {
                EmptyDetailView(icon: "book", message: "Select a log entry to view details")
                    .accessibilityIdentifier("detail.empty.log")
            }
        case .vendors, .vendorDetail:
            switch store.vendorsTab {
            case .vendors:
                if let vendor = store.selectedVendor {
                    VendorDetailView(vendor: vendor)
                        .accessibilityIdentifier("detail.vendor")
                } else {
                    EmptyDetailView(icon: "person.2", message: "Select a vendor to view details")
                        .accessibilityIdentifier("detail.empty.vendor")
                }
            case .sourcings:
                if let sourcing = store.selectedSourcing {
                    SourcingDetailView(sourcing: sourcing)
                        .accessibilityIdentifier("detail.sourcing")
                } else {
                    EmptyDetailView(icon: "magnifyingglass", message: "Select a sourcing to view details")
                        .accessibilityIdentifier("detail.empty.sourcing")
                }
            }
        case .homeProfile:
            HomeProfileView()
                .accessibilityIdentifier("detail.homeProfile")
        case nil:
            EmptyDetailView(icon: "house", message: "Welcome to Upkeep")
                .accessibilityIdentifier("detail.empty")
        }
    }
}

// MARK: - Empty State

struct EmptyDetailView: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.upkeepAmber.opacity(0.5))
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("emptyDetail")
    }
}

// MARK: - Keyboard Shortcut Helper

private extension View {
    func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers, action: @escaping () -> Void) -> some View {
        background(
            Button("") { action() }
                .keyboardShortcut(key, modifiers: modifiers)
                .hidden()
        )
    }
}
