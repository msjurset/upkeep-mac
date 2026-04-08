import Foundation

enum AppAppearance: String, Codable, CaseIterable, Sendable {
    case system
    case dark
    case light

    var label: String {
        switch self {
        case .system: "System"
        case .dark: "Dark"
        case .light: "Light"
        }
    }
}

enum LaunchView: String, Codable, CaseIterable, Sendable {
    case dashboard
    case lastUsed

    var label: String {
        switch self {
        case .dashboard: "Dashboard"
        case .lastUsed: "Last Used"
        }
    }
}

struct LocalConfig: Equatable, Sendable {
    var currentMemberID: UUID?
    var dataLocation: String?
    var showMyTasksOnly: Bool = false
    var appearance: AppAppearance = .system
    var defaultPerformer: String = ""
    var launchView: LaunchView = .dashboard
    var lastNavigationKey: String = "dashboard"

}

extension LocalConfig: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentMemberID = try container.decodeIfPresent(UUID.self, forKey: .currentMemberID)
        dataLocation = try container.decodeIfPresent(String.self, forKey: .dataLocation)
        showMyTasksOnly = try container.decodeIfPresent(Bool.self, forKey: .showMyTasksOnly) ?? false
        appearance = try container.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? .system
        defaultPerformer = try container.decodeIfPresent(String.self, forKey: .defaultPerformer) ?? ""
        launchView = try container.decodeIfPresent(LaunchView.self, forKey: .launchView) ?? .dashboard
        lastNavigationKey = try container.decodeIfPresent(String.self, forKey: .lastNavigationKey) ?? "dashboard"
    }
}

extension LocalConfig {
    static let configURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Upkeep")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("local-config.json")
    }()

    static func load() -> LocalConfig {
        guard FileManager.default.fileExists(atPath: configURL.path),
              let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(LocalConfig.self, from: data) else {
            return LocalConfig()
        }
        return config
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: Self.configURL, options: .atomic)
    }

    var resolvedDataURL: URL {
        if let loc = dataLocation, !loc.isEmpty {
            return URL(fileURLWithPath: (loc as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".upkeep")
    }
}
