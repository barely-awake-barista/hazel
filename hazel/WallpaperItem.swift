import Foundation

struct WallpaperItem: Codable, Identifiable, Equatable {
    var id: UUID
    var url: URL
    var title: String
    var thumbnailPath: String?
    var isLooping: Bool
    var isMuted: Bool
    var isBounceEnabled: Bool
    var isProcessing: Bool
    var isMirrored: Bool
    var processingProgress: Double

    init(id: UUID = UUID(), url: URL, title: String, thumbnailPath: String? = nil, 
         isLooping: Bool = true, isMuted: Bool = true, isBounceEnabled: Bool = false, 
         isProcessing: Bool = false, isMirrored: Bool = false, processingProgress: Double = 0.0) {
        self.id = id
        self.url = url
        self.title = title
        self.thumbnailPath = thumbnailPath
        self.isLooping = isLooping
        self.isMuted = isMuted
        self.isBounceEnabled = isBounceEnabled
        self.isProcessing = isProcessing
        self.isMirrored = isMirrored
        self.processingProgress = processingProgress
    }

    static func == (lhs: WallpaperItem, rhs: WallpaperItem) -> Bool {
        lhs.id == rhs.id
    }
}
