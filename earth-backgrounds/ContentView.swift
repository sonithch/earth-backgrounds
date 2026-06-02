import AppKit
import SwiftUI

// MARK: - Mouse exit

struct MouseExitTracker: NSViewRepresentable {
    func makeNSView(context: Context) -> TrackingView { TrackingView() }
    func updateNSView(_ view: TrackingView, context: Context) {}

    class TrackingView: NSView {
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach { removeTrackingArea($0) }
            addTrackingArea(NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways],
                owner: self
            ))
        }

        override func mouseExited(with event: NSEvent) { window?.close() }
    }
}

// MARK: - Shared components

struct MenuRow<Trailing: View>: View {
    let label: String
    let role: ButtonRole?
    let action: () -> Void
    @ViewBuilder let trailing: () -> Trailing
    @State private var isHovered = false

    init(
        _ label: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.label = label
        self.role = role
        self.action = action
        self.trailing = trailing
    }

    var highlightColor: Color {
        role == .destructive ? .red : .accentColor
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .foregroundStyle(isHovered && role == .destructive ? .red : .primary)
                Spacer()
                trailing()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? highlightColor.opacity(0.12) : Color.clear)
                    .padding(.horizontal, 6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer()
        }
    }
}

// MARK: - Views

struct HomeView: View {
    @ObservedObject var service: WallpaperService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuRow("Change Background", action: {
                Task { await service.setRandomBackground() }
            }, trailing: {
                if service.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                }
            })

            HStack {
                Text("Change every")
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $service.selectedInterval) {
                    ForEach(RefreshInterval.allCases, id: \.rawValue) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 90)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if let error = service.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }

            HStack {
                Text("Launch at login")
                Spacer()
                Toggle("", isOn: Binding(
                    get: { service.launchAtLogin },
                    set: { service.setLaunchAtLogin($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            MenuRow("Clear Cache", role: .destructive, action: {
                service.clearCache()
            })
        }
    }
}

struct InfoView: View {
    @ObservedObject var service: WallpaperService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let info = service.currentInfo {
                VStack(alignment: .leading, spacing: 8) {
                    if let title = info.title {
                        Text(title)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }

                    if let country = info.country {
                        let place = [info.region, country].compactMap { $0 }.joined(separator: ", ")
                        Text(place)
                            .foregroundStyle(.secondary)
                    }

                    Divider().padding(.vertical, 2)

                    if let lat = info.lat, let lng = info.lng {
                        InfoRow(label: "Coords", value: coordString(lat, lng))
                    }
                    InfoRow(label: "Set", value: info.fetchedAt.formatted(date: .abbreviated, time: .shortened))
                    InfoRow(label: "ID", value: "#\(info.id)")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if let link = info.mapsLink, let url = URL(string: link) {
                    MenuRow("View on Maps", action: {
                        NSWorkspace.shared.open(url)
                    })
                }

                MenuRow("Copy URL", action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(info.url.absoluteString, forType: .string)
                })
            } else {
                Text("No wallpaper set yet.\nUse Home to set one.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
    }

    private func coordString(_ lat: Double, _ lng: Double) -> String {
        String(format: "%.4f° %@,  %.4f° %@",
               abs(lat), lat >= 0 ? "N" : "S",
               abs(lng), lng >= 0 ? "E" : "W")
    }
}

// MARK: - Root

struct ContentView: View {
    @StateObject private var service = WallpaperService()
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Earth Backgrounds")
                    .font(.headline)
                Spacer()
                Button { showInfo.toggle() } label: {
                    Image(systemName: showInfo ? "info.circle.fill" : "info.circle")
                        .imageScale(.medium)
                        .foregroundStyle(showInfo ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            if showInfo {
                InfoView(service: service)
            } else {
                HomeView(service: service)
            }

            Divider()

            MenuRow("Quit", role: .destructive, action: {
                NSApplication.shared.terminate(nil)
            })
            .padding(.bottom, 4)
        }
        .font(.callout)
        .frame(width: 260)
        .background(MouseExitTracker())
    }
}
