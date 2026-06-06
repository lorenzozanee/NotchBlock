import Cocoa
import ImageIO
import OSLog
import IOKit.ps

private let animationLogger = Logger(subsystem: "com.notchblock.app", category: "PetAnimation")

// MARK: - Power Source Detection

/// Detect whether the system is currently running on battery power.
/// Desktop Macs without a battery return false (treated as AC).
private func isOnBattery() -> Bool {
    guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
        return false
    }
    guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
        return false
    }
    for source in sources {
        guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let powerSource = info[kIOPSPowerSourceStateKey] as? String else {
            continue
        }
        if powerSource == kIOPSBatteryPowerValue {
            return true
        }
    }
    return false
}

// MARK: - PetAnimationPlayer

/// GIF rendering engine for the desktop pet.
///
/// Loads GIF files via CGImageSource, drives frame dispatch with CADisplayLink
/// (macOS 14+, main-thread-bound — eliminates CVDisplayLink data race and
/// use-after-free risks flagged in code review).
///
/// Handles 0.2s crossfade transitions between animations, throttles frame
/// rate on battery power, and enforces GIF dimension/frame-count limits.
///
/// All mutable state is accessed exclusively from the main thread via
/// `@MainActor` isolation and CADisplayLink's main-run-loop delivery.
@MainActor
final class PetAnimationPlayer: ObservableObject {

    // MARK: - Published State

    /// The current frame to display in the SwiftUI view.
    @Published var currentFrame: CGImage?

    /// Whether a crossfade transition is in progress.
    @Published var isCrossfading: Bool = false

    // MARK: - Constants

    /// Crossfade duration in seconds (matching the spec: 0.2s).
    private static let crossfadeDuration: TimeInterval = 0.2

    /// Maximum frame count allowed per GIF (DoS protection — security review finding).
    private static let maxFrameCount = 300

    /// Maximum GIF dimensions in pixels (DoS protection — security review finding).
    private static let maxDimension = 1024

    /// How often to re-sample the battery/idle state, in seconds.
    private static let batterySampleInterval: TimeInterval = 2.0

    // MARK: - Crossfade

    /// The animation currently fading out (nil when not crossfading).
    private var oldFrames: [CGImage] = []

    /// Progress of the current crossfade (0.0 to 1.0).
    private var crossfadeProgress: TimeInterval = 0

    /// The CGImage frames for the currently-active animation.
    private var currentFrames: [CGImage] = []

    // MARK: - Frame State

    /// Current frame index into currentFrames.
    private var frameIndex: Int = 0

    /// Current GIF loop iteration count (for finite-loop GIFs).
    private var completedLoops: Int = 0

    /// Total loop count from the GIF (0 = infinite).
    private var loopCount: Int = 0

    /// Accumulated time since the last frame advance, in seconds.
    private var accumulatedTime: TimeInterval = 0

    /// Duration of the current frame in seconds.
    private var currentFrameDuration: TimeInterval = 1.0 / 30.0

    // MARK: - Display Link (CADisplayLink — main-thread-bound)

    private var displayLink: CADisplayLink?

    /// Generation counter for race prevention during animation swaps.
    private var animationGeneration: Int = 0

    // MARK: - Battery / Idle

    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var onBattery: Bool = isOnBattery()
    private var lastBatterySampleTime: TimeInterval = 0
    private var cachedTargetFPS: Int? = nil

    /// Cached target FPS recomputed every N seconds to avoid hitting
    /// CGEventSource on every display-link callback.
    private var targetFPS: Int? {
        let now = CACurrentMediaTime()
        if now - lastBatterySampleTime < Self.batterySampleInterval {
            return cachedTargetFPS
        }
        lastBatterySampleTime = now
        guard onBattery else {
            cachedTargetFPS = nil
            return nil
        }
        let idleKey = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let idleMouse = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDown)
        let fps = min(idleKey, idleMouse) >= 30 ? 5 : 10
        cachedTargetFPS = fps
        return fps
    }

    /// Counts display link callbacks for frame-skip throttling on battery.
    private var callbackCounter: Int = 0

    // MARK: - Initialization

    init() {
        createDisplayLink()
        startPowerSourceMonitoring()
    }

    deinit {
        displayLink?.invalidate()
        if let source = powerSourceRunLoopSource {
            CFRunLoopRemoveSource(RunLoop.main.getCFRunLoop(), source, .commonModes)
        }
    }

    // MARK: - Public API

    /// Load a new GIF and begin playback. Triggers crossfade from the current animation.
    /// - Parameter gifURL: The file URL of the GIF to load.
    func loadAnimation(from gifURL: URL) {
        animationGeneration += 1
        let gen = animationGeneration

        guard let source = CGImageSourceCreateWithURL(gifURL as CFURL, nil) else {
            animationLogger.error("Failed to create CGImageSource from \(gifURL.path)")
            loadPlaceholderAnimation()
            return
        }

        guard CGImageSourceGetType(source) != nil else {
            animationLogger.error("Unrecognized image type at \(gifURL.path)")
            loadPlaceholderAnimation()
            return
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0, frameCount <= Self.maxFrameCount else {
            animationLogger.error("GIF frame count \(frameCount) out of acceptable range [1, \(Self.maxFrameCount)]")
            loadPlaceholderAnimation()
            return
        }

        // Dimension check on first frame (DoS protection)
        if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
           let width = props[kCGImagePropertyPixelWidth as String] as? Int,
           let height = props[kCGImagePropertyPixelHeight as String] as? Int {
            guard width <= Self.maxDimension && height <= Self.maxDimension else {
                animationLogger.error("GIF dimensions \(width)x\(height) exceed max \(Self.maxDimension)")
                loadPlaceholderAnimation()
                return
            }
        }

        // Extract frame durations and loop count from GIF properties
        var durations: [TimeInterval] = []
        var decodedFrames: [CGImage] = []
        var extractedLoopCount = 0

        let gifProperties = CGImageSourceCopyProperties(source, nil) as? [String: Any]
        if let gifDict = gifProperties?[kCGImagePropertyGIFDictionary as String] as? [String: Any],
           let loopValue = gifDict[kCGImagePropertyGIFLoopCount as String] as? Int {
            extractedLoopCount = loopValue
        }

        for i in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else {
                animationLogger.warning("Failed to decode frame \(i) of \(gifURL.path)")
                continue
            }
            decodedFrames.append(cgImage)

            let frameProperties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any]
            let gifFrameDict = frameProperties?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
            let delayTime = (gifFrameDict?[kCGImagePropertyGIFDelayTime as String] as? Double)
                ?? (gifFrameDict?[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double)
                ?? 0.1
            // GIF delay of 0 means 0.1s (browser convention)
            durations.append(delayTime > 0 ? delayTime : 0.1)
        }

        guard !decodedFrames.isEmpty else {
            animationLogger.error("No decodable frames in GIF: \(gifURL.path)")
            loadPlaceholderAnimation()
            return
        }

        // All work happens on @MainActor — no DispatchQueue.main.async needed.
        guard animationGeneration == gen else { return }

        // Save current frames as "old" for crossfade
        oldFrames = currentFrames
        currentFrames = decodedFrames
        loopCount = extractedLoopCount
        frameIndex = 0
        completedLoops = 0
        accumulatedTime = 0
        self.frameDurations = durations

        // Start crossfade if we had a previous animation
        if !oldFrames.isEmpty {
            beginCrossfade()
        } else {
            // First animation — display first frame immediately
            currentFrame = decodedFrames.first
        }

        animationLogger.debug("Loaded \(decodedFrames.count) frames from \(gifURL.lastPathComponent)")
    }

    /// Stop playback and release all frame data.
    func stop() {
        stopDisplayLink()
        frameIndex = 0
        completedLoops = 0
        accumulatedTime = 0
        var clearedOld = oldFrames
        var clearedCurrent = currentFrames
        var clearedDurations = frameDurations
        clearedOld.removeAll()
        clearedCurrent.removeAll()
        clearedDurations.removeAll()
        oldFrames = clearedOld
        currentFrames = clearedCurrent
        frameDurations = clearedDurations
        currentFrame = nil
    }

    // MARK: - CADisplayLink (main-thread-bound, no data race)

    private func createDisplayLink() {
        // CADisplayLink fires on the main run loop — eliminates the CVDisplayLink
        // data race, use-after-free risk, and deprecation flagged in code review.
        displayLink = NSScreen.main?.displayLink(target: self, selector: #selector(displayLinkFired))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkFired(_ link: CADisplayLink) {
        let delta = link.duration  // seconds per frame at current refresh rate
        accumulatedTime += delta

        // Battery-aware frame skip
        if let fps = targetFPS {
            callbackCounter += 1
            let sourceFPS = 30
            let skipInterval = max(1, sourceFPS / fps)
            if callbackCounter % skipInterval != 0 {
                return
            }
        }

        // Advance frames based on accumulated time
        let frameDurationsCopy = frameDurations
        var frameIndexCopy = frameIndex
        var completedLoopsCopy = completedLoops
        var currentFrameCopy: CGImage?

        let totalFrames = currentFrames.count
        guard totalFrames > 0 else { return }

        while accumulatedTime >= currentFrameDuration {
            accumulatedTime -= currentFrameDuration

            let nextIndex = frameIndexCopy + 1
            if nextIndex < totalFrames {
                frameIndexCopy = nextIndex
            } else {
                if loopCount == 0 {
                    frameIndexCopy = 0
                } else {
                    completedLoopsCopy += 1
                    if completedLoopsCopy >= loopCount {
                        frameIndexCopy = totalFrames - 1
                        accumulatedTime = 0
                        break
                    }
                    frameIndexCopy = 0
                }
            }

            if frameIndexCopy < frameDurationsCopy.count {
                currentFrameDuration = frameDurationsCopy[frameIndexCopy]
            }
        }

        if frameIndexCopy < currentFrames.count {
            currentFrameCopy = currentFrames[frameIndexCopy]
        }

        // Copy-then-assign back (immutable pattern)
        frameIndex = frameIndexCopy
        completedLoops = completedLoopsCopy
        frameDurations = frameDurationsCopy

        if let frame = currentFrameCopy {
            currentFrame = frame
        }
    }

    // MARK: - Crossfade

    private var crossfadeTimer: Timer?
    private var crossfadeGen: Int = 0

    private func beginCrossfade() {
        crossfadeTimer?.invalidate()
        crossfadeGen += 1
        let gen = crossfadeGen

        crossfadeProgress = 0
        isCrossfading = true
        currentFrame = currentFrames.first

        let stepInterval = Self.crossfadeDuration / 10.0 // 10 steps for smooth fade
        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            guard let self, self.crossfadeGen == gen else {
                timer.invalidate()
                return
            }
            self.crossfadeProgress += stepInterval
            if self.crossfadeProgress >= Self.crossfadeDuration {
                self.completeCrossfade()
                timer.invalidate()
            }
        }
        RunLoop.main.add(crossfadeTimer!, forMode: .common)
    }

    private func completeCrossfade() {
        isCrossfading = false
        crossfadeProgress = 0
        var cleared = oldFrames
        cleared.removeAll()
        oldFrames = cleared
    }

    // MARK: - Placeholder

    /// Generate a fallback placeholder image when GIF loading fails.
    /// Uses block-based NSImage drawing (non-deprecated, macOS 14+ compatible).
    private func loadPlaceholderAnimation() {
        let size = NSSize(width: 120, height: 120)
        let placeholderImage = NSImage(size: size, flipped: false) { rect in
            NSColor.systemGray.withAlphaComponent(0.3).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 48, weight: .light),
                .foregroundColor: NSColor.systemGray,
                .paragraphStyle: paragraphStyle
            ]
            "?".draw(in: NSRect(x: 0, y: rect.height / 2 - 24, width: rect.width, height: 48),
                     withAttributes: attrs)
            return true
        }

        guard let cgImage = placeholderImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            animationLogger.error("Failed to create placeholder CGImage")
            currentFrame = nil
            return
        }

        let updated = [cgImage]
        oldFrames = currentFrames
        currentFrames = updated
        frameIndex = 0
        completedLoops = 0
        loopCount = 0
        accumulatedTime = 0
        let durations = [TimeInterval](repeating: 1.0, count: 1)
        frameDurations = durations
        currentFrame = cgImage

        if !oldFrames.isEmpty {
            beginCrossfade()
        }

        animationLogger.warning("Using placeholder animation")
    }

    // MARK: - Power Source Monitoring

    private func startPowerSourceMonitoring() {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource(petPowerSourceCallback, selfPtr)?.takeRetainedValue()

        if let source = source {
            powerSourceRunLoopSource = source
            CFRunLoopAddSource(RunLoop.main.getCFRunLoop(), source, .commonModes)
        }
    }

    private func stopPowerSourceMonitoring() {
        if let source = powerSourceRunLoopSource {
            CFRunLoopRemoveSource(RunLoop.main.getCFRunLoop(), source, .commonModes)
            powerSourceRunLoopSource = nil
        }
    }

    fileprivate func handlePowerSourceChange() {
        // Runs on main thread via CFRunLoop. @MainActor ensures safe access.
        onBattery = isOnBattery()
        callbackCounter = 0
        lastBatterySampleTime = 0
        cachedTargetFPS = nil
        animationLogger.debug("Power source changed: battery=\(self.onBattery)")
    }

    // MARK: - Frame Durations

    /// Per-frame display durations extracted from the GIF metadata.
    private var frameDurations: [TimeInterval] = []
}

// MARK: - Power Source Callback (C function — safe: source removed in deinit before deallocation)

private func petPowerSourceCallback(context: UnsafeMutableRawPointer?) {
    guard let context = context else { return }
    let player = Unmanaged<PetAnimationPlayer>.fromOpaque(context).takeUnretainedValue()
    Task { @MainActor in
        player.handlePowerSourceChange()
    }
}
