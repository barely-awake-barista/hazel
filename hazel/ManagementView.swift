import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Constants
private enum AppConstants {
    static let githubURL = URL(string: "https://github.com/harryfrzz/hazel")!
    static let allowedMovieTypes: [UTType] = [.movie, .mpeg4Movie, .quickTimeMovie]
}

// MARK: - View
struct ManagementView: View {
    @ObservedObject var store: WallpaperStore
    @ObservedObject var controller: WallpaperController
    let windowController: ManagementWindowController
    var settings = SettingsManager.shared
    
    @State private var showingFileImporter = false
    @State private var showingDuplicateAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var duplicateVideoName = ""
    
    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 0) {
            
            // ── UNIFIED HEADER (Identity + Status) ───────
            appHeader
            
            // ── TOP FIXED (Management) ────────────────────
            hdr("Management")
            grp {
                AddRow { showingFileImporter = true }
                    .fileImporter(
                        isPresented: $showingFileImporter,
                        allowedContentTypes: AppConstants.allowedMovieTypes,
                        allowsMultipleSelection: true,
                        onCompletion: handleFileImport
                    )
            }
            
            // ── SCROLLABLE AREA (Library + Config) ────────
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // ── WALLPAPER LIBRARY ─────────────────
                    hdr("Wallpaper Library")
                    grp {
                        if store.wallpapers.isEmpty {
                            emptyLibraryRow
                        } else {
                            let wallpapers = store.wallpapers
                            ForEach(0..<wallpapers.count, id: \.self) { idx in
                                wallpaperRowHelper(idx: idx, item: wallpapers[idx])
                                if idx < wallpapers.count - 1 {
                                    rowDivider()
                                }
                            }
                        }
                    }
                    
                    // ── VIDEO FILTERS ─────────────────────
                    hdr("Video Filters")
                    grp {
                        VStack(spacing: 8) {
                            FilterSlider(icon: "sun.max", label: "Brightness", value: $settings.brightness, range: -1...1, resetValue: 0.0)
                            FilterSlider(icon: "drop", label: "Saturation", value: $settings.saturation, range: 0...2, resetValue: 1.0)
                            FilterSlider(icon: "rainbow", label: "Hue", value: $settings.hue, range: -Double.pi...Double.pi, resetValue: 0.0)
                            FilterSlider(icon: "aqi.medium", label: "Blur", value: $settings.blur, range: 0...10, resetValue: 0.0)
                        }
                        .padding(10)
                        .onChange(of: settings.brightness) { controller.updateFilters() }
                        .onChange(of: settings.saturation) { controller.updateFilters() }
                        .onChange(of: settings.hue) { controller.updateFilters() }
                        .onChange(of: settings.blur) { controller.updateFilters() }
                    }
                    
                    // ── PREFERENCES ───────────────────────
                    hdr("Preferences")
                    grp {
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Image(systemName: "aspectratio").font(.system(size: 11)).foregroundStyle(.tertiary)
                                Text("Fit Mode").font(Design.geist(12))
                                Spacer()
                                Picker("", selection: $settings.wallpaperFit) {
                                    ForEach(WallpaperFit.allCases, id: \.self) { fit in
                                        Text(fit.rawValue).tag(fit)
                                    }
                                }
                                .pickerStyle(.menu).scaleEffect(0.85).labelsHidden()
                                .onChange(of: settings.wallpaperFit) { controller.reloadCurrentWallpaper() }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 2)
                            
                            rowDivider().opacity(0.15)
                            
                            Toggle(isOn: $settings.openOnStartup) {
                                HStack(spacing: 8) {
                                    Image(systemName: "app.badge.checkmark").font(.system(size: 11)).foregroundStyle(.tertiary)
                                    Text("Auto-Start").font(Design.geist(12))
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                            .scaleEffect(0.8)
                            .padding(.horizontal, 10).padding(.vertical, 2)
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
            
            // ── FOOTER ────────────────────────────────────
            footerView
        }
        .frame(width: 320, height: 560)
        .background(
            VisualEffectView(material: NSVisualEffectView.Material.popover, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        )
        .onChange(of: showingFileImporter) { _, newValue in
            windowController.isBusy = newValue
        }
        .alert("Wallpaper Already Exists", isPresented: $showingDuplicateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The wallpaper \"\(duplicateVideoName)\" is already in your library.")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Subviews

    @ViewBuilder
    private func wallpaperRowHelper(idx: Int, item: WallpaperItem) -> some View {
        WallpaperRow(
            item: item,
            isSelected: store.activeWallpaperID == item.id,
            onTap: {
                withAnimation(.spring(duration: 0.3)) {
                    store.setActiveWallpaper(item)
                    controller.setWallpaper(item)
                }
            },
            onRemove: {
                if store.activeWallpaperID == item.id {
                    controller.clearWallpaper()
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.removeWallpaper(item)
                }
            },
            onToggleLoop: {
                store.toggleLoop(for: item)
                if store.activeWallpaperID == item.id {
                    if let updated = store.wallpapers.first(where: { $0.id == item.id }) {
                        controller.setWallpaper(updated)
                    }
                }
            },
            onToggleMute: {
                store.toggleMute(for: item)
                if store.activeWallpaperID == item.id {
                    if let updated = store.wallpapers.first(where: { $0.id == item.id }) {
                        controller.setWallpaper(updated)
                    }
                }
            },
            onToggleBounce: {
                store.toggleBounce(for: item)
                if store.activeWallpaperID == item.id {
                    if let updated = store.wallpapers.first(where: { $0.id == item.id }) {
                        controller.setWallpaper(updated)
                    }
                }
            },
            onMirror: { store.mirrorWallpaper(item) },
            onShowInFinder: {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
        )
    }
    
    private var appHeader: some View {
        ZStack {
            // ── CENTERED BRAND MARK (ELARGED) ─────────────
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
            
            HStack(spacing: 0) {
                // ── NAME (Left) ───────────────────────────
                Text("Hazel")
                    .font(Design.geist(17))
                    .tracking(0.5)
                
                Spacer()
                
                // ── STATUS (Right) ────────────────────────
                HStack(spacing: 8) {
                    if controller.isActive {
                        Button(action: {
                            controller.togglePlayback()
                        }) {
                            Text(controller.isPaused ? "RESUME" : "STOP")
                                .font(Design.geist(10))
                                .foregroundStyle(controller.isPaused ? Color.accentColor : Color.red)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(
                                    (controller.isPaused ? Color.accentColor : Color.red).opacity(0.1),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .help(controller.isPaused ? "Resume video playback" : "Pause current wallpaper")
                    }
                    
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(store.activeWallpaperID == nil ? Color.gray.opacity(0.15) : Color.neonGreen.opacity(0.2))
                            Circle()
                                .fill(store.activeWallpaperID == nil ? Color.gray.opacity(0.5) : Color.neonGreen)
                                .frame(width: 6, height: 6)
                                .shadow(color: (store.activeWallpaperID == nil ? Color.clear : Color.neonGreen.opacity(0.7)), radius: 4)
                        }
                        .frame(width: 14, height: 14)
                        
                        Text(store.activeWallpaperID == nil ? "IDLE" : "LIVE")
                            .font(Design.geist(11))
                            .foregroundStyle(store.activeWallpaperID == nil ? .secondary : .primary)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.primary.opacity(0.04), in: Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4).padding(.bottom, 4)
    }
    
    private var emptyLibraryRow: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "video.slash")
                    .font(.system(size: 18))
                    .foregroundStyle(.quaternary)
                Text("Library is empty")
                    .font(Design.geist(12))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }

    private var footerView: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.1)
            HStack(spacing: 0) {
                Button(action: quitApp) {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(width: 22, height: 22)
                        .background(.primary.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Quit Hazel")
                
                Spacer()
                
                Text("v1.1.0").font(Design.geist(11)).foregroundStyle(.tertiary)
                
                Spacer()
                
                Link(destination: AppConstants.githubURL) {
                    Image(systemName: "link")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 4)
        }
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Primitives
    
    @ViewBuilder
    private func grp<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .glassEffect(NSVisualEffectView.Material.contentBackground, in: RoundedRectangle(cornerRadius: Design.glassCornerRadius, style: .continuous))
            .padding(.horizontal, 13)
            .padding(.bottom, 4)
    }

    private func hdr(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Design.geist(11))
            .foregroundStyle(.tertiary)
            .tracking(0.5)
            .padding(.leading, 16)
            .padding(.top, 14).padding(.bottom, 6)
    }

    private func rowDivider() -> some View {
        Divider().padding(.horizontal, 10).opacity(0.25)
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var lastAddedItem: WallpaperItem?
            var hasDuplicate = false
            for url in urls {
                let fileName = url.deletingPathExtension().lastPathComponent
                if store.wallpapers.contains(where: { $0.title == fileName }) {
                    duplicateVideoName = fileName
                    hasDuplicate = true
                    continue
                }
                if let item = store.addWallpaper(url: url) {
                    lastAddedItem = item
                }
            }
            if hasDuplicate { showingDuplicateAlert = true }
            if let itemToActivate = lastAddedItem {
                store.setActiveWallpaper(itemToActivate)
                controller.setWallpaper(itemToActivate)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
}

// MARK: - Window Controller
class ManagementWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    var isBusy: Bool = false
    
    func togglePanel(store: WallpaperStore, controller: WallpaperController, relativeTo button: NSButton) {
        if let existingPanel = panel, existingPanel.isVisible {
            closePanel()
            return
        }
        showPanel(store: store, controller: controller, relativeTo: button)
    }
    
    private func showPanel(store: WallpaperStore, controller: WallpaperController, relativeTo button: NSButton) {
        if panel == nil {
            let hostingView = NSHostingView(rootView: ManagementView(store: store, controller: controller, windowController: self))
            let newPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 560),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            newPanel.isMovableByWindowBackground = false
            newPanel.isReleasedWhenClosed = false
            newPanel.backgroundColor = .clear
            newPanel.hasShadow = true
            newPanel.level = .mainMenu
            newPanel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
            newPanel.contentView = hostingView
            newPanel.delegate = self
            panel = newPanel
        }
        
        guard let panel = panel else { return }
        
        if let window = button.window {
            let buttonFrame = window.convertToScreen(button.frame)
            let panelFrame = panel.frame
            let x = buttonFrame.origin.x + (buttonFrame.width / 2) - (panelFrame.width / 2)
            let y = buttonFrame.origin.y - panelFrame.height - 5
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startMonitors()
        
        NotificationCenter.default.addObserver(self, selector: #selector(closePanel), name: NSApplication.didResignActiveNotification, object: nil)
    }
    
    @objc func closePanel() {
        guard !isBusy else { return }
        guard let existingPanel = panel else { return }
        stopMonitors()
        NotificationCenter.default.removeObserver(self, name: NSApplication.didResignActiveNotification, object: nil)
        
        existingPanel.orderOut(nil)
        self.panel = nil
    }
    
    private func startMonitors() {
        stopMonitors()
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.panel, panel.isVisible, !self.isBusy else { return event }
            if event.window != panel {
                self.closePanel()
            }
            return event
        }
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, !self.isBusy else { return }
            self.closePanel()
        }
    }
    
    private func stopMonitors() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        stopMonitors()
    }
}

// ── SUBVIEWS ───────────────────────────────────

struct FilterSlider: View {
    let icon: String
    let label: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var resetValue: Double = 0.0
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 10)).foregroundStyle(.tertiary)
                Text(label).font(Design.geist(11))
                Spacer()
                
                if abs(value - resetValue) > 0.05 {
                    Button(action: { 
                        withAnimation(.spring(duration: 0.2)) { value = resetValue }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.accentColor.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Reset to original value")
                }
                
                Text(String(format: "%.1f", value))
                    .font(Design.geist(10)).foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .trailing)
            }
            Slider(value: $value, in: range)
                .controlSize(.mini)
        }
    }
}

struct AddRow: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.15))
                    Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.accentColor)
                }
                .frame(width: 22, height: 22)
                
                Text("Add New Wallpaper").font(Design.geist(13))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Import video files from your Mac")
    }
}
