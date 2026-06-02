import AppKit
import Foundation
import ServiceManagement

// MARK: - Errors

enum WallpaperError: LocalizedError {
    case noImageFound

    var errorDescription: String? {
        "No Earth View image could be found after several attempts. Try again later."
    }
}

// MARK: - Models

struct ImageInfo: Codable {
    let id: Int
    let url: URL
    let fetchedAt: Date
    var title: String?
    var country: String?
    var region: String?
    var lat: Double?
    var lng: Double?
    var mapsLink: String?

    init(id: Int, url: URL, meta: EarthViewData?) {
        self.id        = id
        self.url       = url
        self.fetchedAt = Date()
        self.title     = meta?.geocode?.locality
        self.region    = meta?.geocode?.administrative_area_level_1
        self.country   = meta?.geocode?.country
        self.lat       = meta?.lat
        self.lng       = meta?.lng
        if let lat = meta?.lat, let lng = meta?.lng {
            self.mapsLink = "https://www.google.com/maps/@\(lat),\(lng),14z"
        }
    }
}

struct EarthViewData: Decodable {
    struct Geocode: Decodable {
        let locality: String?
        let administrative_area_level_1: String?
        let country: String?
    }
    let geocode: Geocode?
    let lat: Double?
    let lng: Double?
}

private struct PrefetchedWallpaper {
    let localURL: URL
    let id: Int
    let imageURL: URL
    let meta: EarthViewData?
}

// MARK: - Refresh interval

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

// MARK: - Service

@MainActor
class WallpaperService: ObservableObject {
    @Published var isLoading = false
    @Published var currentInfo: ImageInfo?
    @Published var errorMessage: String?
    @Published var launchAtLogin: Bool
    @Published var selectedInterval: RefreshInterval {
        didSet {
            UserDefaults.standard.set(selectedInterval.rawValue, forKey: Keys.timerInterval)
            scheduleTimer()
        }
    }

    private var timer: Timer?
    private var prefetchTask: Task<Void, Never>?
    private var prefetchBuffer: [PrefetchedWallpaper] = []
    private let prefetchBufferSize = 2

    private let cacheDir: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("earth-backgrounds")
    }()

    private enum Keys {
        static let timerInterval   = "timerInterval"
        static let currentImageInfo = "currentImageInfo"
    }

    init() {
        let saved = UserDefaults.standard.double(forKey: Keys.timerInterval)
        selectedInterval = RefreshInterval(rawValue: saved) ?? .off
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if let data = UserDefaults.standard.data(forKey: Keys.currentImageInfo),
           let info = try? JSONDecoder().decode(ImageInfo.self, from: data) {
            currentInfo = info
        }
        scheduleTimer()
    }

    func setRandomBackground() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let localURL: URL
            let id: Int
            let imageURL: URL
            let meta: EarthViewData?

            if !prefetchBuffer.isEmpty {
                let p = prefetchBuffer.removeFirst()
                localURL = p.localURL
                id       = p.id
                imageURL = p.imageURL
                meta     = p.meta
            } else {
                let (imgURL, imgID) = try await findRandomImageURL()
                async let metaTask = fetchMetadata(id: imgID)
                localURL = try await downloadImage(from: imgURL)
                id       = imgID
                imageURL = imgURL
                meta     = try? await metaTask
            }

            try applyWallpaper(localURL)

            let info = ImageInfo(id: id, url: imageURL, meta: meta)
            currentInfo = info
            if let data = try? JSONEncoder().encode(info) {
                UserDefaults.standard.set(data, forKey: Keys.currentImageInfo)
            }

            startPrefetch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearCache() {
        prefetchTask?.cancel()
        prefetchBuffer.removeAll()
        do {
            try FileManager.default.removeItem(at: cacheDir)
            currentInfo = nil
            UserDefaults.standard.removeObject(forKey: Keys.currentImageInfo)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = nil
        prefetchTask?.cancel()
        prefetchBuffer.removeAll()

        guard selectedInterval != .off else { return }

        startPrefetch()
        timer = Timer.scheduledTimer(withTimeInterval: selectedInterval.rawValue, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.setRandomBackground()
            }
        }
    }

    // Fills the prefetch buffer in the background; retries each slot on failure
    private func startPrefetch() {
        prefetchTask?.cancel()
        prefetchTask = Task {
            while prefetchBuffer.count < prefetchBufferSize {
                guard !Task.isCancelled else { return }
                guard let (imageURL, id) = try? await findRandomImageURL() else { continue }
                async let metaTask = fetchMetadata(id: id)
                guard let localURL = try? await downloadImage(from: imageURL) else { continue }
                let meta = try? await metaTask
                guard !Task.isCancelled else { return }
                prefetchBuffer.append(PrefetchedWallpaper(localURL: localURL, id: id, imageURL: imageURL, meta: meta))
            }
        }
    }

    private func fetchMetadata(id: Int) async throws -> EarthViewData {
        let url = URL(string: "https://www.gstatic.com/prettyearth/assets/data/\(id).json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(EarthViewData.self, from: data)
    }

    // Probes 5 random IDs concurrently; returns the first that responds 200
    private func findRandomImageURL() async throws -> (URL, Int) {
        try await withThrowingTaskGroup(of: (URL, Int)?.self) { group in
            for _ in 0..<5 {
                let id = Int.random(in: 1000...8000)
                let url = URL(string: "https://www.gstatic.com/prettyearth/assets/full/\(id).jpg")!
                group.addTask {
                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"
                    guard let (_, response) = try? await URLSession.shared.data(for: request),
                          (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
                    return (url, id)
                }
            }
            for try await result in group {
                if let found = result {
                    group.cancelAll()
                    return found
                }
            }
            throw WallpaperError.noImageFound
        }
    }

    private func downloadImage(from url: URL) async throws -> URL {
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let dest = cacheDir.appendingPathComponent(url.lastPathComponent)

        if !FileManager.default.fileExists(atPath: dest.path) {
            let (tmp, _) = try await URLSession.shared.download(from: url)
            do {
                try FileManager.default.moveItem(at: tmp, to: dest)
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                try? FileManager.default.removeItem(at: tmp)
            }
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
        let sorted = files.sorted {
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
