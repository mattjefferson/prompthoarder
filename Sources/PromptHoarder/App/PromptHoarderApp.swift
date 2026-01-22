import SwiftUI

@main
struct PromptHoarderApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }

        MenuBarExtra("Prompt Hoarder", systemImage: "doc.text.magnifyingglass") {
            MenuBarView()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
