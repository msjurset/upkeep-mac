import SwiftUI
import Sparkle

@main
struct UpkeepApp: App {
    @NSApplicationDelegateAdaptor(UpkeepAppDelegate.self) private var appDelegate
    @State private var store = UpkeepStore()
    @State private var weather = WeatherStore()
    @Environment(\.openWindow) private var openWindow
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var body: some Scene {
        WindowGroup {
            Group {
                if store.needsOnboarding {
                    OnboardingView()
                        .environment(store)
                        .environment(weather)
                } else {
                    ContentView()
                        .environment(store)
                        .environment(weather)
                }
            }
            .preferredColorScheme(store.colorScheme)
            .tint(.upkeepAmber)
            .onAppear {
                store.startBackgroundRefresh()
                weather.startBackgroundRefresh()
                Task {
                    if let profile = try? await store.loadHomeProfile() {
                        weather.applyLocation(latitude: profile.latitude, longitude: profile.longitude)
                    }
                }
            }
            .onDisappear {
                store.stopBackgroundRefresh()
                weather.stopBackgroundRefresh()
            }
        }
        .defaultSize(width: 1300, height: 750)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
            CommandGroup(replacing: .help) {
                Button("Upkeep Help") {
                    openWindow(id: "help")
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(store)
                .environment(weather)
                .preferredColorScheme(store.colorScheme)
        }

        WindowGroup("Upkeep Help", id: "help") {
            HelpView()
        }
        .defaultSize(width: 600, height: 500)
    }
}

// MARK: - Check for Updates Menu Item

struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates...") {
            updater.checkForUpdates()
        }
        .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    private var timer: Timer?

    init(updater: SPUUpdater) {
        // Poll canCheckForUpdates since KVO keypaths don't work with MainActor in Swift 6
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
        canCheckForUpdates = updater.canCheckForUpdates
    }
}
