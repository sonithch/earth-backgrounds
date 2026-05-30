import AppKit
import Foundation

enum RefreshInterval: TimeInterval, CaseIterable {
    case off           = 0
    case fifteenMin    = 900
    case thirtyMin     = 1800
    case oneHour       = 3600
    case threeHours    = 10800
    case sixHours      = 21600
    case oneDay        = 86400

    var label: String {
        switch self {
        case .off:        return "Off"
        case .fifteenMin: return "15 min"
        case .thirtyMin:  return "30 min"
        case .oneHour:    return "1 hour"
        case .threeHours: return "3 hours"
        case .sixHours:   return "6 hours"
        case .oneDay:     return "1 day"
        }
    }
}

@MainActor
class WallpaperService: ObservableObject {
    @Published var isLoading = false
    @Published var currentID: Int?
    @Published var errorMessage: String?
    @Published var selectedInterval: RefreshInterval {
        didSet {
            UserDefaults.standard.set(selectedInterval.rawValue, forKey: "timerInterval")
            scheduleTimer()
        }
    }

    private var timer: Timer?
    private let cacheDir: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("earth-backgrounds")
    }()

    init() {
        let saved = UserDefaults.standard.double(forKey: "timerInterval")
        selectedInterval = RefreshInterval(rawValue: saved) ?? .off
        scheduleTimer()
    }

    func setRandomBackground() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let (imageURL, id) = try await findRandomImageURL()
            let localURL = try await downloadImage(from: imageURL)
            try applyWallpaper(localURL)
            currentID = id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDir)
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = nil
        guard selectedInterval != .off else { return }
        timer = Timer.scheduledTimer(withTimeInterval: selectedInterval.rawValue, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.setRandomBackground()
            }
        }
    }

    // Google Earth View images (gstatic.com) — IDs in the ~1000–8000 range
    private func findRandomImageURL() async throws -> (URL, Int) {
        for _ in 0..<10 {
            let id = Int.random(in: 1000...8000)
            let url = URL(string: "https://www.gstatic.com/prettyearth/assets/full/\(id).jpg")!
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            if let (_, response) = try? await URLSession.shared.data(for: request),
               (response as? HTTPURLResponse)?.statusCode == 200 {
                return (url, id)
            }
        }
        throw URLError(.cannotFindHost)
    }

    private func downloadImage(from url: URL) async throws -> URL {
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let dest = cacheDir.appendingPathComponent(url.lastPathComponent)

        if !FileManager.default.fileExists(atPath: dest.path) {
            let (tmp, _) = try await URLSession.shared.download(from: url)
            try FileManager.default.moveItem(at: tmp, to: dest)
        }

        try pruneCache()
        return dest
    }

    private func pruneCache() throws {
        let files = try FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )
        guard files.count > 10 else { return }
        let sorted = try files.sorted {
            let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return a < b
        }
        for file in sorted.dropLast(10) {
            try FileManager.default.removeItem(at: file)
        }
    }

    private func applyWallpaper(_ url: URL) throws {
        for screen in NSScreen.screens {
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
        }
    }
}
