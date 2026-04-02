#!/usr/bin/env swift

import Foundation

let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

// Mirror the app's model structs for standalone script use

struct Supply: Codable {
    var stockOnHand: Int
    var quantityPerUse: Int
    var productName: String
    var productURL: String
    var unitCost: Decimal?
}

struct MaintenanceItem: Codable {
    var id: UUID
    var name: String
    var category: String
    var priority: String
    var frequencyInterval: Int
    var frequencyUnit: String
    var startDate: Date
    var notes: String
    var vendorID: UUID?
    var supply: Supply?
    var tags: [String]
    var snoozedUntil: Date?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct LogEntry: Codable {
    var id: UUID
    var itemID: UUID?
    var title: String
    var category: String
    var completedDate: Date
    var notes: String
    var cost: Decimal?
    var performedBy: String
    var createdAt: Date
}

struct Vendor: Codable {
    var id: UUID
    var name: String
    var phone: String
    var email: String
    var website: String
    var specialty: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date
}

let now = Date()
let cal = Calendar.current
let home = FileManager.default.homeDirectoryForCurrentUser
let fm = FileManager.default

func daysAgo(_ days: Int) -> Date {
    cal.date(byAdding: .day, value: -days, to: now)!
}

func monthsAgo(_ months: Int) -> Date {
    cal.date(byAdding: .month, value: -months, to: now)!
}

// Ensure directories
for path in [".upkeep", ".upkeep/items", ".upkeep/log", ".upkeep/vendors"] {
    let url = home.appendingPathComponent(path)
    if !fm.fileExists(atPath: url.path) {
        try! fm.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

let itemsDir = home.appendingPathComponent(".upkeep/items")
if let existing = try? fm.contentsOfDirectory(at: itemsDir, includingPropertiesForKeys: nil),
   existing.contains(where: { $0.pathExtension == "json" }) {
    print("Data already exists in ~/.upkeep/")
    print("To re-seed, remove existing data first: rm -rf ~/.upkeep/{items,log,vendors}/*.json")
    Foundation.exit(0)
}

// --- Vendors ---

let hvacPro = Vendor(
    id: UUID(), name: "Comfort Air Systems", phone: "(555) 234-5678",
    email: "service@comfortair.example.com", website: "comfortair.example.com",
    specialty: "HVAC installation & repair", notes: "Annual service contract. Ask for Mike.",
    createdAt: now, updatedAt: now
)

let plumber = Vendor(
    id: UUID(), name: "Reliable Plumbing Co.", phone: "(555) 345-6789",
    email: "info@reliableplumbing.example.com", website: "reliableplumbing.example.com",
    specialty: "Residential plumbing", notes: "24-hour emergency service available.",
    createdAt: now, updatedAt: now
)

let electrician = Vendor(
    id: UUID(), name: "BrightWire Electric", phone: "(555) 456-7890",
    email: "jobs@brightwire.example.com", website: "",
    specialty: "Residential electrical", notes: "Licensed & insured. Good with older wiring.",
    createdAt: now, updatedAt: now
)

let lawnCare = Vendor(
    id: UUID(), name: "Green Thumb Landscaping", phone: "(555) 567-8901",
    email: "hello@greenthumb.example.com", website: "greenthumb.example.com",
    specialty: "Lawn care & landscaping", notes: "Bi-weekly mowing service in summer.",
    createdAt: now, updatedAt: now
)

let roofing = Vendor(
    id: UUID(), name: "Summit Roofing", phone: "(555) 678-9012",
    email: "", website: "summitroofing.example.com",
    specialty: "Roof inspection & repair", notes: "Did the roof replacement in 2023.",
    createdAt: now, updatedAt: now
)

let vendors = [hvacPro, plumber, electrician, lawnCare, roofing]

// --- Maintenance Items ---

let hvacFilter = MaintenanceItem(
    id: UUID(), name: "Replace HVAC filter", category: "hvac", priority: "high",
    frequencyInterval: 3, frequencyUnit: "months", startDate: monthsAgo(4),
    notes: "Use MERV 13 filters. Size: 20x25x1. Stored in garage.",
    vendorID: nil,
    supply: Supply(stockOnHand: 1, quantityPerUse: 1, productName: "Filtrete MERV 13 20x25x1 (6-pack)",
                   productURL: "https://www.amazon.com/dp/B0002YPBRY", unitCost: 18.99),
    tags: ["hvac", "monthly-task"], snoozedUntil: nil,
    isActive: true, createdAt: monthsAgo(12), updatedAt: now
)

let hvacService = MaintenanceItem(
    id: UUID(), name: "Annual HVAC tune-up", category: "hvac", priority: "medium",
    frequencyInterval: 1, frequencyUnit: "years", startDate: monthsAgo(10),
    notes: "Spring tune-up for AC, fall tune-up for heating. Service contract with Comfort Air.",
    vendorID: hvacPro.id, tags: ["hvac", "annual"], snoozedUntil: nil, isActive: true, createdAt: monthsAgo(12), updatedAt: now
)

let gutters = MaintenanceItem(
    id: UUID(), name: "Clean gutters", category: "exterior", priority: "high",
    frequencyInterval: 6, frequencyUnit: "months", startDate: monthsAgo(5),
    notes: "Spring and fall. Check downspouts for clogs. Watch for loose brackets on south side.",
    vendorID: nil, tags: [], snoozedUntil: nil, isActive: true, createdAt: monthsAgo(12), updatedAt: now
)

let waterHeater = MaintenanceItem(
    id: UUID(), name: "Flush water heater", category: "plumbing", priority: "medium",
    frequencyInterval: 1, frequencyUnit: "years", startDate: monthsAgo(11),
    notes: "Drain sediment from tank. Check anode rod — replace if heavily corroded.",
    vendorID: plumber.id, tags: ["plumbing", "annual"], snoozedUntil: nil, isActive: true, createdAt: monthsAgo(12), updatedAt: now
)

let smokeDetectors = MaintenanceItem(
    id: UUID(), name: "Test smoke & CO detectors", category: "safety", priority: "critical",
    frequencyInterval: 6, frequencyUnit: "months", startDate: monthsAgo(5),
    notes: "Test all units. Replace batteries annually. Replace units every 10 years.",
    vendorID: nil, tags: [], snoozedUntil: nil, isActive: true, createdAt: monthsAgo(12), updatedAt: now
)

let fireExtinguisher = MaintenanceItem(
    id: UUID(), name: "Inspect fire extinguishers", category: "safety", priority: "high",
    frequencyInterval: 1, frequencyUnit: "years", startDate: monthsAgo(9),
    notes: "Check pressure gauge. Kitchen and garage units. Replace if older than 12 years.",
    vendorID: nil, tags: [], snoozedUntil: nil, isActive: true, createdAt: monthsAgo(12), updatedAt: now
)

let roofInspection = MaintenanceItem(
    id: UUID(), name: "Roof inspection", category: "exterior", priority: "medium",
    frequencyInterval: 1, frequencyUnit: "years", startDate: monthsAgo(8),
    notes: "Look for missing/damaged shingles, flashing issues, moss growth.",
    vendorID: roofing.id, tags: ["exterior", "annual"], snoozedUntil: nil, isActive: true, createdAt: monthsAgo(12), updatedAt: now
)

let deckStain = MaintenanceItem(
    id: UUID(), name: "Stain & seal deck", category: "exterior", priority: "low",
    frequencyInterval: 2, frequencyUnit: "years", startDate: monthsAgo(18),
    notes: "Power wash first, let dry 48 hours. Use semi-transparent oil-based stain.",
    vendorID: nil, tags: [], snoozedUntil: nil, isActive: true, createdAt: monthsAgo(24), updatedAt: now
)

let dryer = MaintenanceItem(
    id: UUID(), name: "Clean dryer vent", category: "appliances", priority: "high",
    frequencyInterval: 1, frequencyUnit: "years", startDate: monthsAgo(10),
    notes: "Remove lint from full duct run, not just trap. Fire hazard if neglected.",
    vendorID: nil, tags: [], snoozedUntil: nil, isActive: true, createdAt: monthsAgo(12), updatedAt: now
)

let fridge = MaintenanceItem(
    id: UUID(), name: "Clean refrigerator coils", category: "appliances", priority: "low",
    frequencyInterval: 1, frequencyUnit: "years", startDate: monthsAgo(7),
    notes: "Coils are on the back. Pull unit out, vacuum coils and floor underneath.",
    vendorID: nil, tags: [], snoozedUntil: nil, isActive: true, createdAt: monthsAgo(12), updatedAt: now
)

let furnaceFilter = MaintenanceItem(
    id: UUID(), name: "Replace furnace filter", category: "hvac", priority: "high",
    frequencyInterval: 1, frequencyUnit: "months", startDate: daysAgo(45),
    notes: "Use same MERV 13 as HVAC. More frequent in winter when heating runs constantly.",
    vendorID: nil,
    supply: Supply(stockOnHand: 3, quantityPerUse: 1, productName: "Filtrete MERV 13 16x25x1 (4-pack)",
                   productURL: "https://www.amazon.com/dp/B0000AXVLM", unitCost: 12.99),
    tags: ["hvac", "monthly-task"], snoozedUntil: nil, isActive: true, createdAt: monthsAgo(6), updatedAt: now
)

let lawnMower = MaintenanceItem(
    id: UUID(), name: "Service lawn mower", category: "lawnAndGarden", priority: "medium",
    frequencyInterval: 1, frequencyUnit: "years", startDate: monthsAgo(10),
    notes: "Change oil, replace spark plug, sharpen blade. Do in early spring.",
    vendorID: nil, tags: [], snoozedUntil: nil, isActive: true, createdAt: monthsAgo(12), updatedAt: now
)

let caulking = MaintenanceItem(
    id: UUID(), name: "Inspect & replace caulking", category: "exterior", priority: "low",
    frequencyInterval: 1, frequencyUnit: "years", startDate: monthsAgo(6),
    notes: "Check around windows, doors, and where siding meets trim. Bathroom caulk too.",
    vendorID: nil, tags: [], snoozedUntil: nil, isActive: true, createdAt: monthsAgo(12), updatedAt: now
)

let garageDoor = MaintenanceItem(
    id: UUID(), name: "Lubricate garage door", category: "exterior", priority: "low",
    frequencyInterval: 6, frequencyUnit: "months", startDate: monthsAgo(4),
    notes: "White lithium grease on tracks, hinges, springs, and rollers. Test auto-reverse.",
    vendorID: nil, tags: [], snoozedUntil: nil, isActive: true, createdAt: monthsAgo(12), updatedAt: now
)

let treeTriming = MaintenanceItem(
    id: UUID(), name: "Trim trees & shrubs", category: "lawnAndGarden", priority: "low",
    frequencyInterval: 1, frequencyUnit: "years", startDate: monthsAgo(7),
    notes: "Keep branches away from house and power lines. Late winter for deciduous trees.",
    vendorID: lawnCare.id, tags: ["spring-prep", "exterior"], snoozedUntil: nil, isActive: true, createdAt: monthsAgo(12), updatedAt: now
)

let waterSoftener = MaintenanceItem(
    id: UUID(), name: "Add salt to water softener", category: "plumbing", priority: "medium",
    frequencyInterval: 2, frequencyUnit: "months", startDate: monthsAgo(1),
    notes: "Use solar salt crystals. Keep tank at least half full.",
    vendorID: nil,
    supply: Supply(stockOnHand: 2, quantityPerUse: 1, productName: "Morton Solar Salt 40lb bag",
                   productURL: "https://www.amazon.com/dp/B000LNWXUM", unitCost: 6.99),
    tags: ["plumbing"], snoozedUntil: nil, isActive: true, createdAt: monthsAgo(6), updatedAt: now
)

let items = [
    hvacFilter, hvacService, gutters, waterHeater, smokeDetectors,
    fireExtinguisher, roofInspection, deckStain, dryer, fridge,
    furnaceFilter, lawnMower, caulking, garageDoor, treeTriming, waterSoftener
]

// --- Log Entries (maintenance history) ---

var logEntries: [LogEntry] = []

func log(_ title: String, itemID: UUID?, category: String, daysAgo d: Int,
         notes: String = "", cost: Decimal? = nil, by: String = "") -> LogEntry {
    LogEntry(id: UUID(), itemID: itemID, title: title, category: category,
             completedDate: daysAgo(d), notes: notes, cost: cost, performedBy: by,
             createdAt: daysAgo(d))
}

// HVAC filter changes (every ~3 months)
logEntries.append(log("Replaced HVAC filter", itemID: hvacFilter.id, category: "hvac", daysAgo: 8, notes: "MERV 13, 20x25x1", cost: 18.99, by: "Self"))
logEntries.append(log("Replaced HVAC filter", itemID: hvacFilter.id, category: "hvac", daysAgo: 98, notes: "MERV 13", cost: 18.99, by: "Self"))
logEntries.append(log("Replaced HVAC filter", itemID: hvacFilter.id, category: "hvac", daysAgo: 188, notes: "MERV 13", cost: 17.49, by: "Self"))

// Furnace filter (monthly)
logEntries.append(log("Replaced furnace filter", itemID: furnaceFilter.id, category: "hvac", daysAgo: 15, cost: 12.99, by: "Self"))
logEntries.append(log("Replaced furnace filter", itemID: furnaceFilter.id, category: "hvac", daysAgo: 45, cost: 12.99, by: "Self"))

// HVAC annual tune-up
logEntries.append(log("Annual AC tune-up", itemID: hvacService.id, category: "hvac", daysAgo: 120, notes: "Recharged refrigerant. System running well. Recommend new filter more often in summer.", cost: 189, by: "Comfort Air Systems"))

// Gutters
logEntries.append(log("Cleaned gutters — fall", itemID: gutters.id, category: "exterior", daysAgo: 160, notes: "Lots of leaves on south side. Tightened one bracket.", by: "Self"))

// Water heater flush
logEntries.append(log("Flushed water heater", itemID: waterHeater.id, category: "plumbing", daysAgo: 200, notes: "Some sediment. Anode rod looks ok for now.", cost: 0, by: "Self"))

// Smoke detectors
logEntries.append(log("Tested smoke & CO detectors", itemID: smokeDetectors.id, category: "safety", daysAgo: 30, notes: "All 6 units tested OK. Replaced batteries in upstairs hallway unit.", cost: 8.99, by: "Self"))

// Fire extinguisher
logEntries.append(log("Inspected fire extinguishers", itemID: fireExtinguisher.id, category: "safety", daysAgo: 150, notes: "Kitchen and garage both OK. Pressure in green.", by: "Self"))

// Roof
logEntries.append(log("Annual roof inspection", itemID: roofInspection.id, category: "exterior", daysAgo: 240, notes: "No issues found. A few moss spots on north side — will monitor.", cost: 150, by: "Summit Roofing"))

// Dryer vent
logEntries.append(log("Cleaned dryer vent", itemID: dryer.id, category: "appliances", daysAgo: 100, notes: "Significant lint buildup in the duct. Used brush kit from garage.", by: "Self"))

// Fridge coils
logEntries.append(log("Cleaned refrigerator coils", itemID: fridge.id, category: "appliances", daysAgo: 210, notes: "Very dusty. Should do this more often.", by: "Self"))

// Lawn mower
logEntries.append(log("Serviced lawn mower", itemID: lawnMower.id, category: "lawnAndGarden", daysAgo: 330, notes: "Oil change, new spark plug, sharpened blade.", cost: 32, by: "Self"))

// Garage door
logEntries.append(log("Lubricated garage door", itemID: garageDoor.id, category: "exterior", daysAgo: 60, notes: "White lithium grease on all moving parts. Auto-reverse working.", by: "Self"))

// Water softener
logEntries.append(log("Added salt to water softener", itemID: waterSoftener.id, category: "plumbing", daysAgo: 20, notes: "40 lb bag of solar crystals.", cost: 6.99, by: "Self"))
logEntries.append(log("Added salt to water softener", itemID: waterSoftener.id, category: "plumbing", daysAgo: 80, cost: 6.99, by: "Self"))

// Standalone entries (one-off work, not linked to recurring items)
logEntries.append(log("Fixed loose porch railing", itemID: nil, category: "exterior", daysAgo: 45, notes: "Two bolts were loose. Tightened and added thread locker.", by: "Self"))
logEntries.append(log("Replaced kitchen faucet", itemID: nil, category: "plumbing", daysAgo: 75, notes: "Old faucet was dripping. Installed Moen Arbor pulldown.", cost: 287, by: "Reliable Plumbing Co."))
logEntries.append(log("Patched drywall in hallway", itemID: nil, category: "interior", daysAgo: 110, notes: "Small hole from doorknob. Spackle, sand, prime, paint.", cost: 12, by: "Self"))
logEntries.append(log("Replaced outdoor light fixtures", itemID: nil, category: "electrical", daysAgo: 180, notes: "Front porch and back door. LED fixtures, much brighter.", cost: 156, by: "BrightWire Electric"))
logEntries.append(log("Repaired fence gate latch", itemID: nil, category: "exterior", daysAgo: 250, notes: "Gate wasn't closing properly. Adjusted hinges and replaced latch.", cost: 24, by: "Self"))

// --- Write everything ---

print("Writing vendors...")
let vendorsDir = home.appendingPathComponent(".upkeep/vendors")
for vendor in vendors {
    let data = try! encoder.encode(vendor)
    try! data.write(to: vendorsDir.appendingPathComponent("\(vendor.id.uuidString).json"))
    print("  \(vendor.name) (\(vendor.specialty))")
}

print("\nWriting maintenance items...")
for item in items {
    let data = try! encoder.encode(item)
    try! data.write(to: itemsDir.appendingPathComponent("\(item.id.uuidString).json"))
    print("  \(item.name) — every \(item.frequencyInterval) \(item.frequencyUnit)")
}

print("\nWriting log entries...")
let logDir = home.appendingPathComponent(".upkeep/log")
for entry in logEntries {
    let data = try! encoder.encode(entry)
    try! data.write(to: logDir.appendingPathComponent("\(entry.id.uuidString).json"))
}
print("  \(logEntries.count) entries (\(logEntries.filter { $0.itemID == nil }.count) standalone)")

let totalCost = logEntries.compactMap(\.cost).reduce(Decimal.zero, +)
print("\nSeed complete!")
print("  \(vendors.count) vendors")
print("  \(items.count) maintenance items")
print("  \(logEntries.count) log entries")
print("  Total logged cost: $\(totalCost)")
