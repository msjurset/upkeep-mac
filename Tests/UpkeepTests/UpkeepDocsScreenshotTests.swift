import XCTest
import SwiftUI
import AppKit
@testable import Upkeep

final class UpkeepDocsScreenshotTests: XCTestCase {

    struct DocCallout: Identifiable {
        let id = UUID()
        let number: Int
        let title: String
        let subtitle: String
        let targetRect: CGRect
        let badgeCenter: CGPoint
        let color: Color

        var estimatedBadgeRect: CGRect {
            let textWidth = CGFloat(max(title.count * 7 + 44, subtitle.count * 6 + 44, 195))
            let width = min(max(textWidth, 195), 290)
            let height: CGFloat = 50
            return CGRect(
                x: badgeCenter.x - width / 2,
                y: badgeCenter.y - height / 2,
                width: width,
                height: height
            )
        }
    }

    struct AnnotatedScreenshotCanvas<Content: View>: View {
        let content: Content
        let callouts: [DocCallout]
        let size: CGSize

        var body: some View {
            ZStack(alignment: .topLeading) {
                Color(red: 0.11, green: 0.12, blue: 0.14)
                    .frame(width: size.width, height: size.height)

                content
                    .frame(width: size.width, height: size.height)

                Canvas { context, _ in
                    for callout in callouts {
                        let rect = callout.targetRect
                        let badge = callout.badgeCenter
                        let targetPoint = closestPoint(on: rect, to: badge)

                        var shadowLine = Path()
                        shadowLine.move(to: badge)
                        shadowLine.addLine(to: targetPoint)
                        context.stroke(
                            shadowLine,
                            with: .color(Color.black.opacity(0.65)),
                            style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                        )

                        var line = Path()
                        line.move(to: badge)
                        line.addLine(to: targetPoint)
                        context.stroke(
                            line,
                            with: .color(callout.color),
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [6, 4])
                        )

                        let dotRect = CGRect(x: targetPoint.x - 4.5, y: targetPoint.y - 4.5, width: 9, height: 9)
                        context.fill(Path(ellipseIn: dotRect), with: .color(callout.color))
                        context.stroke(Path(ellipseIn: dotRect), with: .color(.white), lineWidth: 1.5)
                    }
                }
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)

                ForEach(callouts) { callout in
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.black.opacity(0.65), lineWidth: 4.0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(callout.color, lineWidth: 2.2)
                        )
                        .frame(width: callout.targetRect.width, height: callout.targetRect.height)
                        .position(x: callout.targetRect.midX, y: callout.targetRect.midY)
                }

                ForEach(callouts) { callout in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(callout.color)
                                .frame(width: 26, height: 26)
                            Text("\(callout.number)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(callout.title)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            Text(callout.subtitle)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.82))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.10, green: 0.11, blue: 0.15).opacity(0.96))
                            .shadow(color: Color.black.opacity(0.45), radius: 8, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(callout.color.opacity(0.9), lineWidth: 1.5)
                    )
                    .position(callout.badgeCenter)
                }
            }
            .frame(width: size.width, height: size.height)
            .preferredColorScheme(.dark)
        }

        private func closestPoint(on rect: CGRect, to point: CGPoint) -> CGPoint {
            let cx = min(max(point.x, rect.minX), rect.maxX)
            let cy = min(max(point.y, rect.minY), rect.maxY)
            return CGPoint(x: cx, y: cy)
        }
    }

    @MainActor
    private func renderAnnotatedScreenshot<V: View>(
        _ view: V,
        callouts: [DocCallout],
        size: CGSize,
        to path: String
    ) throws {
        assertNoCalloutOverlaps(callouts: callouts, size: size, path: path)

        _ = NSApplication.shared
        NSApp?.appearance = NSAppearance(named: .darkAqua)

        let canvas = AnnotatedScreenshotCanvas(content: view, callouts: callouts, size: size)
            .environment(\.colorScheme, .dark)

        let hostingView = NSHostingView(rootView: canvas)
        hostingView.appearance = NSAppearance(named: .darkAqua)
        hostingView.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1.0)
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)

        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.35))
        applyDarkScrollBackgrounds(in: hostingView)
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            XCTFail("Failed to create bitmapImageRep")
            return
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to encode PNG")
            return
        }

        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try pngData.write(to: url)
        window.orderOut(nil)
    }

    @MainActor
    private func applyDarkScrollBackgrounds(in view: NSView) {
        view.appearance = NSAppearance(named: .darkAqua)
        if let scrollView = view as? NSScrollView {
            scrollView.drawsBackground = false
        }
        for subview in view.subviews {
            applyDarkScrollBackgrounds(in: subview)
        }
    }

    private func assertNoCalloutOverlaps(callouts: [DocCallout], size: CGSize, path: String) {
        let canvasBounds = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
        for i in 0..<callouts.count {
            let a = callouts[i]
            let badgeA = a.estimatedBadgeRect
            XCTAssertTrue(
                canvasBounds.contains(badgeA),
                "Callout #\(a.number) (\(a.title)) in \(URL(fileURLWithPath: path).lastPathComponent) clips outside canvas bounds: \(badgeA)"
            )
            for j in (i + 1)..<callouts.count {
                let b = callouts[j]
                let badgeB = b.estimatedBadgeRect
                XCTAssertFalse(
                    badgeA.insetBy(dx: -4, dy: -4).intersects(badgeB),
                    "Callout badges #\(a.number) and #\(b.number) overlap in \(URL(fileURLWithPath: path).lastPathComponent)"
                )
                XCTAssertFalse(
                    a.targetRect.intersects(b.targetRect),
                    "Target highlight rects #\(a.number) and #\(b.number) overlap in \(URL(fileURLWithPath: path).lastPathComponent)"
                )
            }
            for other in callouts {
                XCTAssertFalse(
                    badgeA.intersects(other.targetRect),
                    "Callout badge #\(a.number) overlaps target highlight rect #\(other.number) in \(URL(fileURLWithPath: path).lastPathComponent)"
                )
            }
        }
    }

    // MARK: - Synthetic Data Seeding (Zero PII)

    @MainActor
    private func makeSyntheticStore() -> (
        store: UpkeepStore,
        weather: WeatherStore,
        lawnItem: MaintenanceItem,
        sourcing: Sourcing
    ) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("upkeep-docs-\(UUID().uuidString)")
        let persistence = Persistence(baseURL: tempDir)
        let store = UpkeepStore(persistence: persistence)
        let weather = WeatherStore()

        let cal = Calendar.current
        let now = Date.now
        let currentYear = cal.component(.year, from: now)
        let currentMonth = cal.component(.month, from: now)

        // 1. Properties (Synthetic Addresses & Coordinates)
        let primaryHomeID = UUID()
        let lakeCabinID = UUID()

        let systems: [HomeProfile.HomeSystem] = [
            HomeProfile.HomeSystem(
                name: "Architectural Shingle Roof",
                brand: "CertainTeed",
                model: "Landmark PRO",
                installedDate: cal.date(byAdding: .year, value: -7, to: now),
                expectedLifespanYears: 30,
                notes: "50-year limited warranty; ridge vents inspected annually."
            ),
            HomeProfile.HomeSystem(
                name: "Dual-Fuel Heat Pump (Main Floor)",
                brand: "Trane",
                model: "XV18 Variable Speed",
                installedDate: cal.date(byAdding: .year, value: -4, to: now),
                expectedLifespanYears: 15,
                notes: "Uses MERV 13 20x25x4 pleated media filter."
            ),
            HomeProfile.HomeSystem(
                name: "Hybrid Heat Pump Water Heater",
                brand: "Rheem",
                model: "ProTerra 65-Gal",
                installedDate: cal.date(byAdding: .year, value: -2, to: now),
                expectedLifespanYears: 12,
                notes: "Flush sediment every 12 months; check anode rod at year 4."
            ),
            HomeProfile.HomeSystem(
                name: "Exterior Cedar Deck & Pergola",
                brand: "Custom Western Red Cedar",
                model: "Penofin Red Label Finish",
                installedDate: cal.date(byAdding: .year, value: -9, to: now),
                expectedLifespanYears: 20,
                notes: "Re-seal horizontal boards every 2 years."
            )
        ]

        let primaryHome = Property(
            id: primaryHomeID,
            name: "Oakridge Residence",
            address: "742 Evergreen Terrace, Asheville, NC",
            yearBuilt: 2014,
            squareFootage: 3150,
            notes: "Main family residence. Municipal water/sewer, dual-zone HVAC, irrigated fescue lawn.",
            icon: "house.fill",
            isPrimary: true,
            latitude: 35.5951,
            longitude: -82.5515,
            geocodedAddress: "742 Evergreen Terrace, Asheville, NC",
            systems: systems
        )

        let lakeCabin = Property(
            id: lakeCabinID,
            name: "Blue Ridge Lake Cabin",
            address: "118 Pine Cove Rd, Lake Toxaway, NC",
            yearBuilt: 2006,
            squareFootage: 1850,
            notes: "Seasonal mountain cabin. Well water with UV filter, septic system, and floating dock.",
            icon: "water.waves",
            isPrimary: false,
            latitude: 35.1256,
            longitude: -82.9332,
            geocodedAddress: "118 Pine Cove Rd, Lake Toxaway, NC",
            systems: []
        )

        store.properties = [primaryHome, lakeCabin]
        store.selectedPropertyID = primaryHomeID

        // 2. Household Members (Synthetic)
        let alex = HouseholdMember(name: "Alex Mercer")
        let jordan = HouseholdMember(name: "Jordan Mercer")
        store.members = [alex, jordan]

        // 3. Vendors (Synthetic)
        let hvacVendor = Vendor(
            name: "Blue Ridge Climate Control",
            phone: "(828) 555-0142",
            email: "service@blueridgeclimate.example.com",
            website: "https://blueridgeclimate.example.com",
            location: "Asheville, NC",
            specialty: "HVAC & Heat Pumps",
            propertyIDs: [primaryHomeID],
            tags: ["HVAC", "licensed", "24h"],
            accountManager: AccountManager(name: "Marcus Vance", phone: "(828) 555-0149", email: "mvance@blueridgeclimate.example.com"),
            notes: "Annual maintenance contract covers spring AC and fall furnace tune-ups."
        )

        let turfVendor = Vendor(
            name: "Carolina Turf & Ornamental",
            phone: "(828) 555-0188",
            email: "schedule@carolinaturf.example.com",
            website: "https://carolinaturf.example.com",
            location: "Hendersonville, NC",
            specialty: "Lawn & Soil Care",
            propertyIDs: [primaryHomeID],
            tags: ["lawn", "aeration", "soil"],
            notes: "Handles core aeration and bulk lime applications."
        )

        let plumbingVendor = Vendor(
            name: "Summit Flow Plumbing",
            phone: "(828) 555-0164",
            email: "dispatch@summitflow.example.com",
            website: "https://summitflow.example.com",
            location: "Asheville, NC",
            specialty: "Plumbing & Water Heaters",
            propertyIDs: [primaryHomeID, lakeCabinID],
            tags: ["plumbing", "well", "winterization"]
        )

        store.vendors = [hvacVendor, turfVendor, plumbingVendor]

        // 4. Maintenance Items (Overdue, Upcoming, Multi-Event Lawn Program, Reorder Supply)
        let hvacFilterItem = MaintenanceItem(
            propertyID: primaryHomeID,
            name: "Replace HVAC Media Filter (20x25x4)",
            category: .hvac,
            priority: .high,
            scheduleKind: .recurring,
            frequencyInterval: 3,
            frequencyUnit: .months,
            startDate: cal.date(byAdding: .day, value: -102, to: now)!,
            notes: "Turn off blower disconnect before sliding out media cartridge. Check condensate trap.",
            vendorID: hvacVendor.id,
            ownerID: alex.id,
            supply: Supply(
                stockOnHand: 1,
                quantityPerUse: 1,
                productName: "Honeywell FC100A1037 MERV 13 (20x25x4)",
                productURL: "https://supply.example.com/merv13-20x25x4",
                unitCost: Decimal(string: "38.50")
            ),
            tags: ["filter", "air-quality", "indoor"],
            followUps: [
                FollowUp(
                    title: "Vacuum return air grilles in hallway",
                    dueDate: cal.date(byAdding: .day, value: 2, to: now),
                    isDone: false
                )
            ]
        )

        let sub1 = SubEvent(
            name: "Stage 1: Pre-Emergent Crabgrass Barrier (Prodiamine)",
            seasonalWindow: SeasonalWindow(startMonth: 3, startDay: 1, endMonth: 4, endDay: 10),
            notes: "Apply when 5-day soil temp reaches 53°F; water in with 0.5\" irrigation within 48h."
        )
        let sub2 = SubEvent(
            name: "Stage 2: Spring Slow-Release Nitrogen & Iron Feed",
            seasonalWindow: SeasonalWindow(startMonth: 5, startDay: 1, endMonth: 6, endDay: 5),
            notes: "Apply 0.75 lb N / 1,000 sq ft before morning dew dries."
        )
        let sub3 = SubEvent(
            name: "Stage 3: Fall Core Aeration & Tall Fescue Overseeding",
            seasonalWindow: SeasonalWindow(startMonth: currentMonth, startDay: 1, endMonth: min(12, currentMonth + 1), endDay: 28),
            notes: "Double-pass core aerate, apply 6 lbs/1k TTTF blend + starter fertilizer.",
            vendorID: turfVendor.id
        )
        let sub4 = SubEvent(
            name: "Stage 4: Late-Fall Winterizer Root Builder",
            seasonalWindow: SeasonalWindow(startMonth: 11, startDay: 5, endMonth: 12, endDay: 10),
            notes: "Fast-release urea feed after top growth stops but roots remain active."
        )

        let lawnProgramItem = MaintenanceItem(
            propertyID: primaryHomeID,
            name: "Annual Cool-Season Lawn Care Program",
            category: .lawnAndGarden,
            priority: .high,
            scheduleKind: .seasonal,
            frequencyInterval: 1,
            frequencyUnit: .years,
            startDate: cal.date(byAdding: .day, value: 4, to: now)!,
            notes: "4-stage tall fescue agronomic schedule covering 12,000 sq ft turf area. Check 14-day spray window before applying liquid treatments.",
            supply: Supply(
                stockOnHand: 2,
                quantityPerUse: 2,
                productName: "Lesco 24-0-11 50% PolyPlus Slow-Release (50 lb)",
                productURL: "https://supply.example.com/lesco-24-0-11",
                unitCost: Decimal(string: "64.00")
            ),
            tags: ["lawn", "spray", "fertilizer", "outdoor"],
            seasonalWindow: SeasonalWindow(startMonth: 3, startDay: 1, endMonth: 11, endDay: 30),
            followUps: [],
            subEvents: [sub1, sub2, sub3, sub4]
        )

        let gutterItem = MaintenanceItem(
            propertyID: primaryHomeID,
            name: "Clean Gutters & Flush Downspout Drains",
            category: .exterior,
            priority: .high,
            scheduleKind: .recurring,
            frequencyInterval: 6,
            frequencyUnit: .months,
            startDate: cal.date(byAdding: .month, value: -7, to: now)!,
            notes: "Clear oak leaves from upper roof valleys and test underground corrugated drain lines.",
            ownerID: jordan.id,
            tags: ["roof", "drainage", "outdoor"],
            followUps: [
                FollowUp(
                    title: "Flag sprinkler heads along driveway before core aeration",
                    dueDate: cal.date(byAdding: .day, value: 3, to: now),
                    isDone: false
                )
            ]
        )

        let waterHeaterItem = MaintenanceItem(
            propertyID: primaryHomeID,
            name: "Flush Hybrid Water Heater & Clean Air Filter",
            category: .plumbing,
            priority: .medium,
            scheduleKind: .recurring,
            frequencyInterval: 6,
            frequencyUnit: .months,
            startDate: cal.date(byAdding: .month, value: -5, to: now)!,
            notes: "Connect garden hose to brass drain valve; rinse washable top intake screen.",
            vendorID: plumbingVendor.id,
            ownerID: alex.id,
            tags: ["plumbing", "efficiency"]
        )

        let smokeDetectorItem = MaintenanceItem(
            propertyID: primaryHomeID,
            name: "Test Smoke & CO Alarms + Replace 9V Backup Cells",
            category: .safety,
            priority: .critical,
            scheduleKind: .recurring,
            frequencyInterval: 6,
            frequencyUnit: .months,
            startDate: cal.date(byAdding: .month, value: -5, to: now)!.addingTimeInterval(86400 * 12),
            notes: "8 interconnected First Alert units across basement, main floor, and upstairs bedrooms.",
            supply: Supply(
                stockOnHand: 4,
                quantityPerUse: 8,
                productName: "Energizer Ultimate Lithium 9V (8-Pack)",
                productURL: "https://supply.example.com/lithium-9v",
                unitCost: Decimal(string: "29.99")
            ),
            tags: ["safety", "battery"]
        )

        store.items = [hvacFilterItem, lawnProgramItem, gutterItem, waterHeaterItem, smokeDetectorItem]

        // 5. Log Entries
        let log1 = LogEntry(
            propertyID: primaryHomeID,
            itemID: lawnProgramItem.id,
            subEventID: sub1.id,
            title: "Annual Cool-Season Lawn Care Program — Stage 1: Pre-Emergent",
            category: .lawnAndGarden,
            completedDate: cal.date(from: DateComponents(year: currentYear, month: 3, day: 18)) ?? cal.date(byAdding: .day, value: -60, to: now)!,
            notes: "Applied 0.38% Prodiamine granular barrier across front and rear turf prior to rain.",
            cost: Decimal(string: "58.00"),
            performedBy: "Alex Mercer",
            rating: 5,
            countsAsCompletion: true
        )
        let log2 = LogEntry(
            propertyID: primaryHomeID,
            itemID: lawnProgramItem.id,
            subEventID: sub2.id,
            title: "Annual Cool-Season Lawn Care Program — Stage 2: Spring Nitrogen Feed",
            category: .lawnAndGarden,
            completedDate: cal.date(from: DateComponents(year: currentYear, month: 5, day: 12)) ?? cal.date(byAdding: .day, value: -25, to: now)!,
            notes: "Applied 2 bags Lesco 24-0-11 with chelated iron; deep green-up within 6 days.",
            cost: Decimal(string: "128.00"),
            performedBy: "Alex Mercer",
            rating: 5,
            countsAsCompletion: true
        )
        let log3 = LogEntry(
            propertyID: primaryHomeID,
            itemID: waterHeaterItem.id,
            title: "Annual Heat Pump HVAC Inspection & Coil Cleaning",
            category: .hvac,
            completedDate: cal.date(byAdding: .day, value: -14, to: now)!,
            notes: "Static pressure 0.42 in. w.c., subcooling within 1°F of spec.",
            cost: Decimal(string: "185.00"),
            performedBy: "Blue Ridge Climate Control",
            rating: 5,
            countsAsCompletion: true
        )
        store.logEntries = [log1, log2, log3]

        // 6. Sourcing with Candidate Quotes
        let cand1 = Candidate(
            name: "Highland Exterior & Gutter Co.",
            phone: "(828) 555-0191",
            email: "estimates@highlandexterior.example.com",
            source: "Neighbor Referral",
            status: .quoted,
            quoteAmount: Decimal(string: "1450.00"),
            notes: "Includes micro-mesh stainless guards on 160 linear feet + 3x4 oversized downspouts."
        )
        let cand2 = Candidate(
            name: "Appalachian Seamless Gutters",
            phone: "(828) 555-0123",
            email: "bids@appseamless.example.com",
            source: "Local Directory",
            status: .quoted,
            quoteAmount: Decimal(string: "1680.00"),
            notes: "Includes helmet-style aluminum hoods; 3-week lead time."
        )
        let cand3 = Candidate(
            name: "Peak Ridge Roofing & Drainage",
            phone: "(828) 555-0177",
            email: "info@peakridgeroof.example.com",
            source: "Web Search",
            status: .contacted,
            quoteAmount: nil,
            notes: "On-site measurement scheduled for Thursday at 10:00 AM."
        )

        let roofSourcing = Sourcing(
            propertyID: primaryHomeID,
            title: "Gutter Guard Installation & Downspout Upgrade",
            linkedItemIDs: [gutterItem.id],
            replacingVendorID: turfVendor.id,
            status: .open,
            decideBy: cal.date(byAdding: .day, value: 6, to: now),
            notes: "Comparing heavy-gauge stainless micro-mesh guards vs. solid aluminum hoods for upper oak canopy roof line.",
            candidates: [cand1, cand2, cand3]
        )
        store.sourcings = [roofSourcing]

        // 7. Seasonal Procedures
        let winterProc = Procedure(
            propertyIDs: [primaryHomeID, lakeCabinID],
            name: "Late-Autumn Freeze & Pipe Winterization",
            phase: .winterization,
            steps: [
                ProcedureStep(
                    text: "Shut off interior supply valves to exterior hose bibs & open bleed caps",
                    notes: "Basement mechanical room manifold valves #3 and #4",
                    isComplete: true,
                    completedAt: cal.date(byAdding: .day, value: -2, to: now),
                    sortOrder: 0
                ),
                ProcedureStep(
                    text: "Blow out 6-zone irrigation manifold with 50 PSI compressed air",
                    notes: "Do not exceed 55 PSI on gear-driven rotor zones",
                    isComplete: true,
                    completedAt: cal.date(byAdding: .day, value: -1, to: now),
                    sortOrder: 1
                ),
                ProcedureStep(
                    text: "Insulate crawlspace backflow preventer & test heat trace cable",
                    notes: "Verify GFCI indicator light on circuit #14",
                    isComplete: false,
                    linkedItemID: waterHeaterItem.id,
                    sortOrder: 2
                ),
                ProcedureStep(
                    text: "Reverse ceiling fans to clockwise low-speed winter updraft mode",
                    isComplete: false,
                    sortOrder: 3
                )
            ],
            scheduledWindow: SeasonalWindow(startMonth: 10, startDay: 15, endMonth: 11, endDay: 30),
            notes: "Complete before first hard mountain frost (< 28°F).",
            isCollapsed: false,
            sortOrder: 0
        )

        let springProc = Procedure(
            propertyIDs: [primaryHomeID],
            name: "Spring Exterior & Cooling Commissioning",
            phase: .springOpening,
            steps: [
                ProcedureStep(
                    text: "Clear debris from outdoor heat pump condenser fins & level pad",
                    isComplete: true,
                    completedAt: cal.date(byAdding: .day, value: -30, to: now),
                    sortOrder: 0
                ),
                ProcedureStep(
                    text: "Pressurize irrigation main line slowly and inspect zone heads",
                    isComplete: true,
                    completedAt: cal.date(byAdding: .day, value: -28, to: now),
                    sortOrder: 1
                ),
                ProcedureStep(
                    text: "Wash exterior window screens and lubricate casement cranks",
                    isComplete: false,
                    sortOrder: 2
                )
            ],
            scheduledWindow: SeasonalWindow(startMonth: 4, startDay: 1, endMonth: 5, endDay: 15),
            isCollapsed: false,
            sortOrder: 1
        )

        store.procedures = [winterProc, springProc]

        // Persist synthetic records to temp directory so any view .onAppear / loadAll() preserves them
        Task {
            for p in store.properties { try? await persistence.saveProperty(p) }
            for item in store.items { try? await persistence.saveItem(item) }
            for log in store.logEntries { try? await persistence.saveLogEntry(log) }
            for v in store.vendors { try? await persistence.saveVendor(v) }
            for s in store.sourcings { try? await persistence.saveSourcing(s) }
            for proc in store.procedures { try? await persistence.saveProcedure(proc) }
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))

        // 8. Synthetic 14-Day Weather Forecast (Calm Spray Window + Upcoming Rain)
        var dailyForecasts: [DailyForecast] = []
        let codes = [0, 1, 0, 2, 61, 3, 0, 1, 0, 0, 2, 61, 1, 0]
        let highs: [Double] = [71, 73, 75, 69, 63, 66, 70, 72, 74, 73, 68, 64, 69, 72]
        let lows: [Double]  = [49, 51, 52, 50, 47, 45, 48, 50, 51, 52, 49, 46, 47, 50]
        let precipProbs = [5, 10, 5, 20, 80, 15, 5, 10, 5, 10, 25, 75, 10, 5]
        let winds: [Double] = [5, 6, 4, 8, 14, 9, 5, 6, 4, 5, 9, 15, 7, 5]

        for i in 0..<14 {
            let dayDate = cal.date(byAdding: .day, value: i, to: cal.startOfDay(for: now))!
            dailyForecasts.append(
                DailyForecast(
                    date: dayDate,
                    highF: highs[i],
                    lowF: lows[i],
                    feelsLikeHighF: highs[i],
                    feelsLikeLowF: lows[i],
                    weatherCode: codes[i],
                    precipitationInches: precipProbs[i] >= 50 ? 0.42 : 0.0,
                    precipitationProbability: precipProbs[i],
                    windSpeedMph: winds[i],
                    windGustMph: winds[i] + 4,
                    humidity: 54,
                    uvIndex: 6.0,
                    pressureHpa: 1018,
                    dewPointF: 48
                )
            )
        }
        weather.setForecastForTesting(Forecast(daily: dailyForecasts, hourly: [], fetchedAt: now))

        return (store, weather, lawnProgramItem, roofSourcing)
    }

    // MARK: - Screenshot Generation Test

    @MainActor
    func testGenerateDocumentationScreenshots() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let assetsDir = packageRoot.appendingPathComponent("docs/assets").path

        let (store, weather, lawnItem, sourcing) = makeSyntheticStore()

        // 1. Dashboard Overview (`upkeep_dashboard.png`)
        store.navigation = .dashboard
        let dashboardSize = CGSize(width: 1380, height: 880)
        let dashboardView = HStack(spacing: 0) {
            SidebarView(selection: .constant(.dashboard))
                .frame(width: 220)
            Divider()
            DashboardView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(store)
        .environment(weather)

        let dashboardCallouts: [DocCallout] = [
            DocCallout(
                number: 1,
                title: "Health Score & Readiness Ring",
                subtitle: "Priority-weighted score & overdue summary",
                targetRect: CGRect(x: 242, y: 20, width: 640, height: 145),
                badgeCenter: CGPoint(x: 1120, y: 92),
                color: Color(red: 0.96, green: 0.65, blue: 0.14)
            ),
            DocCallout(
                number: 2,
                title: "Interactive Activity Timeline",
                subtitle: "Recent completions & upcoming scheduled items",
                targetRect: CGRect(x: 242, y: 182, width: 1110, height: 132),
                badgeCenter: CGPoint(x: 510, y: 348),
                color: Color(red: 0.22, green: 0.62, blue: 0.98)
            ),
            DocCallout(
                number: 3,
                title: "Reorder Alerts & Open Sourcing",
                subtitle: "Low-stock consumables, follow-ups & RFPs",
                targetRect: CGRect(x: 242, y: 382, width: 535, height: 465),
                badgeCenter: CGPoint(x: 960, y: 815),
                color: Color(red: 0.20, green: 0.78, blue: 0.52)
            ),
            DocCallout(
                number: 4,
                title: "14-Day Weather & Spray Window",
                subtitle: "Dry, low-wind outdoor treatment advisories",
                targetRect: CGRect(x: 798, y: 382, width: 558, height: 195),
                badgeCenter: CGPoint(x: 1075, y: 348),
                color: Color(red: 0.68, green: 0.45, blue: 0.98)
            )
        ]

        try renderAnnotatedScreenshot(
            dashboardView,
            callouts: dashboardCallouts,
            size: dashboardSize,
            to: "\(assetsDir)/upkeep_dashboard.png"
        )

        // 2. Inventory & Multi-Event Schedule (`inventory_and_subevents.png`)
        store.navigation = .inventoryAll
        store.selectedItemID = lawnItem.id
        let inventorySize = CGSize(width: 1380, height: 960)
        let inventoryView = HStack(spacing: 0) {
            SidebarView(selection: .constant(.inventoryAll))
                .frame(width: 210)
            Divider()
            ItemListView(items: store.filteredAllItems, title: "All Items", showNewItemSheet: .constant(false))
                .frame(width: 350)
            Divider()
            ItemDetailView(item: lawnItem)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(store)
        .environment(weather)

        let inventoryCallouts: [DocCallout] = [
            DocCallout(
                number: 1,
                title: "Sortable Maintenance Inventory",
                subtitle: "Filter by due date, priority, tag, or property",
                targetRect: CGRect(x: 218, y: 52, width: 334, height: 390),
                badgeCenter: CGPoint(x: 385, y: 490),
                color: Color(red: 0.22, green: 0.62, blue: 0.98)
            ),
            DocCallout(
                number: 2,
                title: "Schedule & Seasonal Window",
                subtitle: "Annual window, status & last completion date",
                targetRect: CGRect(x: 576, y: 132, width: 780, height: 120),
                badgeCenter: CGPoint(x: 1190, y: 82),
                color: Color(red: 0.20, green: 0.78, blue: 0.52)
            ),
            DocCallout(
                number: 3,
                title: "Consumable Supply Stock Tracker",
                subtitle: "Track bags on hand, unit cost & reorder link",
                targetRect: CGRect(x: 576, y: 270, width: 780, height: 260),
                badgeCenter: CGPoint(x: 385, y: 615),
                color: Color(red: 0.96, green: 0.65, blue: 0.14)
            ),
            DocCallout(
                number: 4,
                title: "Multi-Event Schedule (Sub-Events)",
                subtitle: "4 timed agronomic stages with per-stage vendors",
                targetRect: CGRect(x: 576, y: 690, width: 780, height: 255),
                badgeCenter: CGPoint(x: 385, y: 785),
                color: Color(red: 0.68, green: 0.45, blue: 0.98)
            )
        ]

        try renderAnnotatedScreenshot(
            inventoryView,
            callouts: inventoryCallouts,
            size: inventorySize,
            to: "\(assetsDir)/inventory_and_subevents.png"
        )

        // 3. Vendor Sourcing & Quote Comparison (`vendor_sourcing.png`)
        store.navigation = .vendors
        store.vendorsTab = .sourcings
        store.selectedSourcingID = sourcing.id
        let sourcingSize = CGSize(width: 1380, height: 860)
        let sourcingView = HStack(spacing: 0) {
            SidebarView(selection: .constant(.vendors))
                .frame(width: 210)
            Divider()
            VendorsContainerView(
                showNewVendorSheet: .constant(false),
                showNewSourcingSheet: .constant(false)
            )
            .frame(width: 350)
            Divider()
            SourcingDetailView(sourcing: sourcing)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(store)
        .environment(weather)

        let sourcingCallouts: [DocCallout] = [
            DocCallout(
                number: 1,
                title: "Vendors & Sourcing Switcher",
                subtitle: "Toggle between contractor rolodex & open RFPs",
                targetRect: CGRect(x: 218, y: 12, width: 334, height: 220),
                badgeCenter: CGPoint(x: 385, y: 278),
                color: Color(red: 0.22, green: 0.62, blue: 0.98)
            ),
            DocCallout(
                number: 2,
                title: "Scope, Linked Items & Deadline",
                subtitle: "Links to maintenance tasks & Decide-By target",
                targetRect: CGRect(x: 576, y: 16, width: 780, height: 210),
                badgeCenter: CGPoint(x: 385, y: 410),
                color: Color(red: 0.96, green: 0.65, blue: 0.14)
            ),
            DocCallout(
                number: 3,
                title: "Candidate Bid Comparison",
                subtitle: "Track status, quote amounts & scope notes",
                targetRect: CGRect(x: 576, y: 315, width: 585, height: 225),
                badgeCenter: CGPoint(x: 868, y: 610),
                color: Color(red: 0.20, green: 0.78, blue: 0.52)
            ),
            DocCallout(
                number: 4,
                title: "One-Click Hire & Vendor Promotion",
                subtitle: "Promotes winner & archives runner-up quotes",
                targetRect: CGRect(x: 1175, y: 315, width: 180, height: 225),
                badgeCenter: CGPoint(x: 385, y: 545),
                color: Color(red: 0.68, green: 0.45, blue: 0.98)
            )
        ]

        try renderAnnotatedScreenshot(
            sourcingView,
            callouts: sourcingCallouts,
            size: sourcingSize,
            to: "\(assetsDir)/vendor_sourcing.png"
        )

        // 4. Seasonal Procedures & Major Home Systems (`procedures_and_systems.png`)
        store.navigation = .procedures
        let proceduresSize = CGSize(width: 1380, height: 860)
        let proceduresView = HStack(spacing: 0) {
            SidebarView(selection: .constant(.procedures))
                .frame(width: 210)
            Divider()
            ProceduresContainerView()
                .frame(width: 670)
            Divider()
            PropertyProfileView()
                .frame(width: 498)
        }
        .environment(store)
        .environment(weather)

        let proceduresCallouts: [DocCallout] = [
            DocCallout(
                number: 1,
                title: "Property Scope & Season Filter",
                subtitle: "Filter checklists by property & seasonal phase",
                targetRect: CGRect(x: 218, y: 6, width: 654, height: 42),
                badgeCenter: CGPoint(x: 545, y: 78),
                color: Color(red: 0.22, green: 0.62, blue: 0.98)
            ),
            DocCallout(
                number: 2,
                title: "Seasonal Procedure Checklists",
                subtitle: "Reusable Winterization & Spring Opening steps",
                targetRect: CGRect(x: 224, y: 112, width: 642, height: 475),
                badgeCenter: CGPoint(x: 545, y: 655),
                color: Color(red: 0.20, green: 0.78, blue: 0.52)
            ),
            DocCallout(
                number: 3,
                title: "Property Profile & Geocoding",
                subtitle: "Coordinates power local 14-day weather hints",
                targetRect: CGRect(x: 892, y: 16, width: 472, height: 325),
                badgeCenter: CGPoint(x: 1128, y: 380),
                color: Color(red: 0.96, green: 0.65, blue: 0.14)
            ),
            DocCallout(
                number: 4,
                title: "Major Home Systems Lifespan",
                subtitle: "Track age & remaining years for Roof, HVAC & Water",
                targetRect: CGRect(x: 892, y: 550, width: 472, height: 245),
                badgeCenter: CGPoint(x: 1128, y: 828),
                color: Color(red: 0.68, green: 0.45, blue: 0.98)
            )
        ]

        try renderAnnotatedScreenshot(
            proceduresView,
            callouts: proceduresCallouts,
            size: proceduresSize,
            to: "\(assetsDir)/procedures_and_systems.png"
        )
    }
}
