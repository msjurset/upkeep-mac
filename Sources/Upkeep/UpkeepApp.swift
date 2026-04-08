import SwiftUI
import Sparkle

@main
struct UpkeepApp: App {
    @State private var store = UpkeepStore()
    @Environment(\.openWindow) private var openWindow
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var body: some Scene {
        WindowGroup {
            Group {
                if store.needsOnboarding {
                    OnboardingView()
                        .environment(store)
                } else {
                    ContentView()
                        .environment(store)
                }
            }
            .preferredColorScheme(store.colorScheme)
            .onAppear {
                store.startBackgroundRefresh()
            }
            .onDisappear {
                store.stopBackgroundRefresh()
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
