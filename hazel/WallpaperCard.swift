import SwiftUI
import AppKit

struct WallpaperRow: View {
    let item: WallpaperItem
    let isSelected: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    let onToggleLoop: () -> Void
    let onToggleMute: () -> Void
    let onToggleBounce: () -> Void
    let onMirror: () -> Void
    let onShowInFinder: () -> Void

    @State private var thumbnailImage: NSImage?
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let image = thumbnailImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.primary.opacity(0.05))
                        .frame(width: 48, height: 28)
                        .overlay(
                            Image(systemName: "video.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Design.iconGradientDim)
                        )
                }
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                        .frame(width: 48, height: 28)
                }
                
                if item.isProcessing {
                    ZStack {
                        Color.black.opacity(0.6)
                        VStack(spacing: 4) {
                            ProgressView(value: item.processingProgress, total: 1.0)
                                .progressViewStyle(.linear)
                                .tint(Color.accentColor)
                                .scaleEffect(x: 0.8, y: 0.5)
                        }
                    }
                    .frame(width: 48, height: 28).clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .onTapGesture(perform: onTap)
            .contextMenu {
                Button("Show in Finder") { onShowInFinder() }
                Divider()
                Button("Bake Bounce (Mirror Video)") { onMirror() }
                Divider()
                Button("Remove", role: .destructive) { onRemove() }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(Design.geist(13))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if item.isLooping {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 9))
                            .help("Continuous Loop")
                    }
                    if item.isBounceEnabled {
                        Image(systemName: "infinity")
                            .font(.system(size: 9))
                            .help("Ping-Pong (Software Bounce)")
                    }
                    if item.isMirrored {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.accentColor)
                            .help("Baked Bounce (Mirrored File)")
                    }
                    if item.isMuted {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 9))
                            .help("Muted")
                    }
                }
                .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            if isHovered {
                HStack(spacing: 10) {
                    Button(action: onToggleMute) {
                        Image(systemName: item.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(item.isMuted ? "Unmute" : "Mute")
                    
                    Button(action: onToggleBounce) {
                        Image(systemName: "infinity")
                            .font(.system(size: 11))
                            .foregroundStyle(item.isBounceEnabled ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Ping-Pong (Bounce) Loop")
                    
                    Button(action: onToggleLoop) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 11))
                            .foregroundStyle(item.isLooping ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Continuous Loop")
                    
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Remove from Library")
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)
                    .help("Currently Active")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { hovering in
            withAnimation(.spring(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onAppear(perform: loadThumbnail)
    }

    private func loadThumbnail() {
        Task {
            guard let thumbnailPath = item.thumbnailPath else { return }
            let url = URL(fileURLWithPath: thumbnailPath)
            if let image = NSImage(contentsOf: url) {
                await MainActor.run {
                    self.thumbnailImage = image
                }
            }
        }
    }
}

