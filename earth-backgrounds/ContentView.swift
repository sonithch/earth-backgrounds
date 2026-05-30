import SwiftUI

struct MouseExitTracker: NSViewRepresentable {
    let onExit: () -> Void

    func makeNSView(context: Context) -> TrackingView { TrackingView(onExit: onExit) }
    func updateNSView(_ view: TrackingView, context: Context) { view.onExit = onExit }

    class TrackingView: NSView {
        var onExit: () -> Void

        init(onExit: @escaping () -> Void) {
            self.onExit = onExit
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach { removeTrackingArea($0) }
            addTrackingArea(NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways],
                owner: self
            ))
        }

        override func mouseExited(with event: NSEvent) { onExit() }
    }
}

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

struct ContentView: View {
    @StateObject private var service = WallpaperService()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Earth Backgrounds")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            MenuRow("Set Random Background", action: {
                Task { await service.setRandomBackground() }
            }, trailing: {
                if service.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                }
            })

            if let id = service.currentID {
                Text("Earth View #\(id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }

            HStack {
                Text("Change every")
                    .font(.caption)
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
            .padding(.bottom, 8)

            if let error = service.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }

            MenuRow("Clear Cache", role: .destructive, action: {
                service.clearCache()
            })

            Divider()

            MenuRow("Quit", role: .destructive, action: {
                NSApplication.shared.terminate(nil)
            })
            .padding(.bottom, 4)
        }
        .frame(width: 240)
        .background(MouseExitTracker {
            NSApplication.shared.keyWindow?.close()
        })
    }
}
