import SwiftUI

@Observable
@MainActor
final class UpkeepStore {
    enum SortMode: String, CaseIterable, Sendable {
        case dueSoonest = "Due"
        case priority = "Priority"
        case nameAZ = "Name A-Z"
        case nameZA = "Name Z-A"

        var next: SortMode {
            let all = SortMode.allCases
            let idx = all.firstIndex(of: self)!
            return all[(idx + 1) % all.count]
        }

        var icon: String {
            switch self {
            case .dueSoonest: "calendar"
            case .priority: "exclamationmark.circle"
            case .nameAZ: "arrow.down"
            case .nameZA: "arrow.up"
            }
        }
    }

    var items: [MaintenanceItem] = []
    var logEntries: [LogEntry] = []
    var vendors: [Vendor] = []
    var sourcings: [Sourcing] = []
    var members: [HouseholdMember] = []
    var config: AppConfig = AppConfig()
    var sortMode: SortMode = .dueSoonest

    var navigation: NavigationItem? = .dashboard {
        didSet {
            if let navigation {
                localConfig.lastNavigationKey = navigation.sectionKey
                localConfig.save()
            }
        }
    }
    enum VendorsTab: String, CaseIterable, Sendable {
        case vendors
        case sourcings

        var label: String {
            switch self {
            case .vendors: "Vendors"
            case .sourcings: "Sourcing"
            }
        }
    }

    /// Snapshot of the user-visible navigation state. Used by the back/forward stack
    /// to restore prior drill-downs across views.
    struct NavigationSnapshot: Equatable, Sendable {
        let navigation: NavigationItem?
        let vendorsTab: VendorsTab
        let selectedItemID: UUID?
        let selectedVendorID: UUID?
        let selectedLogEntryID: UUID?
        let selectedSourcingID: UUID?
    }

    var selectedItemID: UUID?
    var selectedVendorID: UUID?
    var selectedLogEntryID: UUID?
    var selectedSourcingID: UUID?
    var vendorsTab: VendorsTab = .vendors
    var showInactiveVendors = false

    // Back/forward navigation history. recordHistory() pushes the current snapshot
    // before a drill-down; goBack()/goForward() shuttle between them. Capped at 50.
    var historyStack: [NavigationSnapshot] = []
    var forwardStack: [NavigationSnapshot] = []
    var isApplyingHistory = false
    var searchQuery = ""
    var isLoading = false
    var error: String?
    var undoManager: UndoManager?
    var showMyTasksOnly = false
    var needsOnboarding = false
    var conflicts: [Conflict] = []

    var localConfig: LocalConfig
    private(set) var persistence: Persistence
    private let notifications: NotificationService?
    private var refreshTimer: Timer?
    private var knownVersions: [UUID: Int] = [:]

    var currentMemberID: UUID? { localConfig.currentMemberID }

    var colorScheme: ColorScheme? {
        switch localConfig.appearance {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }

    var currentMember: HouseholdMember? {
        guard let id = currentMemberID else { return nil }
        return members.first { $0.id == id }
    }

    init(notifications: NotificationService = .shared) {
        let config = LocalConfig.load()
        self.localConfig = config

        // UI tests pass a temp directory to isolate from live data
        if let testDir = ProcessInfo.processInfo.environment["UI_TEST_DATA_DIR"] {
            self.persistence = Persistence(baseURL: URL(fileURLWithPath: testDir))
            self.notifications = nil
            self.needsOnboarding = false
        } else {
            self.persistence = Persistence(baseURL: config.resolvedDataURL)
            self.notifications = notifications
            self.showMyTasksOnly = config.showMyTasksOnly
            if config.currentMemberID == nil {
                self.needsOnboarding = true
            }
        }

        // Restore last-used view if configured
        if config.launchView == .lastUsed,
           let restored = NavigationItem.from(sectionKey: config.lastNavigationKey) {
            self.navigation = restored
        }
    }

    /// Test-only initializer that skips LocalConfig and NotificationService.
    init(persistence: Persistence) {
        self.localConfig = LocalConfig()
        self.persistence = persistence
        self.notifications = nil
    }

    func reconfigureDataLocation(_ path: String) {
        localConfig.dataLocation = path
        localConfig.save()
        persistence = Persistence(baseURL: localConfig.resolvedDataURL)
        loadAll()
    }

    func setCurrentMember(_ member: HouseholdMember) {
        localConfig.currentMemberID = member.id
        localConfig.save()
        needsOnboarding = false
    }

    // MARK: - Navigation History

    var canGoBack: Bool { !historyStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    private func currentSnapshot() -> NavigationSnapshot {
        NavigationSnapshot(
            navigation: navigation,
            vendorsTab: vendorsTab,
            selectedItemID: selectedItemID,
            selectedVendorID: selectedVendorID,
            selectedLogEntryID: selectedLogEntryID,
            selectedSourcingID: selectedSourcingID
        )
    }

    /// Push the current navigation state onto the history stack. Call BEFORE a drill-down
    /// mutation (clicking a link to another view, opening a detail from a list, etc.).
    /// Clears the forward stack since a new branch is starting.
    func recordHistory() {
        let snap = currentSnapshot()
        // Skip duplicates
        if let last = historyStack.last, last == snap { return }
        historyStack.append(snap)
        forwardStack.removeAll()
        if historyStack.count > 50 {
            historyStack.removeFirst(historyStack.count - 50)
        }
    }

    func goBack() {
        guard let prev = historyStack.popLast() else { return }
        forwardStack.append(currentSnapshot())
        applySnapshot(prev)
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        historyStack.append(currentSnapshot())
        applySnapshot(next)
    }

    private func applySnapshot(_ snapshot: NavigationSnapshot) {
        isApplyingHistory = true
        navigation = snapshot.navigation
        vendorsTab = snapshot.vendorsTab
        selectedItemID = snapshot.selectedItemID
        selectedVendorID = snapshot.selectedVendorID
        selectedLogEntryID = snapshot.selectedLogEntryID
        selectedSourcingID = snapshot.selectedSourcingID
        // Defer flag clear so SwiftUI's .onChange handlers see the flag as still set
        // and skip their normal selection-clearing behavior.
        Task { @MainActor in
            isApplyingHistory = false
        }
    }

    // MARK: - Background Refresh

    func startBackgroundRefresh() {
        stopBackgroundRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.silentReload()
            }
        }
    }

    func stopBackgroundRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func silentReload() {
        Task {
            do {
                let loadedItems = try await persistence.loadItems()
                let loadedLog = try await persistence.loadLogEntries()
                let loadedVendors = try await persistence.loadVendors()
                let loadedSourcings = try await persistence.loadSourcings()
                let loadedMembers = try await persistence.loadMembers()

                // Detect conflicts before replacing in-memory model
                detectConflicts(newItems: loadedItems, newVendors: loadedVendors)

                self.items = loadedItems.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.logEntries = loadedLog.sorted { $0.completedDate > $1.completedDate }
                self.vendors = loadedVendors.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.sourcings = loadedSourcings.sorted { $0.updatedAt > $1.updatedAt }
                self.members = loadedMembers

                // Update known versions from what's on disk
                snapshotVersions()
            } catch {}
        }
    }

    // MARK: - Conflict Detection

    private func snapshotVersions() {
        for item in items { knownVersions[item.id] = item.version }
        for vendor in vendors { knownVersions[vendor.id] = vendor.version }
    }

    func recordVersion(id: UUID, version: Int) {
        knownVersions[id] = version
    }

    private func detectConflicts(newItems: [MaintenanceItem], newVendors: [Vendor]) {
        guard currentMemberID != nil else { return }
        var detected: [Conflict] = []

        for item in newItems {
            if let known = knownVersions[item.id],
               item.version > known,
               item.lastModifiedBy != nil,
               item.lastModifiedBy != currentMemberID {
                // Someone else bumped the version past what we last saw
                let existing = conflicts.contains { $0.entityID == item.id }
                if !existing {
                    detected.append(Conflict(
                        id: UUID(), entityID: item.id, kind: .item,
                        entityName: item.name, ourVersion: known,
                        theirVersion: item.version, theirModifiedBy: item.lastModifiedBy
                    ))
                }
            }
        }

        for vendor in newVendors {
            if let known = knownVersions[vendor.id],
               vendor.version > known,
               vendor.lastModifiedBy != nil,
               vendor.lastModifiedBy != currentMemberID {
                let existing = conflicts.contains { $0.entityID == vendor.id }
                if !existing {
                    detected.append(Conflict(
                        id: UUID(), entityID: vendor.id, kind: .vendor,
                        entityName: vendor.name, ourVersion: known,
                        theirVersion: vendor.version, theirModifiedBy: vendor.lastModifiedBy
                    ))
                }
            }
        }

        if !detected.isEmpty {
            conflicts.append(contentsOf: detected)
        }
    }

    func dismissConflict(id: UUID) {
        conflicts.removeAll { $0.id == id }
    }

    func dismissAllConflicts() {
        conflicts.removeAll()
    }

    func acceptTheirVersion(conflict: Conflict) {
        // Already on disk (theirs won). Just update our known version and dismiss.
        if let item = items.first(where: { $0.id == conflict.entityID }) {
            knownVersions[item.id] = item.version
        } else if let vendor = vendors.first(where: { $0.id == conflict.entityID }) {
            knownVersions[vendor.id] = vendor.version
        }
        dismissConflict(id: conflict.id)
    }

    func revertToOurVersion(conflict: Conflict) {
        // Re-save our in-memory version (bump version again to overtake theirs)
        if var item = items.first(where: { $0.id == conflict.entityID }) {
            item.touch(by: currentMemberID)
            Task {
                try? await persistence.saveItem(item)
                knownVersions[item.id] = item.version
                loadAll()
            }
        } else if var vendor = vendors.first(where: { $0.id == conflict.entityID }) {
            vendor.touch(by: currentMemberID)
            Task {
                try? await persistence.saveVendor(vendor)
                knownVersions[vendor.id] = vendor.version
                loadAll()
            }
        }
        dismissConflict(id: conflict.id)
    }

    // MARK: - Computed: Selected

    var selectedItem: MaintenanceItem? {
        guard let id = selectedItemID else { return nil }
        return items.first { $0.id == id }
    }

    var selectedVendor: Vendor? {
        guard let id = selectedVendorID else { return nil }
        return vendors.first { $0.id == id }
    }

    var selectedLogEntry: LogEntry? {
        guard let id = selectedLogEntryID else { return nil }
        return logEntries.first { $0.id == id }
    }

    var selectedSourcing: Sourcing? {
        guard let id = selectedSourcingID else { return nil }
        return sourcings.first { $0.id == id }
    }

    var visibleVendors: [Vendor] {
        showInactiveVendors ? vendors : vendors.filter(\.isActive)
    }

    // MARK: - Computed: Scheduling

    var scheduling: SchedulingService {
        SchedulingService(items: items, logEntries: logEntries)
    }

    func lastCompletion(for itemID: UUID) -> LogEntry? {
        scheduling.lastCompletion(for: itemID)
    }

    func nextDueDate(for item: MaintenanceItem) -> Date {
        scheduling.nextDueDate(for: item)
    }

    func isOverdue(_ item: MaintenanceItem) -> Bool {
        scheduling.isOverdue(item)
    }

    func daysUntilDue(_ item: MaintenanceItem) -> Int {
        scheduling.daysUntilDue(item)
    }

    // MARK: - Computed: Filtered Lists

    var activeItems: [MaintenanceItem] {
        items.filter(\.isActive)
    }

    var filteredActiveItems: [MaintenanceItem] {
        applyingSort(applyingSearchFilter(activeItems))
    }

    /// Every item (active + inactive) with search + sort applied. Used by the "All Items" section
    /// so deactivated items remain discoverable for reactivation.
    var filteredAllItems: [MaintenanceItem] {
        applyingSort(applyingSearchFilter(items))
    }

    var filteredOverdueItems: [MaintenanceItem] {
        applyingSort(applyingSearchFilter(overdueItems))
    }

    var filteredUpcomingItems: [MaintenanceItem] {
        applyingSort(applyingSearchFilter(upcomingItems))
    }

    var filteredIdeaItems: [MaintenanceItem] {
        // Ideas default to "recently updated" order; allow sort override but keep it sensible.
        let filtered = applyingSearchFilter(ideaItems)
        if sortMode == .dueSoonest {
            // "Due" has no meaning for ideas — keep the updatedAt-desc order from ideaItems
            return filtered
        }
        return applyingSort(filtered)
    }

    func applyingSearchFilter(_ items: [MaintenanceItem]) -> [MaintenanceItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return items }

        let tagTokens = query.matches(of: /tag:(\S+)/).map { String($0.output.1).lowercased() }
        let textQuery = query
            .replacing(/tag:\S*/, with: "")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()

        return items.filter { item in
            let matchesTags = tagTokens.allSatisfy { tag in item.tags.contains(tag) }
            let matchesText = textQuery.isEmpty || item.name.lowercased().contains(textQuery) || item.notes.lowercased().contains(textQuery)
            return matchesTags && matchesText
        }
    }

    func applyingSort(_ items: [MaintenanceItem]) -> [MaintenanceItem] {
        switch sortMode {
        case .dueSoonest:
            return items.sorted { nextDueDate(for: $0) < nextDueDate(for: $1) }
        case .priority:
            return items.sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .nameAZ:
            return items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .nameZA:
            return items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
        }
    }

    func cycleSortMode() {
        sortMode = sortMode.next
    }

    func navigateToTag(_ tag: String) {
        searchQuery = "tag:\(tag) "
        navigation = .inventoryAll
        selectedItemID = nil
    }

    var pendingFollowUps: [MaintenanceItem] {
        items.filter { item in
            item.followUps.contains { !$0.isDone }
        }
    }

    var overdueItems: [MaintenanceItem] {
        activeItems
            .filter { isOverdue($0) }
            .sorted { nextDueDate(for: $0) < nextDueDate(for: $1) }
    }

    var upcomingItems: [MaintenanceItem] {
        activeItems
            .filter { !isOverdue($0) && !$0.isIdea }
            .sorted { nextDueDate(for: $0) < nextDueDate(for: $1) }
    }

    var ideaItems: [MaintenanceItem] {
        activeItems
            .filter(\.isIdea)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var recentLogEntries: [LogEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        return logEntries
            .filter { $0.completedDate >= cutoff }
            .sorted { $0.completedDate > $1.completedDate }
    }

    var lowStockItems: [MaintenanceItem] {
        activeItems.filter { $0.supply?.needsReorder == true }
    }

    var onTrackCount: Int {
        activeItems.filter { !isOverdue($0) }.count
    }

    var longestOverdueItem: MaintenanceItem? {
        overdueItems.min { nextDueDate(for: $0) < nextDueDate(for: $1) }
    }

    var allTags: [String] {
        var tagSet = Set<String>()
        for item in items {
            for tag in item.tags { tagSet.insert(tag) }
        }
        for vendor in vendors {
            for tag in vendor.tags { tagSet.insert(tag) }
        }
        return tagSet.sorted()
    }

    func itemsDueInRange(start: Date, end: Date) -> [MaintenanceItem] {
        scheduling.itemsDueInRange(start: start, end: end)
    }

    func logEntries(for itemID: UUID) -> [LogEntry] {
        logEntries
            .filter { $0.itemID == itemID }
            .sorted { $0.completedDate > $1.completedDate }
    }

    func items(for vendorID: UUID) -> [MaintenanceItem] {
        items.filter { $0.vendorID == vendorID }
    }

    func vendor(for item: MaintenanceItem) -> Vendor? {
        guard let vid = item.vendorID else { return nil }
        return vendors.first { $0.id == vid }
    }

    // MARK: - Loading

    func loadAll() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            do {
                let loadedItems = try await persistence.loadItems()
                let loadedLog = try await persistence.loadLogEntries()
                let loadedVendors = try await persistence.loadVendors()
                let loadedSourcings = try await persistence.loadSourcings()
                let loadedMembers = try await persistence.loadMembers()
                let loadedConfig = (try? await persistence.loadConfig()) ?? AppConfig()
                self.items = loadedItems.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.logEntries = loadedLog.sorted { $0.completedDate > $1.completedDate }
                self.vendors = loadedVendors.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.sourcings = loadedSourcings.sorted { $0.updatedAt > $1.updatedAt }
                self.members = loadedMembers
                self.config = loadedConfig
                self.error = nil
                snapshotVersions()
                await syncAllNotifications()
            } catch {
                self.error = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    private func syncAllNotifications() async {
        _ = await notifications?.requestPermission()
        for item in activeItems {
            let due = nextDueDate(for: item)
            await notifications?.syncReminders(item: item, nextDueDate: due, daysBefore: config.defaultReminderDaysBefore)
        }
        for sourcing in sourcings {
            await notifications?.syncSourcingReminder(sourcing: sourcing, daysBefore: config.defaultReminderDaysBefore)
        }
    }

    // MARK: - Undo

    private func registerUndo(_ name: String, handler: @escaping @MainActor (UpkeepStore) -> Void) {
        undoManager?.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                handler(store)
            }
        }
        undoManager?.setActionName(name)
    }

    // MARK: - Item CRUD

    func createItem(name: String, category: MaintenanceCategory = .other, priority: Priority = .medium,
                    scheduleKind: ScheduleKind = .recurring,
                    frequencyInterval: Int = 1, frequencyUnit: FrequencyUnit = .months,
                    startDate: Date = .now, notes: String = "", vendorID: UUID? = nil,
                    supply: Supply? = nil, tags: [String] = [],
                    customIcon: String? = nil,
                    seasonalWindow: SeasonalWindow? = nil) {
        let item = MaintenanceItem(
            name: name, category: category, priority: priority,
            scheduleKind: scheduleKind,
            frequencyInterval: frequencyInterval, frequencyUnit: frequencyUnit,
            startDate: startDate, notes: notes, vendorID: vendorID,
            supply: supply, tags: tags, customIcon: customIcon,
            seasonalWindow: seasonalWindow
        )
        registerUndo("Add Item") { store in store.deleteItem(id: item.id) }
        Task {
            do {
                try await persistence.saveItem(item)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func updateItem(_ item: MaintenanceItem, actionName: String = "Edit Item") {
        if let prev = items.first(where: { $0.id == item.id }) {
            registerUndo(actionName) { store in store.updateItem(prev, actionName: actionName) }
        }
        var updated = item
        updated.touch(by: currentMemberID)
        Task {
            do {
                try await persistence.saveItem(updated)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func deleteItem(id: UUID, deleteLogs: Bool = false) {
        if let item = items.first(where: { $0.id == id }) {
            let linkedLogs = deleteLogs ? logEntries.filter({ $0.itemID == id }) : []
            registerUndo("Delete Item") { store in
                store.restoreItem(item)
                for log in linkedLogs {
                    store.restoreLogEntry(log)
                }
            }
        }
        Task {
            do {
                if deleteLogs {
                    for entry in logEntries where entry.itemID == id {
                        try await persistence.deleteLogEntry(id: entry.id)
                    }
                }
                try await persistence.deleteItem(id: id)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func skipYear(id: UUID) {
        guard var item = items.first(where: { $0.id == id }) else { return }
        let prev = item
        let year = Calendar.current.component(.year, from: .now)
        item.skippedYear = year
        item.touch(by: currentMemberID)
        registerUndo("Skip Year") { store in store.updateItem(prev, actionName: "Undo Skip Year") }
        Task {
            do {
                try await persistence.saveItem(item)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func snoozeItem(id: UUID, days: Int) {
        guard var item = items.first(where: { $0.id == id }) else { return }
        let prev = item
        item.snoozedUntil = Calendar.current.date(byAdding: .day, value: days, to: .now)
        item.touch(by: currentMemberID)
        registerUndo("Snooze Item") { store in store.updateItem(prev, actionName: "Undo Snooze") }
        Task {
            do {
                try await persistence.saveItem(item)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func addTag(_ tag: String, to itemID: UUID) {
        guard var item = items.first(where: { $0.id == itemID }) else { return }
        let prev = item
        let normalized = tag.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty, !item.tags.contains(normalized) else { return }
        item.tags.append(normalized)
        item.touch(by: currentMemberID)
        registerUndo("Add Tag") { store in store.updateItem(prev, actionName: "Remove Tag") }
        Task {
            do {
                try await persistence.saveItem(item)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func removeTag(_ tag: String, from itemID: UUID) {
        guard var item = items.first(where: { $0.id == itemID }) else { return }
        let prev = item
        item.tags.removeAll { $0 == tag }
        item.touch(by: currentMemberID)
        registerUndo("Remove Tag") { store in store.updateItem(prev, actionName: "Add Tag") }
        Task {
            do {
                try await persistence.saveItem(item)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func addFollowUp(to itemID: UUID, title: String, dueDate: Date? = nil) {
        guard var item = items.first(where: { $0.id == itemID }) else { return }
        let prev = item
        let followUp = FollowUp(title: title, dueDate: dueDate)
        item.followUps.append(followUp)
        item.touch(by: currentMemberID)
        registerUndo("Add Follow-Up") { store in store.updateItem(prev, actionName: "Remove Follow-Up") }
        Task {
            do {
                try await persistence.saveItem(item)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func toggleFollowUp(itemID: UUID, followUpID: UUID) {
        guard var item = items.first(where: { $0.id == itemID }),
              let idx = item.followUps.firstIndex(where: { $0.id == followUpID }) else { return }
        let prev = item
        item.followUps[idx].isDone.toggle()
        item.touch(by: currentMemberID)
        registerUndo("Toggle Follow-Up") { store in store.updateItem(prev, actionName: "Toggle Follow-Up") }
        Task {
            do {
                try await persistence.saveItem(item)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func removeFollowUp(itemID: UUID, followUpID: UUID) {
        guard var item = items.first(where: { $0.id == itemID }) else { return }
        let prev = item
        item.followUps.removeAll { $0.id == followUpID }
        item.touch(by: currentMemberID)
        registerUndo("Remove Follow-Up") { store in store.updateItem(prev, actionName: "Add Follow-Up") }
        Task {
            do {
                try await persistence.saveItem(item)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func restoreItem(_ item: MaintenanceItem) {
        registerUndo("Delete Item") { store in store.deleteItem(id: item.id) }
        Task {
            do {
                try await persistence.saveItem(item)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Attachments

    /// Imports a file into the shared attachments/ directory and returns a photo/pdf Attachment.
    /// Throws if copy fails.
    func importAttachmentFile(sourceURL: URL, kind: Attachment.Kind) async throws -> Attachment {
        precondition(kind == .photo || kind == .pdf, "importAttachmentFile only handles copied kinds")
        let ext = sourceURL.pathExtension
        let id = UUID()
        let filename = ext.isEmpty ? id.uuidString : "\(id.uuidString).\(ext)"
        let data = try Data(contentsOf: sourceURL)
        try await persistence.saveAttachmentFile(data, filename: filename)
        return Attachment(
            id: id, kind: kind,
            title: sourceURL.lastPathComponent,
            filename: filename,
            addedAt: .now,
            sizeBytes: Int64(data.count)
        )
    }

    func addAttachmentToItem(itemID: UUID, _ attachment: Attachment) {
        guard var item = items.first(where: { $0.id == itemID }) else { return }
        let prev = item
        item.attachments.append(attachment)
        item.touch(by: currentMemberID)
        registerUndo("Add Attachment") { store in store.updateItem(prev, actionName: "Remove Attachment") }
        Task {
            do {
                try await persistence.saveItem(item)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func removeAttachmentFromItem(itemID: UUID, attachmentID: UUID) {
        guard var item = items.first(where: { $0.id == itemID }),
              let attachment = item.attachments.first(where: { $0.id == attachmentID }) else { return }
        let prev = item
        item.attachments.removeAll { $0.id == attachmentID }
        item.touch(by: currentMemberID)
        registerUndo("Remove Attachment") { store in store.updateItem(prev, actionName: "Add Attachment") }
        Task {
            do {
                try await persistence.saveItem(item)
                if let fn = attachment.filename, attachment.isFileBacked {
                    try? await persistence.deleteAttachmentFile(filename: fn)
                }
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func addAttachmentToLog(entryID: UUID, _ attachment: Attachment) {
        guard var entry = logEntries.first(where: { $0.id == entryID }) else { return }
        let prev = entry
        entry.attachments.append(attachment)
        registerUndo("Add Attachment") { store in store.updateLogEntry(prev, actionName: "Remove Attachment") }
        Task {
            do {
                try await persistence.saveLogEntry(entry)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func removeAttachmentFromLog(entryID: UUID, attachmentID: UUID) {
        guard var entry = logEntries.first(where: { $0.id == entryID }),
              let attachment = entry.attachments.first(where: { $0.id == attachmentID }) else { return }
        let prev = entry
        entry.attachments.removeAll { $0.id == attachmentID }
        registerUndo("Remove Attachment") { store in store.updateLogEntry(prev, actionName: "Add Attachment") }
        Task {
            do {
                try await persistence.saveLogEntry(entry)
                if let fn = attachment.filename, attachment.isFileBacked {
                    try? await persistence.deleteAttachmentFile(filename: fn)
                }
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func attachmentURL(_ attachment: Attachment) -> URL? {
        switch attachment.kind {
        case .photo, .pdf:
            guard let fn = attachment.filename else { return nil }
            return persistence.attachmentsDir.appendingPathComponent(fn)
        case .pdfLink:
            guard let p = attachment.path else { return nil }
            return URL(fileURLWithPath: p)
        case .link:
            guard let s = attachment.url else { return nil }
            return URL(string: s)
        }
    }

    // MARK: - Log Entry CRUD

    func logCompletion(itemID: UUID?, title: String, category: MaintenanceCategory = .other,
                       date: Date = .now, notes: String = "", cost: Decimal? = nil,
                       performedBy: String = "", rating: Int? = nil,
                       markComplete: Bool = true) {
        let entry = LogEntry(
            itemID: itemID, title: title, category: category,
            completedDate: date, notes: notes, cost: cost, performedBy: performedBy,
            rating: rating
        )
        registerUndo("Log Entry") { store in store.deleteLogEntry(id: entry.id) }

        // Apply item-side side effects of completion: supply decrement and/or
        // auto-deactivate for to-do items. Combined so we save the item once.
        if let itemID, var item = items.first(where: { $0.id == itemID }) {
            let prevItem = item
            var modified = false

            if var supply = item.supply {
                supply.stockOnHand = max(0, supply.stockOnHand - supply.quantityPerUse)
                item.supply = supply
                modified = true
            }

            if markComplete && item.isOneTime && item.isActive && config.autoDeactivateCompletedTodos {
                item.isActive = false
                modified = true
            }

            if modified {
                item.touch(by: currentMemberID)
                registerUndo("Complete Item") { store in store.updateItem(prevItem, actionName: "Undo Complete") }
                Task {
                    do {
                        try await persistence.saveItem(item)
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
        }

        Task {
            do {
                try await persistence.saveLogEntry(entry)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func updateSupply(itemID: UUID, stockOnHand: Int) {
        guard var item = items.first(where: { $0.id == itemID }),
              var supply = item.supply else { return }
        let prev = item
        supply.stockOnHand = max(0, stockOnHand)
        item.supply = supply
        item.touch(by: currentMemberID)
        registerUndo("Update Supply") { store in store.updateItem(prev, actionName: "Undo Supply Update") }
        Task {
            do {
                try await persistence.saveItem(item)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func updateLogEntry(_ entry: LogEntry, actionName: String = "Edit Log Entry") {
        if let prev = logEntries.first(where: { $0.id == entry.id }) {
            registerUndo(actionName) { store in store.updateLogEntry(prev, actionName: actionName) }
        }
        Task {
            do {
                try await persistence.saveLogEntry(entry)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func deleteLogEntry(id: UUID) {
        if let entry = logEntries.first(where: { $0.id == id }) {
            registerUndo("Delete Log Entry") { store in store.restoreLogEntry(entry) }
        }
        Task {
            do {
                try await persistence.deleteLogEntry(id: id)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func restoreLogEntry(_ entry: LogEntry) {
        registerUndo("Delete Log Entry") { store in store.deleteLogEntry(id: entry.id) }
        Task {
            do {
                try await persistence.saveLogEntry(entry)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Vendor CRUD

    func createVendor(name: String, phone: String = "", email: String = "",
                      website: String = "", location: String = "",
                      specialty: String = "", tags: [String] = [],
                      accountManager: AccountManager = AccountManager(),
                      notes: String = "", source: String = "",
                      isActive: Bool = true) {
        let vendor = Vendor(
            name: name, phone: phone, email: email,
            website: website, location: location,
            specialty: specialty, tags: tags,
            accountManager: accountManager, notes: notes,
            source: source, isActive: isActive
        )
        registerUndo("Add Vendor") { store in store.deleteVendor(id: vendor.id) }
        Task {
            do {
                try await persistence.saveVendor(vendor)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func updateVendor(_ vendor: Vendor, actionName: String = "Edit Vendor") {
        if let prev = vendors.first(where: { $0.id == vendor.id }) {
            registerUndo(actionName) { store in store.updateVendor(prev, actionName: actionName) }
        }
        var updated = vendor
        updated.touch(by: currentMemberID)
        Task {
            do {
                try await persistence.saveVendor(updated)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func deleteVendor(id: UUID) {
        let affectedItems = items.filter { $0.vendorID == id }
        if let vendor = vendors.first(where: { $0.id == id }) {
            registerUndo("Delete Vendor") { store in
                store.restoreVendor(vendor)
                for item in affectedItems {
                    store.updateItem(item, actionName: "Restore Vendor Link")
                }
            }
        }
        Task {
            do {
                // Clear vendorID from items that reference this vendor
                for var item in affectedItems {
                    item.vendorID = nil
                    try await persistence.saveItem(item)
                }
                try await persistence.deleteVendor(id: id)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func restoreVendor(_ vendor: Vendor) {
        registerUndo("Delete Vendor") { store in store.deleteVendor(id: vendor.id) }
        Task {
            do {
                try await persistence.saveVendor(vendor)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Sourcing

    var activeSourcings: [Sourcing] {
        sourcings.filter(\.isOpen)
    }

    func sourcings(forItem itemID: UUID) -> [Sourcing] {
        sourcings.filter { $0.linkedItemIDs.contains(itemID) }
    }

    func sourcings(replacing vendorID: UUID) -> [Sourcing] {
        sourcings.filter { $0.replacingVendorID == vendorID }
    }

    func sourcing(id: UUID) -> Sourcing? {
        sourcings.first { $0.id == id }
    }

    /// Items that will be reassigned to the winner if `sourcing` is hired.
    /// For replace flows, this is every item currently using the replaced vendor *plus*
    /// any explicitly-linked items that don't currently use it (deduped).
    /// For non-replace flows, just the explicitly-linked items.
    func itemsAffectedOnHire(_ sourcing: Sourcing) -> [MaintenanceItem] {
        var seen = Set<UUID>()
        var affected: [MaintenanceItem] = []
        let linkedItems = sourcing.linkedItemIDs.compactMap { id in
            items.first { $0.id == id }
        }
        if let replacingID = sourcing.replacingVendorID {
            for item in items where item.vendorID == replacingID {
                if seen.insert(item.id).inserted { affected.append(item) }
            }
        }
        for item in linkedItems where seen.insert(item.id).inserted {
            affected.append(item)
        }
        return affected
    }

    func createSourcing(title: String, linkedItemIDs: [UUID] = [],
                        replacingVendorID: UUID? = nil,
                        decideBy: Date? = nil, notes: String = "") {
        let sourcing = Sourcing(
            title: title, linkedItemIDs: linkedItemIDs,
            replacingVendorID: replacingVendorID, decideBy: decideBy,
            notes: notes, lastModifiedBy: currentMemberID
        )
        registerUndo("New Sourcing") { store in store.deleteSourcing(id: sourcing.id) }
        Task {
            do {
                try await persistence.saveSourcing(sourcing)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func updateSourcing(_ sourcing: Sourcing, actionName: String = "Edit Sourcing") {
        if let prev = sourcings.first(where: { $0.id == sourcing.id }) {
            registerUndo(actionName) { store in store.updateSourcing(prev, actionName: actionName) }
        }
        var updated = sourcing
        updated.touch(by: currentMemberID)
        Task {
            do {
                try await persistence.saveSourcing(updated)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func deleteSourcing(id: UUID) {
        if let sourcing = sourcings.first(where: { $0.id == id }) {
            registerUndo("Delete Sourcing") { store in store.restoreSourcing(sourcing) }
        }
        Task {
            do {
                try await persistence.deleteSourcing(id: id)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func restoreSourcing(_ sourcing: Sourcing) {
        registerUndo("Delete Sourcing") { store in store.deleteSourcing(id: sourcing.id) }
        Task {
            do {
                try await persistence.saveSourcing(sourcing)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Candidates

    func addCandidate(to sourcingID: UUID, _ candidate: Candidate) {
        guard var sourcing = sourcings.first(where: { $0.id == sourcingID }) else { return }
        let prev = sourcing
        sourcing.candidates.append(candidate)
        sourcing.touch(by: currentMemberID)
        registerUndo("Add Candidate") { store in store.updateSourcing(prev, actionName: "Remove Candidate") }
        Task {
            do {
                try await persistence.saveSourcing(sourcing)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func updateCandidate(_ candidate: Candidate, in sourcingID: UUID, actionName: String = "Edit Candidate") {
        guard var sourcing = sourcings.first(where: { $0.id == sourcingID }),
              let idx = sourcing.candidates.firstIndex(where: { $0.id == candidate.id }) else { return }
        let prev = sourcing
        sourcing.candidates[idx] = candidate
        sourcing.touch(by: currentMemberID)
        registerUndo(actionName) { store in store.updateSourcing(prev, actionName: actionName) }
        Task {
            do {
                try await persistence.saveSourcing(sourcing)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func removeCandidate(_ candidateID: UUID, from sourcingID: UUID) {
        guard var sourcing = sourcings.first(where: { $0.id == sourcingID }) else { return }
        let prev = sourcing
        sourcing.candidates.removeAll { $0.id == candidateID }
        sourcing.touch(by: currentMemberID)
        registerUndo("Remove Candidate") { store in store.updateSourcing(prev, actionName: "Restore Candidate") }
        Task {
            do {
                try await persistence.saveSourcing(sourcing)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    /// Closes a sourcing by hiring a candidate. Promotes:
    /// - Winner → new active Vendor
    /// - Replaced vendor (if `replacingVendorID` set) → flipped to inactive; **all items** currently using it are reassigned to the winner
    /// - In non-replace flows, only the linked item is reassigned
    /// - Losers reaching `quoted` or above → inactive Vendor records
    /// - Losers below `quoted` → not promoted (snapshot-only)
    /// `extraSavedCandidateIDs` opts in losers below `quoted` to also become inactive vendors.
    func hireCandidate(_ candidateID: UUID, in sourcingID: UUID,
                       extraSavedCandidateIDs: Set<UUID> = []) {
        guard var sourcing = sourcings.first(where: { $0.id == sourcingID }),
              let winnerIdx = sourcing.candidates.firstIndex(where: { $0.id == candidateID }) else { return }

        let now = Date.now
        var newVendors: [Vendor] = []
        var vendorsToUpdate: [Vendor] = []
        var itemsToUpdate: [MaintenanceItem] = []

        // Promote winner → active Vendor
        var winner = sourcing.candidates[winnerIdx]
        let winnerVendor = Vendor(
            name: winner.name, phone: winner.phone, email: winner.email,
            notes: winner.notes, source: winner.source, isActive: true,
            lastModifiedBy: currentMemberID, createdAt: now, updatedAt: now
        )
        winner.status = .hired
        winner.promotedToVendorID = winnerVendor.id
        sourcing.candidates[winnerIdx] = winner
        newVendors.append(winnerVendor)

        // Promote eligible losers → inactive Vendors
        for idx in sourcing.candidates.indices where idx != winnerIdx {
            var c = sourcing.candidates[idx]
            let shouldPromote = c.status.reachedQuoted || extraSavedCandidateIDs.contains(c.id)
            if shouldPromote {
                let v = Vendor(
                    name: c.name, phone: c.phone, email: c.email,
                    notes: c.notes, source: c.source, isActive: false,
                    lastModifiedBy: currentMemberID, createdAt: now, updatedAt: now
                )
                c.promotedToVendorID = v.id
                sourcing.candidates[idx] = c
                newVendors.append(v)
            }
        }

        // Cascade reassignment: every item currently using the replaced vendor (replace flow)
        // OR just the linkedItem (non-replace flow). Use itemsAffectedOnHire to dedupe.
        let affected = itemsAffectedOnHire(sourcing)
        var seenItemIDs = Set<UUID>()
        for item in affected where seenItemIDs.insert(item.id).inserted {
            var updated = item
            updated.vendorID = winnerVendor.id
            updated.touch(by: currentMemberID)
            itemsToUpdate.append(updated)
        }

        // Replace flow: deactivate the old vendor
        if let replacingID = sourcing.replacingVendorID,
           var oldVendor = vendors.first(where: { $0.id == replacingID }) {
            oldVendor.isActive = false
            oldVendor.touch(by: currentMemberID)
            vendorsToUpdate.append(oldVendor)
        }

        sourcing.status = .decided
        sourcing.hiredCandidateID = winner.id
        sourcing.touch(by: currentMemberID)

        Task {
            do {
                for v in newVendors { try await persistence.saveVendor(v) }
                for v in vendorsToUpdate { try await persistence.saveVendor(v) }
                for i in itemsToUpdate { try await persistence.saveItem(i) }
                try await persistence.saveSourcing(sourcing)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Candidate Attachments

    func addAttachmentToCandidate(sourcingID: UUID, candidateID: UUID, _ attachment: Attachment) {
        guard var sourcing = sourcings.first(where: { $0.id == sourcingID }),
              let idx = sourcing.candidates.firstIndex(where: { $0.id == candidateID }) else { return }
        sourcing.candidates[idx].attachments.append(attachment)
        sourcing.touch(by: currentMemberID)
        Task {
            do {
                try await persistence.saveSourcing(sourcing)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func removeAttachmentFromCandidate(sourcingID: UUID, candidateID: UUID, attachmentID: UUID) {
        guard var sourcing = sourcings.first(where: { $0.id == sourcingID }),
              let idx = sourcing.candidates.firstIndex(where: { $0.id == candidateID }),
              let attachment = sourcing.candidates[idx].attachments.first(where: { $0.id == attachmentID })
        else { return }
        sourcing.candidates[idx].attachments.removeAll { $0.id == attachmentID }
        sourcing.touch(by: currentMemberID)
        Task {
            do {
                try await persistence.saveSourcing(sourcing)
                if let fn = attachment.filename, attachment.isFileBacked {
                    try? await persistence.deleteAttachmentFile(filename: fn)
                }
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func cancelSourcing(_ sourcingID: UUID, reason: String = "") {
        guard var sourcing = sourcings.first(where: { $0.id == sourcingID }) else { return }
        let prev = sourcing
        sourcing.status = .cancelled
        sourcing.cancelReason = reason
        sourcing.touch(by: currentMemberID)
        registerUndo("Cancel Sourcing") { store in store.updateSourcing(prev, actionName: "Reopen Sourcing") }
        Task {
            do {
                try await persistence.saveSourcing(sourcing)
                loadAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Members

    func addMember(name: String, color: String = "amber") {
        let member = HouseholdMember(name: name, color: color)
        members.append(member)
        Task {
            do {
                try await persistence.saveMembers(members)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func removeMember(id: UUID) {
        members.removeAll { $0.id == id }
        Task {
            do {
                try await persistence.saveMembers(members)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func updateMember(_ member: HouseholdMember) {
        guard let idx = members.firstIndex(where: { $0.id == member.id }) else { return }
        members[idx] = member
        Task {
            do {
                try await persistence.saveMembers(members)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func memberName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return members.first { $0.id == id }?.name
    }

    // MARK: - Backup

    func backup() async throws -> URL {
        try await persistence.backup()
    }

    func restore(from url: URL) async throws {
        try await persistence.restore(from: url)
        loadAll()
    }

    func listBackups() async throws -> [URL] {
        try await persistence.listBackups()
    }

    // MARK: - Config

    func loadConfig() async throws -> AppConfig {
        try await persistence.loadConfig()
    }

    func saveConfig(_ config: AppConfig) async throws {
        try await persistence.saveConfig(config)
        self.config = config
    }

    // MARK: - Home Profile

    func loadHomeProfile() async throws -> HomeProfile {
        try await persistence.loadHomeProfile()
    }

    func saveHomeProfile(_ profile: HomeProfile) async throws {
        try await persistence.saveHomeProfile(profile)
    }

    // MARK: - Photos

    func savePhoto(_ data: Data, filename: String) async throws {
        try await persistence.savePhoto(data, filename: filename)
    }

    func photoURL(filename: String) -> URL {
        persistence.photosDir.appendingPathComponent(filename)
    }

    // MARK: - Consistency Streaks

    func currentStreak(for itemID: UUID) -> Int {
        scheduling.currentStreak(for: itemID)
    }

    // MARK: - Annual Cost Projection

    var annualCostProjection: Decimal {
        let cal = Calendar.current
        let now = Date.now
        let yearAgo = cal.date(byAdding: .year, value: -1, to: now) ?? now
        let recentEntries = logEntries.filter { $0.completedDate >= yearAgo }
        let totalCost = recentEntries.compactMap(\.cost).reduce(Decimal.zero, +)

        let daysCovered = max(1, cal.dateComponents([.day], from: yearAgo, to: now).day ?? 365)
        let dailyRate = totalCost / Decimal(daysCovered)
        return dailyRate * 365
    }

    // MARK: - Search

    struct SearchResult: Identifiable {
        enum Kind { case item, logEntry, vendor }
        let id: UUID
        let kind: Kind
        let title: String
        let subtitle: String
        let icon: String
        let tint: MaintenanceCategory?
    }

    func search(query: String) -> [SearchResult] {
        let q = query.lowercased()
        guard !q.isEmpty else { return [] }
        var results: [SearchResult] = []

        for item in items where item.name.lowercased().contains(q)
            || item.tags.contains(where: { $0.contains(q) })
            || item.notes.lowercased().contains(q)
            || (item.supply?.productName.lowercased().contains(q) == true)
            || item.followUps.contains(where: { $0.title.lowercased().contains(q) }) {
            results.append(SearchResult(id: item.id, kind: .item, title: item.name,
                                        subtitle: "\(item.category.label) ~ \(item.frequencyDescription)",
                                        icon: item.effectiveIcon, tint: item.category))
        }

        for entry in logEntries where entry.title.lowercased().contains(q) || entry.notes.lowercased().contains(q) {
            results.append(SearchResult(id: entry.id, kind: .logEntry, title: entry.title,
                                        subtitle: entry.completedDate.shortDate,
                                        icon: "book", tint: entry.category))
        }

        for vendor in vendors where vendor.name.lowercased().contains(q)
            || vendor.specialty.lowercased().contains(q)
            || vendor.notes.lowercased().contains(q)
            || vendor.tags.contains(where: { $0.contains(q) }) {
            results.append(SearchResult(id: vendor.id, kind: .vendor, title: vendor.name,
                                        subtitle: vendor.specialty.isEmpty ? "Vendor" : vendor.specialty,
                                        icon: "person.circle", tint: nil))
        }

        return Array(results.prefix(20))
    }
}
