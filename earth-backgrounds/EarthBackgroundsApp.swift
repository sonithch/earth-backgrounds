import SwiftUI

@main
struct EarthBackgroundsApp: App {
    @StateObject private var service = WallpaperService()

    var body: some Scene {
        MenuBarExtra("Earth Backgrounds", systemImage: "globe.americas.fill") {
            ContentView()
                .environmentObject(service)
        }
        .menuBarExtraStyle(.window)
    }
}
