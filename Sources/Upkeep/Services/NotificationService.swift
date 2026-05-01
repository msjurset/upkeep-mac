import Foundation
import UserNotifications

actor NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Scheduling

    func scheduleDueReminder(itemID: UUID, itemName: String, dueDate: Date, daysBefore: Int) async {
        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: dueDate),
              reminderDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Maintenance Due Soon"
        content.body = "\(itemName) is due in \(daysBefore) \(daysBefore == 1 ? "day" : "days")."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let id = reminderID(itemID: itemID, suffix: "due")
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func scheduleOverdueReminder(itemID: UUID, itemName: String, dueDate: Date) async {
        guard dueDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Maintenance Overdue"
        content.body = "\(itemName) is now overdue."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let id = reminderID(itemID: itemID, suffix: "overdue")
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: - Cancellation

    func cancelReminders(itemID: UUID) async {
        let pending = await center.pendingNotificationRequests()
        let prefix = "upkeep-\(itemID.uuidString)"
        let matching = pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: matching)
    }

    // MARK: - Sync

    func syncReminders(item: MaintenanceItem, nextDueDate: Date, daysBefore: Int) async {
        await cancelReminders(itemID: item.id)
        guard item.isActive else { return }
        await scheduleDueReminder(itemID: item.id, itemName: item.name, dueDate: nextDueDate, daysBefore: daysBefore)
        await scheduleOverdueReminder(itemID: item.id, itemName: item.name, dueDate: nextDueDate)
    }

    // MARK: - Sourcing

    func scheduleSourcingReminder(sourcingID: UUID, title: String, decideBy: Date, daysBefore: Int) async {
        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: decideBy),
              reminderDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Sourcing Decision Approaching"
        content.body = "\(title) — decide by \(decideBy.shortDate)."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let id = sourcingReminderID(sourcingID: sourcingID)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancelSourcingReminder(sourcingID: UUID) async {
        let id = sourcingReminderID(sourcingID: sourcingID)
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    func syncSourcingReminder(sourcing: Sourcing, daysBefore: Int) async {
        await cancelSourcingReminder(sourcingID: sourcing.id)
        guard sourcing.isOpen, let decideBy = sourcing.decideBy else { return }
        await scheduleSourcingReminder(
            sourcingID: sourcing.id,
            title: sourcing.title,
            decideBy: decideBy,
            daysBefore: daysBefore
        )
    }

    // MARK: - Identifiers

    private func reminderID(itemID: UUID, suffix: String) -> String {
        "upkeep-\(itemID.uuidString)-\(suffix)"
    }

    private func sourcingReminderID(sourcingID: UUID) -> String {
        "upkeep-sourcing-\(sourcingID.uuidString)"
    }
}
