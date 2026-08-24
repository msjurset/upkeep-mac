import SwiftUI

// MARK: - Procedure Phase

enum ProcedurePhase: String, Codable, CaseIterable, Identifiable {
    case winterization
    case springOpening
    case seasonalPrep
    case inspection
    case general

    var id: String { rawValue }

    var label: String {
        switch self {
        case .winterization: "Winterization"
        case .springOpening: "Spring Opening"
        case .seasonalPrep: "Seasonal Prep"
        case .inspection: "Home Inspection"
        case .general: "General Procedure"
        }
    }

    var icon: String {
        switch self {
        case .winterization: "snowflake"
        case .springOpening: "sun.max.fill"
        case .seasonalPrep: "leaf.fill"
        case .inspection: "checkmark.shield.fill"
        case .general: "checklist"
        }
    }

    var color: Color {
        switch self {
        case .winterization: .blue
        case .springOpening: .orange
        case .seasonalPrep: .upkeepGreen
        case .inspection: .purple
        case .general: .upkeepAmber
        }
    }
}

// MARK: - Procedure Step

struct ProcedureStep: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var text: String
    var notes: String?
    var isComplete: Bool = false
    var completedAt: Date?
    var linkedItemID: UUID?
    var sortOrder: Int = 0

    init(
        id: UUID = UUID(),
        text: String,
        notes: String? = nil,
        isComplete: Bool = false,
        completedAt: Date? = nil,
        linkedItemID: UUID? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.text = text
        self.notes = notes
        self.isComplete = isComplete
        self.completedAt = completedAt
        self.linkedItemID = linkedItemID
        self.sortOrder = sortOrder
    }
}

// MARK: - Procedure Model

struct Procedure: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var propertyIDs: [UUID] = []
    var name: String
    var phase: ProcedurePhase = .winterization
    var steps: [ProcedureStep] = []
    var scheduledWindow: SeasonalWindow?
    var startedAt: Date = Date.now
    var completedAt: Date?
    var notes: String = ""
    var isCollapsed: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var propertyID: UUID? {
        get { propertyIDs.first }
        set {
            if let newValue {
                if !propertyIDs.contains(newValue) { propertyIDs.append(newValue) }
            }
        }
    }

    init(
        id: UUID = UUID(),
        propertyIDs: [UUID] = [],
        propertyID: UUID? = nil,
        name: String,
        phase: ProcedurePhase = .winterization,
        steps: [ProcedureStep] = [],
        scheduledWindow: SeasonalWindow? = nil,
        startedAt: Date = Date.now,
        completedAt: Date? = nil,
        notes: String = "",
        isCollapsed: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date.now,
        updatedAt: Date = Date.now
    ) {
        self.id = id
        if !propertyIDs.isEmpty {
            self.propertyIDs = propertyIDs
        } else if let propertyID {
            self.propertyIDs = [propertyID]
        } else {
            self.propertyIDs = []
        }
        self.name = name
        self.phase = phase
        self.steps = steps
        self.scheduledWindow = scheduledWindow
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.notes = notes
        self.isCollapsed = isCollapsed
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, propertyIDs, propertyID, name, phase, steps, scheduledWindow, startedAt, completedAt, notes, isCollapsed, sortOrder, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        if let ids = try container.decodeIfPresent([UUID].self, forKey: .propertyIDs) {
            propertyIDs = ids
        } else if let singleID = try container.decodeIfPresent(UUID.self, forKey: .propertyID) {
            propertyIDs = [singleID]
        } else {
            propertyIDs = []
        }
        name = try container.decode(String.self, forKey: .name)
        phase = try container.decodeIfPresent(ProcedurePhase.self, forKey: .phase) ?? .winterization
        steps = try container.decodeIfPresent([ProcedureStep].self, forKey: .steps) ?? []
        scheduledWindow = try container.decodeIfPresent(SeasonalWindow.self, forKey: .scheduledWindow)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? .now
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(propertyIDs, forKey: .propertyIDs)
        try container.encode(propertyID, forKey: .propertyID)
        try container.encode(name, forKey: .name)
        try container.encode(phase, forKey: .phase)
        try container.encode(steps, forKey: .steps)
        try container.encodeIfPresent(scheduledWindow, forKey: .scheduledWindow)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(notes, forKey: .notes)
        try container.encode(isCollapsed, forKey: .isCollapsed)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    var completedCount: Int {
        steps.filter { $0.isComplete }.count
    }

    var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(completedCount) / Double(steps.count)
    }

    var isFullyCompleted: Bool {
        !steps.isEmpty && completedCount == steps.count
    }

    mutating func touch() {
        updatedAt = Date.now
    }
}

// MARK: - Built-In Procedure Templates

extension Procedure {
    struct BuiltInTemplate: Identifiable, Hashable {
        let id: String
        let title: String
        let icon: String
        let phase: ProcedurePhase
        let create: (UUID?) -> Procedure

        static func == (lhs: BuiltInTemplate, rhs: BuiltInTemplate) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    @MainActor static let builtInTemplates: [BuiltInTemplate] = [
        BuiltInTemplate(id: "winterization", title: "Lake House Winterization", icon: "snowflake", phase: .winterization, create: defaultWinterizationTemplate),
        BuiltInTemplate(id: "springOpening", title: "Lake House Spring Opening", icon: "sun.max.fill", phase: .springOpening, create: defaultSpringOpeningTemplate),
        BuiltInTemplate(id: "inspection", title: "Fall Home & Property Inspection", icon: "checkmark.shield.fill", phase: .inspection, create: defaultInspectionTemplate)
    ]

    static func defaultWinterizationTemplate(propertyID: UUID? = nil) -> Procedure {
        Procedure(
            propertyID: propertyID,
            name: "Northern Lake House Winterization",
            phase: .winterization,
            steps: [
                // Phase 1: Utilities, Services & Subscriptions
                ProcedureStep(text: "Contact Arvig for Internet winter suspension rate", notes: "Request winter suspension rate ($24/mo) from Nov 1 – May 1 while maintaining cellular/internet monitoring for thermostat & security cameras.", sortOrder: 0),
                ProcedureStep(text: "Suspend garbage service (Ballards)", notes: "Call Ballards (218-863-1386) to suspend seasonal service (active May–Oct).", sortOrder: 1),
                ProcedureStep(text: "Schedule Cox activation in AZ", notes: "Call Cox 1 week ahead of arrival to connect internet/cable service in Arizona.", sortOrder: 2),
                ProcedureStep(text: "Update vehicle insurance coverage", notes: "Switch pickup truck insurance to comprehensive storage coverage only (leave Lincoln insurance unchanged).", sortOrder: 3),

                // Phase 2: Travel, Mail & Personal Documents
                ProcedureStep(text: "Change mailing address & place mail hold", notes: "File mail forwarding with USPS to AZ address and place hold on AZ mail until arrival.", sortOrder: 4),
                ProcedureStep(text: "Update Express Scripts delivery address", notes: "Change delivery address to Arizona for Express Scripts pharmacy.", sortOrder: 5),
                ProcedureStep(text: "Organize tax & legal documents to bring", notes: "Pack current year tax files, necessary medical records, wills, and Power of Attorney (POA) documents.", sortOrder: 6),
                ProcedureStep(text: "Complete annual vaccinations before trip", notes: "Ensure Flu, COVID, and RSV vaccinations are up to date.", sortOrder: 7),
                ProcedureStep(text: "Prepare travel logistics & airline passes", notes: "Print airline boarding passes, pack phone chargers & cables, and schedule airport car/driver pickup.", sortOrder: 8),

                // Phase 3: Docks, Boats, Vehicles & Lawn Care
                ProcedureStep(text: "Schedule & complete boat dock & watercraft lift removal", notes: "Call Superior for dock and lift removal. Inspect cables and winches before winter storage.", sortOrder: 9),
                ProcedureStep(text: "Winterize & protect pontoon boat", notes: "Cover pontoon boat and place Downy sheets on beds/upholstery for pest prevention.", sortOrder: 10),
                ProcedureStep(text: "Service & store lawn mowers", notes: "Perform seasonal maintenance on lawn mowers, drain fuel or add stabilizer, and store in shed.", sortOrder: 11),
                ProcedureStep(text: "Store lawn furniture & cover outdoor equipment", notes: "Cover or store patio furniture, grill, and air conditioner condenser against heavy snow and ice.", sortOrder: 12),
                ProcedureStep(text: "Clean out rain gutters & downspouts", notes: "Clear fallen autumn leaves to prevent ice dams.", sortOrder: 13),
                ProcedureStep(text: "Attach trickle chargers to stored vehicles", notes: "Connect trickle chargers to vehicle batteries.", sortOrder: 14),

                // Phase 4: Plumbing, Well, Spa & Heating
                ProcedureStep(text: "Drain & clean spa / hot tub", notes: "Fully drain, clean, and dry spa lines for winter.", sortOrder: 15),
                ProcedureStep(text: "Shut off water heater, well valves & curb stop", notes: "Turn off breaker to water heater, close cold water valve, shut off inside well valve, and close well curb stop.", sortOrder: 16),
                ProcedureStep(text: "Drain water heater & bypass water softener", notes: "Drain water heater tank completely (after breaker is off) and bypass/shutdown water softener.", sortOrder: 17),
                ProcedureStep(text: "Drain & blow out water lines", notes: "Blow out supply lines with compressed air. Open all faucets and spigots after blowout.", sortOrder: 18),
                ProcedureStep(text: "Add RV antifreeze to all drains & traps", notes: "Pour RV plumbing antifreeze into sink traps, shower drains, and toilet bowls.", sortOrder: 19),
                ProcedureStep(text: "Set thermostat & switch furnace over", notes: "Switch furnace from summer to winter mode and set setback temperature to 52°F.", sortOrder: 20),

                // Phase 5: Refrigerators, Freezers & Pantry
                ProcedureStep(text: "Clean out shop & garage refrigerators", notes: "Empty perishables from shop and garage fridges, turn power off, and prop doors open.", sortOrder: 21),
                ProcedureStep(text: "Clean out garage freezer", notes: "Transfer remaining frozen items into house kitchen fridge or pack out.", sortOrder: 22),
                ProcedureStep(text: "Turn off refrigerator ice maker", notes: "Shut off ice maker arm and drain water supply line.", sortOrder: 23),
                ProcedureStep(text: "Clear perishables from kitchen fridge & pantry cupboards", notes: "Remove all perishables from kitchen fridge and pantry cupboards. Unplug fridge and prop doors open with towels.", sortOrder: 24),

                // Phase 6: House Interior, Blinds & Pest Control
                ProcedureStep(text: "Adjust window & skylight blinds", notes: "Set all window blinds to partially closed; close skylight blinds halfway.", sortOrder: 25),
                ProcedureStep(text: "Unplug electronics & turn off candle timers", notes: "Pull plugs for TVs, microwave, and small appliances. Turn off electric candle timers.", sortOrder: 26),
                ProcedureStep(text: "Set out pest traps & bug bombs", notes: "Set mouse traps in hall closets. Place bug bombs on both floors of house and 3 bug bombs in the shop.", sortOrder: 27),
                ProcedureStep(text: "Place dryer sheets on indoor furniture & beds", notes: "Lay dryer sheets across beds and upholstered furniture to repel pests.", sortOrder: 28),
                ProcedureStep(text: "Strip bedding & air out comforters", notes: "Strip master bed, air out comforters and pillows, and pack up jewelry/valuables.", sortOrder: 29),
                ProcedureStep(text: "Bring in plants & move geraniums", notes: "Move geraniums to crawl space. Bring indoor/patio plants inside, water thoroughly, and fill backup bucket.", sortOrder: 30),

                // Phase 7: Final Departure & Lockup
                ProcedureStep(text: "Pack up leftover items for Paul", notes: "Gather remaining food and household items left over to give to Paul.", sortOrder: 31),
                ProcedureStep(text: "Give property key to Roger", notes: "Hand off emergency property key to Roger.", sortOrder: 32),
                ProcedureStep(text: "Take out final garbage to curb", notes: "Roll final garbage containers out to curb.", sortOrder: 33),
                ProcedureStep(text: "Lock sheds & secure property", notes: "Double-check all windows, doors, and outdoor outbuilding sheds are locked.", sortOrder: 34)
            ],
            scheduledWindow: SeasonalWindow(startMonth: 9, startDay: 1, endMonth: 11, endDay: 15)
        )
    }

    static func defaultSpringOpeningTemplate(propertyID: UUID? = nil) -> Procedure {
        Procedure(
            propertyID: propertyID,
            name: "Lake House Spring Opening",
            phase: .springOpening,
            steps: [
                ProcedureStep(text: "Inspect exterior structure, roof, and foundation for winter storm damage", notes: "Check for loose shingles or fallen branches.", sortOrder: 0),
                ProcedureStep(text: "Turn on main water valve & pressurize plumbing slowly", notes: "Listen for running water or pipe leaks.", sortOrder: 1),
                ProcedureStep(text: "Flush RV antifreeze from sink traps and toilets", notes: "Run clean water down all drains for 2 minutes.", sortOrder: 2),
                ProcedureStep(text: "Fill water heater and turn breaker back on", notes: "Ensure tank is full of water BEFORE turning power on!", sortOrder: 3),
                ProcedureStep(text: "Clean furnace air filter & test HVAC cooling mode", notes: "Replace filter if clogged with dust.", sortOrder: 4),
                ProcedureStep(text: "Reinstall boat dock and watercraft lift equipment", notes: "Grease pulley grease fittings.", sortOrder: 5),
                ProcedureStep(text: "Uncover outdoor patio furniture & outdoor grill", notes: "Check propane tank level.", sortOrder: 6)
            ],
            scheduledWindow: SeasonalWindow(startMonth: 4, startDay: 15, endMonth: 5, endDay: 30)
        )
    }

    static func defaultInspectionTemplate(propertyID: UUID? = nil) -> Procedure {
        Procedure(
            propertyID: propertyID,
            name: "Fall Home & Property Inspection",
            phase: .inspection,
            steps: [
                ProcedureStep(text: "Inspect roof shingles, flashing, and vent boots", notes: "Check attic for signs of daylight or water leaks.", sortOrder: 0),
                ProcedureStep(text: "Test sump pump and backup battery system", notes: "Pour a bucket of water into pit to verify float switch.", sortOrder: 1),
                ProcedureStep(text: "Inspect window caulking and weatherstripping", notes: "Seal drafts around window sashes and exterior doors.", sortOrder: 2),
                ProcedureStep(text: "Check foundation walls and grading drainage", notes: "Ensure soil slopes away from foundation walls.", sortOrder: 3)
            ],
            scheduledWindow: SeasonalWindow(startMonth: 9, startDay: 1, endMonth: 10, endDay: 30)
        )
    }
}
