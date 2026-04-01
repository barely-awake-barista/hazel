import AppKit
import AVFoundation
import CoreImage

class VideoPlayerView: NSView {
    private var player: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?
    private var currentURL: URL?
    private var currentIsLooping: Bool = true
    private var currentIsMuted: Bool = true
    private var currentIsBounce: Bool = false
    private var timeObserver: Any?

    var isPlaying: Bool {
        player?.rate ?? 0 != 0
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadVideo(url: URL, isLooping: Bool = true, isMuted: Bool = true, isBounce: Bool = false) {
        cleanup()
        currentURL = url
        currentIsLooping = isLooping
        currentIsMuted = isMuted
        currentIsBounce = isBounce

        var securityScoped = false
        if url.startAccessingSecurityScopedResource() {
            securityScoped = true
        }

        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 2.0
        playerItem.audioTimePitchAlgorithm = .varispeed
        
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        queuePlayer.automaticallyWaitsToMinimizeStalling = false
        let fit = SettingsManager.shared.wallpaperFit
        
        if isLooping && !isBounce {
            let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
            self.playerLooper = looper
        } else if isBounce {
            NotificationCenter.default.addObserver(self, selector: #selector(handleItemDidReachEnd), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            
            // EDGE DETECTOR (For reaching 0.0 while in reverse)
            timeObserver = queuePlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main) { [weak self] time in
                guard let self = self, let player = self.player, self.currentIsBounce else { return }
                if player.rate < 0 && time.seconds <= 0.02 {
                    player.rate = 1.0
                }
            }
        }

        let layer = AVPlayerLayer(player: queuePlayer)
        layer.videoGravity = fit.videoGravity
        layer.frame = bounds
        
        self.layer?.addSublayer(layer)
        self.player = queuePlayer
        self.playerLayer = layer
        queuePlayer.isMuted = isMuted

        if securityScoped {
            url.stopAccessingSecurityScopedResource()
        }

        refreshFilters()
        queuePlayer.play()
    }
    
    @objc private func handleItemDidReachEnd(notification: Notification) {
        guard let player = player, let item = player.currentItem else { return }
        
        if currentIsBounce {
            if item.canPlayReverse {
                let duration = item.duration
                let seekTime = CMTime(seconds: max(0, duration.seconds - 0.05), preferredTimescale: 600)
                
                player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                    self?.player?.rate = -1.0
                }
            } else {
                print("⚠️ Video codec does not support reverse playback for Bounce mode.")
                player.seek(to: .zero) { [weak self] _ in
                    self?.player?.rate = 1.0
                }
            }
        }
    }
    
    func refreshFilters() {
        guard let layer = playerLayer else { return }
        let settings = SettingsManager.shared
        
        var newFilters: [CIFilter] = []
        
        if settings.brightness != 0.0 || settings.saturation != 1.0 {
            if let colorFilter = CIFilter(name: "CIColorControls") {
                colorFilter.setValue(settings.brightness, forKey: kCIInputBrightnessKey)
                colorFilter.setValue(settings.saturation, forKey: kCIInputSaturationKey)
                newFilters.append(colorFilter)
            }
        }
        
        if settings.hue != 0.0 {
            if let hueFilter = CIFilter(name: "CIHueAdjust") {
                hueFilter.setValue(settings.hue, forKey: kCIInputAngleKey)
                newFilters.append(hueFilter)
            }
        }
        
        if settings.blur > 0 {
            if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                blurFilter.setValue(settings.blur * 10, forKey: kCIInputRadiusKey)
                newFilters.append(blurFilter)
            }
        }
        
        layer.filters = newFilters.isEmpty ? nil : newFilters
    }
    
    func updateFilters() {
        refreshFilters()
    }
    
    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
        currentIsMuted = muted
    }
    
    func reloadWithSettings() {
        guard let url = currentURL else { return }
        loadVideo(url: url, isLooping: currentIsLooping, isMuted: currentIsMuted, isBounce: currentIsBounce)
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func cleanup() {
        NotificationCenter.default.removeObserver(self)
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        playerLooper?.disableLooping()
        playerLooper = nil
        player = nil
        playerLayer = nil
        currentURL = nil
    }

    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
    }

    deinit {
        cleanup()
    }
}
