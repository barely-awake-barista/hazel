import SwiftUI
import AppKit

@main
struct LiveWallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var store: WallpaperStore?
    private var controller: WallpaperController?
    private var managementWindowController: ManagementWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerFonts()
        
        let wallpaperStore = WallpaperStore()
        self.store = wallpaperStore

        let wallpaperController = WallpaperController(store: wallpaperStore)
        self.controller = wallpaperController

        if let activeItem = wallpaperStore.activeWallpaper {
            wallpaperController.setWallpaper(activeItem)
        }

        setupStatusItem()

        managementWindowController = ManagementWindowController()
    }
    
    private func registerFonts() {
        guard let fontURL = Bundle.main.url(forResource: "GeistPixel-Square", withExtension: "otf"),
              let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
              let font = CGFont(fontDataProvider) else {
            print("Failed to load custom font")
            return
        }
        
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterGraphicsFont(font, &error) {
            print("Custom font registered successfully")
        } else {
            print("Failed to register custom font: \(error?.takeRetainedValue().localizedDescription ?? "unknown error")")
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            if let image = NSImage(named: "Logo") {
                image.size = NSSize(width: 24, height: 24)
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "play.rectangle.fill", accessibilityDescription: "Hazel")
            }
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }
    
    private func togglePanel() {
        guard let store = store, let controller = controller, let button = statusItem?.button else { return }
        managementWindowController?.togglePanel(store: store, controller: controller, relativeTo: button)
    }

    private func showContextMenu() {
        let menu = NSMenu()
        
        let hazelItem = NSMenuItem(title: "Open Management", action: #selector(openManagement), keyEquivalent: "h")
        hazelItem.target = self
        menu.addItem(hazelItem)
        
        menu.addItem(NSMenuItem.separator())

        let fitMenu = NSMenu()
        for fit in WallpaperFit.allCases {
            let item = NSMenuItem(title: fit.rawValue, action: #selector(fitSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = fit
            item.state = (fit == SettingsManager.shared.wallpaperFit) ? .on : .off
            fitMenu.addItem(item)
        }
        
        let fitItem = NSMenuItem(title: "Wallpaper Fit", action: nil, keyEquivalent: "")
        fitItem.submenu = fitMenu
        menu.addItem(fitItem)

        let startupItem = NSMenuItem(title: "Open on Startup", action: #selector(toggleStartup(_:)), keyEquivalent: "")
        startupItem.target = self
        startupItem.state = SettingsManager.shared.openOnStartup ? .on : .off
        menu.addItem(startupItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Hazel", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Show menu and unhook
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        
        DispatchQueue.main.async {
            self.statusItem?.menu = nil
        }
    }

    @objc private func openManagement() {
        togglePanel()
    }

    @objc private func fitSelected(_ sender: NSMenuItem) {
        guard let fit = sender.representedObject as? WallpaperFit else { return }
        SettingsManager.shared.wallpaperFit = fit
        controller?.reloadCurrentWallpaper()
    }

    @objc private func toggleStartup(_ sender: NSMenuItem) {
        let newValue = !SettingsManager.shared.openOnStartup
        SettingsManager.shared.openOnStartup = newValue
        sender.state = newValue ? .on : .off
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.clearWallpaper()
    }
}
