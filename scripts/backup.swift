#!/usr/bin/env swift

import Foundation

let args = CommandLine.arguments
let command = args.count > 1 ? args[1] : "backup"

let home = FileManager.default.homeDirectoryForCurrentUser
let baseDir = home.appendingPathComponent(".upkeep")
let backupsDir = baseDir.appendingPathComponent("backups")
let fm = FileManager.default

let dataDirs = ["items", "log", "vendors", "photos"]
let dataFiles = ["config.json", "home.json", "members.json"]

func doBackup() {
    if !fm.fileExists(atPath: backupsDir.path) {
        try! fm.createDirectory(at: backupsDir, withIntermediateDirectories: true)
    }

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let timestamp = formatter.string(from: .now)
    let backupFile = backupsDir.appendingPathComponent("upkeep-\(timestamp).zip")

    var zipArgs = ["-r", backupFile.path]
    for name in dataDirs where fm.fileExists(atPath: baseDir.appendingPathComponent(name).path) {
        zipArgs.append(name)
    }
    for name in dataFiles where fm.fileExists(atPath: baseDir.appendingPathComponent(name).path) {
        zipArgs.append(name)
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    process.currentDirectoryURL = baseDir
    process.arguments = zipArgs
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try! process.run()
    process.waitUntilExit()

    if process.terminationStatus == 0 {
        print("Backup created: \(backupFile.path)")
    } else {
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        print("Backup failed: \(output)")
        Foundation.exit(1)
    }
}

func doRestore() {
    guard args.count > 2 else {
        print("Usage: backup.swift restore <path-to-zip>")
        Foundation.exit(1)
    }
    let zipPath = args[2]
    guard fm.fileExists(atPath: zipPath) else {
        print("File not found: \(zipPath)")
        Foundation.exit(1)
    }

    // 1. Unzip to temp dir to verify integrity before touching real data
    let tempDir = fm.temporaryDirectory.appendingPathComponent("upkeep-restore-\(UUID().uuidString)")
    try! fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-o", zipPath, "-d", tempDir.path]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try! process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        try? fm.removeItem(at: tempDir)
        print("Restore failed (corrupt zip): \(output)")
        Foundation.exit(1)
    }

    // 2. Verify the backup looks valid
    guard fm.fileExists(atPath: tempDir.appendingPathComponent("items").path) else {
        try? fm.removeItem(at: tempDir)
        print("Restore failed: backup appears invalid (no items directory)")
        Foundation.exit(1)
    }

    // 3. Move current data to safety copy (so we can roll back if something fails)
    let safetyDir = fm.temporaryDirectory.appendingPathComponent("upkeep-safety-\(UUID().uuidString)")
    try! fm.createDirectory(at: safetyDir, withIntermediateDirectories: true)

    for name in dataDirs + dataFiles {
        let src = baseDir.appendingPathComponent(name)
        if fm.fileExists(atPath: src.path) {
            try! fm.moveItem(at: src, to: safetyDir.appendingPathComponent(name))
        }
    }

    // 4. Move restored data into place
    let extracted = try! fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
    for item in extracted {
        let dest = baseDir.appendingPathComponent(item.lastPathComponent)
        try! fm.moveItem(at: item, to: dest)
    }

    // 5. Re-create empty dirs if they weren't in the backup
    for dir in dataDirs {
        let dirURL = baseDir.appendingPathComponent(dir)
        if !fm.fileExists(atPath: dirURL.path) {
            try! fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }
    }

    // 6. Clean up temp dirs
    try? fm.removeItem(at: tempDir)
    try? fm.removeItem(at: safetyDir)

    print("Restored from: \(zipPath)")
}

func doList() {
    if !fm.fileExists(atPath: backupsDir.path) {
        print("No backups found")
        return
    }
    let contents = (try? fm.contentsOfDirectory(at: backupsDir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
    let zips = contents
        .filter { $0.pathExtension == "zip" }
        .sorted { $0.lastPathComponent > $1.lastPathComponent }

    if zips.isEmpty {
        print("No backups found")
    } else {
        for file in zips {
            let attrs = try? fm.attributesOfItem(atPath: file.path)
            let size = (attrs?[.size] as? Int64) ?? 0
            let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            print("\(file.lastPathComponent)  (\(sizeStr))")
        }
    }
}

switch command {
case "backup": doBackup()
case "restore": doRestore()
case "list": doList()
default:
    print("Usage: backup.swift [backup|restore <zip>|list]")
    Foundation.exit(1)
}
