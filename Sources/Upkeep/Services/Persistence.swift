import Foundation

enum PersistenceError: Error, LocalizedError {
    case notFound(String)
    case encodingFailed(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let path): return "File not found: \(path)"
        case .encodingFailed(let msg): return "Encoding failed: \(msg)"
        case .decodingFailed(let msg): return "Decoding failed: \(msg)"
        }
    }
}

actor Persistence {
    static let shared = Persistence()

    let baseURL: URL
    private let itemsDir: URL
    private let logDir: URL
    private let vendorsDir: URL
    let photosDir: URL

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL? = nil) {
        let base = baseURL ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".upkeep")
        self.baseURL = base
        self.itemsDir = base.appendingPathComponent("items")
        self.logDir = base.appendingPathComponent("log")
        self.vendorsDir = base.appendingPathComponent("vendors")
        self.photosDir = base.appendingPathComponent("photos")

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        let fm = FileManager.default
        for dir in [base, itemsDir, logDir, vendorsDir, photosDir] {
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: - Items

    func loadItems() throws -> [MaintenanceItem] {
        try loadAll(from: itemsDir)
    }

    func saveItem(_ item: MaintenanceItem) throws {
        try save(item, id: item.id, to: itemsDir)
    }

    func deleteItem(id: UUID) throws {
        try deleteFile(id: id, from: itemsDir)
    }

    // MARK: - Log Entries

    func loadLogEntries() throws -> [LogEntry] {
        try loadAll(from: logDir)
    }

    func saveLogEntry(_ entry: LogEntry) throws {
        try save(entry, id: entry.id, to: logDir)
    }

    func deleteLogEntry(id: UUID) throws {
        try deleteFile(id: id, from: logDir)
    }

    // MARK: - Vendors

    func loadVendors() throws -> [Vendor] {
        try loadAll(from: vendorsDir)
    }

    func saveVendor(_ vendor: Vendor) throws {
        try save(vendor, id: vendor.id, to: vendorsDir)
    }

    func deleteVendor(id: UUID) throws {
        try deleteFile(id: id, from: vendorsDir)
    }

    // MARK: - Config

    func loadConfig() throws -> AppConfig {
        let configFile = baseURL.appendingPathComponent("config.json")
        let fm = FileManager.default
        guard fm.fileExists(atPath: configFile.path) else { return AppConfig() }
        let data = try Data(contentsOf: configFile)
        return try decoder.decode(AppConfig.self, from: data)
    }

    func saveConfig(_ config: AppConfig) throws {
        let configFile = baseURL.appendingPathComponent("config.json")
        let data = try encoder.encode(config)
        try data.write(to: configFile, options: .atomic)
    }

    // MARK: - Home Profile

    func loadHomeProfile() throws -> HomeProfile {
        let file = baseURL.appendingPathComponent("home.json")
        let fm = FileManager.default
        guard fm.fileExists(atPath: file.path) else { return HomeProfile() }
        let data = try Data(contentsOf: file)
        return try decoder.decode(HomeProfile.self, from: data)
    }

    func saveHomeProfile(_ profile: HomeProfile) throws {
        let file = baseURL.appendingPathComponent("home.json")
        let data = try encoder.encode(profile)
        try data.write(to: file, options: .atomic)
    }

    // MARK: - Photos

    func savePhoto(_ data: Data, filename: String) throws {
        let file = photosDir.appendingPathComponent(filename)
        try data.write(to: file, options: .atomic)
    }

    func loadPhoto(filename: String) throws -> Data {
        let file = photosDir.appendingPathComponent(filename)
        return try Data(contentsOf: file)
    }

    func deletePhoto(filename: String) throws {
        let file = photosDir.appendingPathComponent(filename)
        let fm = FileManager.default
        if fm.fileExists(atPath: file.path) {
            try fm.removeItem(at: file)
        }
    }

    func photoURL(filename: String) -> URL {
        photosDir.appendingPathComponent(filename)
    }

    // MARK: - Members

    func loadMembers() throws -> [HouseholdMember] {
        let file = baseURL.appendingPathComponent("members.json")
        let fm = FileManager.default
        guard fm.fileExists(atPath: file.path) else { return [] }
        let data = try Data(contentsOf: file)
        return try decoder.decode([HouseholdMember].self, from: data)
    }

    func saveMembers(_ members: [HouseholdMember]) throws {
        let file = baseURL.appendingPathComponent("members.json")
        let data = try encoder.encode(members)
        try data.write(to: file, options: .atomic)
    }

    // MARK: - Backup & Restore

    func backup() throws -> URL {
        let backupsDir = baseURL.appendingPathComponent("backups")
        let fm = FileManager.default
        if !fm.fileExists(atPath: backupsDir.path) {
            try fm.createDirectory(at: backupsDir, withIntermediateDirectories: true)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: .now)
        let backupFile = backupsDir.appendingPathComponent("upkeep-\(timestamp).zip")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = baseURL
        process.arguments = ["-r", backupFile.path,
                             "items", "log", "vendors", "photos",
                             "config.json", "home.json", "members.json"]
        // Only include files that exist
        let fm2 = FileManager.default
        var args = ["-r", backupFile.path]
        for name in ["items", "log", "vendors", "photos"] {
            if fm2.fileExists(atPath: baseURL.appendingPathComponent(name).path) {
                args.append(name)
            }
        }
        for name in ["config.json", "home.json", "members.json"] {
            if fm2.fileExists(atPath: baseURL.appendingPathComponent(name).path) {
                args.append(name)
            }
        }
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw PersistenceError.encodingFailed("Backup zip failed")
        }

        return backupFile
    }

    func restore(from zipURL: URL) throws {
        let fm = FileManager.default
        let dataDirs = ["items", "log", "vendors", "photos"]
        let dataFiles = ["config.json", "home.json", "members.json"]

        // 1. Unzip to temp dir to verify integrity
        let tempDir = fm.temporaryDirectory.appendingPathComponent("upkeep-restore-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", zipURL.path, "-d", tempDir.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            try? fm.removeItem(at: tempDir)
            throw PersistenceError.decodingFailed("Restore failed: corrupt zip")
        }

        guard fm.fileExists(atPath: tempDir.appendingPathComponent("items").path) else {
            try? fm.removeItem(at: tempDir)
            throw PersistenceError.decodingFailed("Restore failed: invalid backup")
        }

        // 2. Move current data to safety copy
        let safetyDir = fm.temporaryDirectory.appendingPathComponent("upkeep-safety-\(UUID().uuidString)")
        try fm.createDirectory(at: safetyDir, withIntermediateDirectories: true)

        for name in dataDirs + dataFiles {
            let src = baseURL.appendingPathComponent(name)
            if fm.fileExists(atPath: src.path) {
                try fm.moveItem(at: src, to: safetyDir.appendingPathComponent(name))
            }
        }

        // 3. Move restored data into place
        let extracted = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        for item in extracted {
            let dest = baseURL.appendingPathComponent(item.lastPathComponent)
            try fm.moveItem(at: item, to: dest)
        }

        // 4. Clean up
        try? fm.removeItem(at: tempDir)
        try? fm.removeItem(at: safetyDir)

        // Re-create directories if they didn't exist in the backup
        for dir in [itemsDir, logDir, vendorsDir, photosDir] {
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    func listBackups() throws -> [URL] {
        let backupsDir = baseURL.appendingPathComponent("backups")
        let fm = FileManager.default
        guard fm.fileExists(atPath: backupsDir.path) else { return [] }
        let contents = try fm.contentsOfDirectory(at: backupsDir, includingPropertiesForKeys: [.contentModificationDateKey])
        return contents
            .filter { $0.pathExtension == "zip" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    // MARK: - Generic Helpers

    private func loadAll<T: Decodable>(from directory: URL) throws -> [T] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        var results: [T] = []
        for entry in entries where entry.pathExtension == "json" {
            let data = try Data(contentsOf: entry)
            let item = try decoder.decode(T.self, from: data)
            results.append(item)
        }
        return results
    }

    private func save<T: Encodable>(_ item: T, id: UUID, to directory: URL) throws {
        let data = try encoder.encode(item)
        let file = directory.appendingPathComponent("\(id.uuidString).json")
        try data.write(to: file, options: .atomic)
    }

    private func deleteFile(id: UUID, from directory: URL) throws {
        let file = directory.appendingPathComponent("\(id.uuidString).json")
        let fm = FileManager.default
        guard fm.fileExists(atPath: file.path) else {
            throw PersistenceError.notFound(file.path)
        }
        try fm.removeItem(at: file)
    }
}
