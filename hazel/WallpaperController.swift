import AppKit
import Combine
import AVFoundation

class WallpaperController: ObservableObject {
    @Published private(set) var isActive: Bool = false
    @Published var isPaused: Bool = false
    
    private var wallpaperWindows: [NSScreen: (window: WallpaperWindow, playerView: VideoPlayerView)] = [:]
    private var store: WallpaperStore
    private var screenObserver: Any?
    private var sleepObserver: Any?
    private var wakeObserver: Any?

    init(store: WallpaperStore) {
        self.store = store
        setupNotifications()
    }

    deinit {
        removeNotifications()
    }

    private func setupNotifications() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }

        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter

        sleepObserver = notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pauseAll()
        }

        wakeObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resumeIfNeeded()
        }
    }

    private func removeNotifications() {
        if let observer = screenObserver { NotificationCenter.default.removeObserver(observer) }
        if let observer = sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        if let observer = wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    private func handleScreenChange() {
        let currentScreens = Set(NSScreen.screens)
        let existingScreens = Set(wallpaperWindows.keys)

        let screensToRemove = existingScreens.subtracting(currentScreens)
        for screen in screensToRemove {
            if let entry = wallpaperWindows.removeValue(forKey: screen) {
                entry.playerView.cleanup()
                entry.window.close()
            }
        }

        let screensToAdd = currentScreens.subtracting(existingScreens)
        for screen in screensToAdd {
            createWallpaperWindow(for: screen)
        }

        for (screen, entry) in wallpaperWindows {
            entry.window.setFrame(screen.frame, display: true)
        }

        resumeIfNeeded()
    }

    private func createWallpaperWindow(for screen: NSScreen) {
        let window = WallpaperWindow(screen: screen)
        let playerView = VideoPlayerView(frame: screen.frame)
        
        window.contentView = playerView
        window.orderFront(nil)
        
        wallpaperWindows[screen] = (window, playerView)
    }

    func setWallpaper(_ item: WallpaperItem) {
        isActive = true
        isPaused = false
        store.setActiveWallpaper(item)

        for screen in NSScreen.screens {
            if wallpaperWindows[screen] == nil {
                createWallpaperWindow(for: screen)
            }
        }

        guard let activeItem = store.activeWallpaper,
              let url = store.resolveBookmark(activeItem.url) else {
            return
        }

        for (_, entry) in wallpaperWindows {
            entry.playerView.loadVideo(url: url, isLooping: activeItem.isLooping, isMuted: activeItem.isMuted, isBounce: activeItem.isBounceEnabled)
        }
    }

    func clearWallpaper() {
        isActive = false
        isPaused = false
        store.activeWallpaperID = nil

        for (_, entry) in wallpaperWindows {
            entry.playerView.cleanup()
        }
    }

    func togglePlayback() {
        if isPaused {
            resumeAll()
        } else {
            pauseAll()
        }
    }

    func pauseAll() {
        isPaused = true
        for (_, entry) in wallpaperWindows {
            entry.playerView.pause()
        }
    }

    func resumeAll() {
        guard isActive else { return }
        isPaused = false
        for (_, entry) in wallpaperWindows {
            entry.playerView.play()
        }
    }

    func resumeIfNeeded() {
        guard isActive, !isPaused else { return }
        resumeAll()
    }
    
    func updateFilters() {
        for (_, entry) in wallpaperWindows {
            entry.playerView.updateFilters()
        }
    }
    
    func reloadCurrentWallpaper() {
        guard let activeItem = store.activeWallpaper,
              let url = store.resolveBookmark(activeItem.url) else { return }
        
        for (_, entry) in wallpaperWindows {
            entry.playerView.loadVideo(url: url, isLooping: activeItem.isLooping, isMuted: activeItem.isMuted, isBounce: activeItem.isBounceEnabled)
        }
    }
}
