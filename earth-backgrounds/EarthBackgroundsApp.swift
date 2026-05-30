import SwiftUI

@main
struct EarthBackgroundsApp: App {
    var body: some Scene {
        MenuBarExtra("Earth Backgrounds", systemImage: "globe.americas.fill") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
