import Testing
import Foundation
@testable import Upkeep

// MARK: - Helpers

@MainActor
private func makeStore() -> UpkeepStore {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let persistence = Persistence(baseURL: tempDir)
    return UpkeepStore(persistence: persistence)
}

private func makeTempPersistence() -> (Persistence, URL) {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    return (Persistence(baseURL: dir), dir)
}

private func cleanup(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

// MARK: - Vendor backward compatibility

@Suite("Vendor schema migration")
struct VendorSchemaMigrationTests {
    @Test("old vendor JSON without isActive/source decodes with defaults")
    func decodesOldSchema() throws {
        let json = """
        {
          "id": "0F7162F1-D97D-45FD-8014-22E3F848C4CA",
          "name": "Bob's Plumbing",
          "phone": "555-0123",
          "email": "",
          "website": "",
          "location": "",
          "specialty": "Plumbing",
          "tags": [],
          "accountManager": {"name": "", "phone": "", "email": ""},
          "notes": "",
          "version": 1,
          "createdAt": "2025-04-02T01:30:41Z",
          "updatedAt": "2025-04-02T01:30:41Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let vendor = try decoder.decode(Vendor.self, from: json)

        #expect(vendor.name == "Bob's Plumbing")
        #expect(vendor.isActive == true)
        #expect(vendor.source == "")
    }

    @Test("Vendor full round-trip preserves new fields")
    func roundTripWithNewFields() throws {
        let original = Vendor(
            name: "Lawn Co", phone: "555-0001",
            notes: "Quoted Apr 12",
            source: "Tom from across the street",
            isActive: false
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Vendor.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.source == "Tom from across the street")
        #expect(decoded.isActive == false)
    }
}

// MARK: - Sourcing model

@Suite("Sourcing model")
struct SourcingModelTests {
    @Test("minimal init defaults")
    func minimalInit() {
        let s = Sourcing(title: "Lawn replacement")
        #expect(s.status == .open)
        #expect(s.candidates.isEmpty)
        #expect(s.linkedItemIDs.isEmpty)
        #expect(s.replacingVendorID == nil)
        #expect(s.isOpen == true)
    }

    @Test("JSON round-trip with full payload")
    func roundTripFull() throws {
        let candidate = Candidate(
            name: "Acme Lawn", phone: "555-1111", email: "info@acme.test",
            source: "Nextdoor", status: .quoted, quoteAmount: 1200,
            notes: "Annual contract, includes leaf cleanup"
        )
        let sourcing = Sourcing(
            title: "Lawn replacement",
            linkedItemIDs: [UUID(), UUID()],
            replacingVendorID: UUID(),
            decideBy: Date(timeIntervalSince1970: 1_750_000_000),
            notes: "Need someone reliable",
            candidates: [candidate]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(sourcing)
        let decoded = try decoder.decode(Sourcing.self, from: data)

        #expect(decoded.id == sourcing.id)
        #expect(decoded.title == "Lawn replacement")
        #expect(decoded.linkedItemIDs == sourcing.linkedItemIDs)
        #expect(decoded.replacingVendorID == sourcing.replacingVendorID)
        #expect(decoded.candidates.count == 1)
        #expect(decoded.candidates[0].name == "Acme Lawn")
        #expect(decoded.candidates[0].quoteAmount == 1200)
        #expect(decoded.candidates[0].source == "Nextdoor")
        #expect(decoded.candidates[0].status == .quoted)
    }

    @Test("touch increments version and stamps modifier")
    func touchSemantics() {
        var s = Sourcing(title: "Test")
        let memberID = UUID()
        let originalUpdatedAt = s.updatedAt
        Thread.sleep(forTimeInterval: 0.001)
        s.touch(by: memberID)
        #expect(s.version == 2)
        #expect(s.lastModifiedBy == memberID)
        #expect(s.updatedAt > originalUpdatedAt)
    }

    @Test("legacy linkedItemID JSON decodes into linkedItemIDs")
    func decodesLegacyLinkedItemID() throws {
        let id = UUID()
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "title": "Pre-multi sourcing",
          "linkedItemID": "\(id.uuidString)",
          "status": "open",
          "notes": "",
          "candidates": [],
          "cancelReason": "",
          "version": 1,
          "createdAt": "2026-05-01T12:00:00Z",
          "updatedAt": "2026-05-01T12:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let s = try decoder.decode(Sourcing.self, from: json)
        #expect(s.linkedItemIDs == [id])
    }

    @Test("encoder dual-writes linkedItemID for backward compat")
    func encoderDualWritesLegacyKey() throws {
        let id1 = UUID()
        let id2 = UUID()
        let s = Sourcing(title: "Multi", linkedItemIDs: [id1, id2])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(s)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect((json?["linkedItemID"] as? String) == id1.uuidString)
        let arr = json?["linkedItemIDs"] as? [String]
        #expect(arr?.contains(id1.uuidString) == true)
        #expect(arr?.contains(id2.uuidString) == true)
    }

    @Test("CandidateStatus.reachedQuoted threshold")
    func reachedQuoted() {
        #expect(CandidateStatus.notContacted.reachedQuoted == false)
        #expect(CandidateStatus.contacted.reachedQuoted == false)
        #expect(CandidateStatus.declined.reachedQuoted == false)
        #expect(CandidateStatus.quoted.reachedQuoted == true)
        #expect(CandidateStatus.hired.reachedQuoted == true)
    }
}

// MARK: - Persistence

@Suite("Sourcing persistence")
struct SourcingPersistenceTests {
    @Test("save and load sourcing")
    func sourcingRoundTrip() async throws {
        let (p, dir) = makeTempPersistence()
        defer { cleanup(dir) }

        let s = Sourcing(title: "Window vendor", notes: "Three quotes minimum")
        try await p.saveSourcing(s)

        let loaded = try await p.loadSourcings()
        #expect(loaded.count == 1)
        #expect(loaded[0].id == s.id)
        #expect(loaded[0].title == "Window vendor")
    }

    @Test("delete sourcing")
    func deleteSourcing() async throws {
        let (p, dir) = makeTempPersistence()
        defer { cleanup(dir) }

        let s = Sourcing(title: "Test")
        try await p.saveSourcing(s)
        try await p.deleteSourcing(id: s.id)

        let loaded = try await p.loadSourcings()
        #expect(loaded.isEmpty)
    }

    @Test("multiple sourcings stored independently")
    func multipleSourcings() async throws {
        let (p, dir) = makeTempPersistence()
        defer { cleanup(dir) }

        try await p.saveSourcing(Sourcing(title: "A"))
        try await p.saveSourcing(Sourcing(title: "B"))

        let loaded = try await p.loadSourcings()
        #expect(loaded.count == 2)
    }

}

// MARK: - Hire/cancel flow (UpkeepStore)

@Suite("Sourcing hire & cancel flows")
struct SourcingFlowTests {
    @MainActor
    private func drain(_ store: UpkeepStore) async {
        for _ in 0..<10 {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    @Test("hire winner with mixed-status losers (rule b)")
    @MainActor func hireWithRuleB() async {
        let store = makeStore()
        let memberID = UUID()
        store.localConfig.currentMemberID = memberID

        let sourcing = Sourcing(
            title: "Lawn vendor",
            candidates: [
                Candidate(name: "Acme", status: .quoted, quoteAmount: 1200),
                Candidate(name: "Bob", status: .quoted, quoteAmount: 1500),
                Candidate(name: "NoShow", status: .notContacted)
            ]
        )
        try? await store.persistence.saveSourcing(sourcing)
        store.sourcings = [sourcing]

        let winnerID = sourcing.candidates[0].id
        store.hireCandidate(winnerID, in: sourcing.id)
        await drain(store)

        let vendors = (try? await store.persistence.loadVendors()) ?? []
        #expect(vendors.count == 2)
        let active = vendors.filter(\.isActive)
        let inactive = vendors.filter { !$0.isActive }
        #expect(active.count == 1)
        #expect(active.first?.name == "Acme")
        #expect(inactive.count == 1)
        #expect(inactive.first?.name == "Bob")

        let saved = (try? await store.persistence.loadSourcings()) ?? []
        #expect(saved.count == 1)
        let s = saved[0]
        #expect(s.status == .decided)
        #expect(s.hiredCandidateID == winnerID)
        #expect(s.candidates.count == 3)
        let winnerSaved = s.candidates.first { $0.id == winnerID }
        #expect(winnerSaved?.status == .hired)
        #expect(winnerSaved?.promotedToVendorID == active.first?.id)
    }

    @Test("hire with extraSavedCandidateIDs promotes a no-show too")
    @MainActor func hireWithOverride() async {
        let store = makeStore()
        store.localConfig.currentMemberID = UUID()

        let sourcing = Sourcing(
            title: "Window vendor",
            candidates: [
                Candidate(name: "Winner", status: .quoted),
                Candidate(name: "Ghosted", status: .notContacted)
            ]
        )
        try? await store.persistence.saveSourcing(sourcing)
        store.sourcings = [sourcing]

        let winnerID = sourcing.candidates[0].id
        let ghostedID = sourcing.candidates[1].id

        store.hireCandidate(winnerID, in: sourcing.id, extraSavedCandidateIDs: [ghostedID])
        await drain(store)

        let vendors = (try? await store.persistence.loadVendors()) ?? []
        #expect(vendors.count == 2)
        let inactive = vendors.filter { !$0.isActive }
        #expect(inactive.count == 1)
        #expect(inactive.first?.name == "Ghosted")
    }

    @Test("hire with replace flow deactivates the old vendor and reassigns the linked item")
    @MainActor func hireWithReplace() async {
        let store = makeStore()
        store.localConfig.currentMemberID = UUID()

        let oldVendor = Vendor(name: "Old Lawn Co", isActive: true)
        let item = MaintenanceItem(name: "Lawn service", vendorID: oldVendor.id)
        try? await store.persistence.saveVendor(oldVendor)
        try? await store.persistence.saveItem(item)
        store.vendors = [oldVendor]
        store.items = [item]

        let sourcing = Sourcing(
            title: "Replace lawn",
            linkedItemIDs: [item.id],
            replacingVendorID: oldVendor.id,
            candidates: [Candidate(name: "New Lawn Co", status: .quoted)]
        )
        try? await store.persistence.saveSourcing(sourcing)
        store.sourcings = [sourcing]

        let winnerID = sourcing.candidates[0].id
        store.hireCandidate(winnerID, in: sourcing.id)
        await drain(store)

        let vendors = (try? await store.persistence.loadVendors()) ?? []
        #expect(vendors.count == 2)
        let oldReloaded = vendors.first { $0.id == oldVendor.id }
        #expect(oldReloaded?.isActive == false)
        let newVendor = vendors.first { $0.isActive }
        #expect(newVendor?.name == "New Lawn Co")

        let items = (try? await store.persistence.loadItems()) ?? []
        let itemReloaded = items.first { $0.id == item.id }
        #expect(itemReloaded?.vendorID == newVendor?.id)
    }

    @Test("replace flow cascades to all items currently using the replaced vendor")
    @MainActor func cascadeAcrossItems() async {
        let store = makeStore()
        store.localConfig.currentMemberID = UUID()

        let oldVendor = Vendor(name: "Old Lawn Co")
        let item1 = MaintenanceItem(name: "Mow lawn", vendorID: oldVendor.id)
        let item2 = MaintenanceItem(name: "Edge driveway", vendorID: oldVendor.id)
        let item3 = MaintenanceItem(name: "Trim hedges", vendorID: oldVendor.id)
        let unrelated = MaintenanceItem(name: "Unrelated") // no vendor — must NOT be touched

        try? await store.persistence.saveVendor(oldVendor)
        for i in [item1, item2, item3, unrelated] {
            try? await store.persistence.saveItem(i)
        }
        store.vendors = [oldVendor]
        store.items = [item1, item2, item3, unrelated]

        // Sourcing references item1 as a linked item, but item2 and item3 also use the old vendor.
        let sourcing = Sourcing(
            title: "Replace lawn vendor",
            linkedItemIDs: [item1.id],
            replacingVendorID: oldVendor.id,
            candidates: [Candidate(name: "New Lawn", status: .quoted)]
        )
        try? await store.persistence.saveSourcing(sourcing)
        store.sourcings = [sourcing]

        // Sanity: itemsAffectedOnHire returns all 3 (deduped), not 4
        #expect(store.itemsAffectedOnHire(sourcing).count == 3)

        let winnerID = sourcing.candidates[0].id
        store.hireCandidate(winnerID, in: sourcing.id)
        await drain(store)

        let vendors = (try? await store.persistence.loadVendors()) ?? []
        let newVendor = vendors.first { $0.isActive }
        #expect(newVendor?.name == "New Lawn")

        let items = (try? await store.persistence.loadItems()) ?? []
        // All three items now point at the new vendor
        for original in [item1, item2, item3] {
            let reloaded = items.first { $0.id == original.id }
            #expect(reloaded?.vendorID == newVendor?.id, "Item \(original.name) should be reassigned")
        }
        // Unrelated item still has no vendor
        let unrelatedReloaded = items.first { $0.id == unrelated.id }
        #expect(unrelatedReloaded?.vendorID == nil)
    }

    @Test("cancel preserves snapshot, no promotions")
    @MainActor func cancelPreservesSnapshot() async {
        let store = makeStore()
        store.localConfig.currentMemberID = UUID()

        let sourcing = Sourcing(
            title: "Roof",
            candidates: [
                Candidate(name: "A", status: .quoted),
                Candidate(name: "B", status: .quoted)
            ]
        )
        try? await store.persistence.saveSourcing(sourcing)
        store.sourcings = [sourcing]

        store.cancelSourcing(sourcing.id, reason: "Decided not to do it")
        await drain(store)

        let vendors = (try? await store.persistence.loadVendors()) ?? []
        #expect(vendors.isEmpty)

        let saved = (try? await store.persistence.loadSourcings()) ?? []
        #expect(saved.count == 1)
        #expect(saved[0].status == .cancelled)
        #expect(saved[0].cancelReason == "Decided not to do it")
        #expect(saved[0].candidates.count == 2)
    }

    @Test("helpers: sourcings(forItem:) and sourcings(replacing:)")
    @MainActor func helpers() async {
        let store = makeStore()
        let itemID = UUID()
        let vendorID = UUID()

        store.sourcings = [
            Sourcing(title: "A", linkedItemIDs: [itemID]),
            Sourcing(title: "B", replacingVendorID: vendorID),
            Sourcing(title: "C")
        ]

        #expect(store.sourcings(forItem: itemID).count == 1)
        #expect(store.sourcings(forItem: itemID).first?.title == "A")
        #expect(store.sourcings(replacing: vendorID).count == 1)
        #expect(store.sourcings(replacing: vendorID).first?.title == "B")
        #expect(store.activeSourcings.count == 3)
    }
}
