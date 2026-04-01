import Foundation
import AVFoundation
import ServiceManagement

enum WallpaperFit: String, CaseIterable, Codable {
    case fill = "Fill"
    case fit = "Fit"
    case center = "Center"
    case stretch = "Stretch"
    
    var videoGravity: AVLayerVideoGravity {
        switch self {
        case .fill: return .resizeAspectFill
        case .fit: return .resizeAspect
        case .center: return .resizeAspect
        case .stretch: return .resize
        }
    }
}

@Observable
class SettingsManager {
    static let shared = SettingsManager()
    
    var wallpaperFit: WallpaperFit {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: "wallpaperFit"),
               let fit = WallpaperFit(rawValue: rawValue) {
                return fit
            }
            return .fill
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "wallpaperFit")
        }
    }
    
    var openOnStartup: Bool {
        get { UserDefaults.standard.bool(forKey: "openOnStartup") }
        set {
            UserDefaults.standard.set(newValue, forKey: "openOnStartup")
            updateLoginItem(enabled: newValue)
        }
    }
    
    var brightness: Double {
        get { UserDefaults.standard.object(forKey: "brightness") as? Double ?? 0.0 }
        set { UserDefaults.standard.set(newValue, forKey: "brightness") }
    }
    
    var saturation: Double {
        get { UserDefaults.standard.object(forKey: "saturation") as? Double ?? 1.0 }
        set { UserDefaults.standard.set(newValue, forKey: "saturation") }
    }
    
    var hue: Double {
        get { UserDefaults.standard.object(forKey: "hue") as? Double ?? 0.0 }
        set { UserDefaults.standard.set(newValue, forKey: "hue") }
    }
    
    var blur: Double {
        get { UserDefaults.standard.object(forKey: "blur") as? Double ?? 0.0 }
        set { UserDefaults.standard.set(newValue, forKey: "blur") }
    }
    
    private init() {
        _ = openOnStartup
    }
    
    private func updateLoginItem(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update login item: \(error)")
            }
        }
    }
}
