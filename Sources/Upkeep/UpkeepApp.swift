import SwiftUI

@main
struct UpkeepApp: App {
    @State private var store = UpkeepStore()
    @Environment(\.openWindow) private var openWindow

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
            .onAppear {
                store.startBackgroundRefresh()
            }
            .onDisappear {
                store.stopBackgroundRefresh()
            }
        }
        .defaultSize(width: 1300, height: 750)
        .commands {
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
        }

        WindowGroup("Upkeep Help", id: "help") {
            HelpView()
        }
        .defaultSize(width: 600, height: 500)
    }
}
