import SwiftUI

@Observable
@MainActor
final class UpkeepStore {
    var items: [MaintenanceItem] = []
    var logEntries: [LogEntry] = []
    var vendors: [Vendor] = []
    var members: [HouseholdMember] = []

    var navigation: NavigationItem? = .dashboard {
        didSet {
            if let navigation {
                localConfig.lastNavigationKey = navigation.sectionKey
                localConfig.save()
            }
        }
    }
    var selectedItemID: UUID?
    var selectedVendorID: UUID?
    var selectedLogEntryID: UUID?
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
                let loadedMembers = try await persistence.loadMembers()

                // Detect conflicts before replacing in-memory model
                detectConflicts(newItems: loadedItems, newVendors: loadedVendors)

                self.items = loadedItems.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.logEntries = loadedLog.sorted { $0.completedDate > $1.completedDate }
                self.vendors = loadedVendors.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return activeItems }

        let tagTokens = query.matches(of: /tag:(\S+)/).map { String($0.output.1).lowercased() }
        let textQuery = query
            .replacing(/tag:\S*/, with: "")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()

        return activeItems.filter { item in
            let matchesTags = tagTokens.allSatisfy { tag in item.tags.contains(tag) }
            let matchesText = textQuery.isEmpty || item.name.lowercased().contains(textQuery) || item.notes.lowercased().contains(textQuery)
            return matchesTags && matchesText
        }
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
            .filter { !isOverdue($0) }
            .sorted { nextDueDate(for: $0) < nextDueDate(for: $1) }
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
                let loadedMembers = try await persistence.loadMembers()
                self.items = loadedItems.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.logEntries = loadedLog.sorted { $0.completedDate > $1.completedDate }
                self.vendors = loadedVendors.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.members = loadedMembers
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
        let config = (try? await persistence.loadConfig()) ?? AppConfig()
        _ = await notifications?.requestPermission()
        for item in activeItems {
            let due = nextDueDate(for: item)
            await notifications?.syncReminders(item: item, nextDueDate: due, daysBefore: config.defaultReminderDaysBefore)
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
                    frequencyInterval: Int = 1, frequencyUnit: FrequencyUnit = .months,
                    startDate: Date = .now, notes: String = "", vendorID: UUID? = nil,
                    supply: Supply? = nil, tags: [String] = [],
                    seasonalWindow: SeasonalWindow? = nil) {
        let item = MaintenanceItem(
            name: name, category: category, priority: priority,
            frequencyInterval: frequencyInterval, frequencyUnit: frequencyUnit,
            startDate: startDate, notes: notes, vendorID: vendorID,
            supply: supply, tags: tags, seasonalWindow: seasonalWindow
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

    // MARK: - Log Entry CRUD

    func logCompletion(itemID: UUID?, title: String, category: MaintenanceCategory = .other,
                       date: Date = .now, notes: String = "", cost: Decimal? = nil,
                       performedBy: String = "", rating: Int? = nil) {
        let entry = LogEntry(
            itemID: itemID, title: title, category: category,
            completedDate: date, notes: notes, cost: cost, performedBy: performedBy,
            rating: rating
        )
        registerUndo("Log Entry") { store in store.deleteLogEntry(id: entry.id) }

        // Decrement supply stock if the linked item tracks supplies
        if let itemID, var item = items.first(where: { $0.id == itemID }),
           var supply = item.supply {
            let prevItem = item
            supply.stockOnHand = max(0, supply.stockOnHand - supply.quantityPerUse)
            item.supply = supply
            item.touch(by: currentMemberID)
            registerUndo("Decrement Supply") { store in store.updateItem(prevItem, actionName: "Undo Supply Change") }
            Task {
                do {
                    try await persistence.saveItem(item)
                } catch {
                    self.error = error.localizedDescription
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
                      notes: String = "") {
        let vendor = Vendor(
            name: name, phone: phone, email: email,
            website: website, location: location,
            specialty: specialty, tags: tags,
            accountManager: accountManager, notes: notes
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
                                        icon: item.category.icon, tint: item.category))
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
