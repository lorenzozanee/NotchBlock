import Foundation

// MARK: - PetPreferences

/// UserDefaults-backed persistence for all pet settings.
///
/// Six keys stored under the standard suite:
/// - `pet.enabled` (Bool, default `true`)
/// - `pet.selected` (String, default `"elysia"`)
/// - `pet.position.x` (Double, default 0 → resolved to screen bottom-right)
/// - `pet.position.y` (Double, default 0 → resolved to screen bottom-right)
/// - `pet.hideInFullscreen` (Bool, default `false`)
/// - `pet.idleSleepMinutes` (Int, default `5`)
struct PetPreferences {
    private let defaults: UserDefaults

    // MARK: - Keys

    private enum Key {
        static let enabled = "pet.enabled"
        static let selected = "pet.selected"
        static let positionX = "pet.position.x"
        static let positionY = "pet.position.y"
        static let hideInFullscreen = "pet.hideInFullscreen"
        static let idleSleepMinutes = "pet.idleSleepMinutes"
    }

    private enum Defaults {
        static let enabled = true
        static let selected = "elysia"
        static let hideInFullscreen = false
        static let idleSleepMinutes = 5
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Stored Properties

    var isEnabled: Bool {
        get {
            if defaults.object(forKey: Key.enabled) == nil { return Defaults.enabled }
            return defaults.bool(forKey: Key.enabled)
        }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    var selectedPet: String {
        get { defaults.string(forKey: Key.selected) ?? Defaults.selected }
        set { defaults.set(newValue, forKey: Key.selected) }
    }

    var positionX: Double {
        get { defaults.double(forKey: Key.positionX) }
        set { defaults.set(newValue, forKey: Key.positionX) }
    }

    var positionY: Double {
        get { defaults.double(forKey: Key.positionY) }
        set { defaults.set(newValue, forKey: Key.positionY) }
    }

    var hideInFullscreen: Bool {
        get {
            if defaults.object(forKey: Key.hideInFullscreen) == nil { return Defaults.hideInFullscreen }
            return defaults.bool(forKey: Key.hideInFullscreen)
        }
        set { defaults.set(newValue, forKey: Key.hideInFullscreen) }
    }

    var idleSleepMinutes: Int {
        get {
            if defaults.object(forKey: Key.idleSleepMinutes) == nil { return Defaults.idleSleepMinutes }
            return defaults.integer(forKey: Key.idleSleepMinutes)
        }
        set { defaults.set(newValue, forKey: Key.idleSleepMinutes) }
    }

    // MARK: - Position Helpers

    /// Default distance (in points) from the edge of the visible screen area.
    static let defaultEdgeMargin: CGFloat = 20

    /// Resolve the pet position, falling back to the bottom-right corner of `fallbackScreenFrame`
    /// when no position has been stored yet (both `x` and `y` are zero).
    func resolvedPosition(fallbackScreenFrame screenFrame: CGRect) -> CGPoint {
        let x = positionX
        let y = positionY
        if x == 0 && y == 0 {
            let m = Self.defaultEdgeMargin
            return CGPoint(x: screenFrame.maxX - m, y: screenFrame.maxY - m)
        }
        return CGPoint(x: x, y: y)
    }

    /// Clamp a point so it stays within `screenFrame` preserving `margin` points from every edge.
    func clampPosition(_ point: CGPoint, to screenFrame: CGRect, margin: CGFloat = defaultEdgeMargin) -> CGPoint {
        let minX = screenFrame.minX + margin
        let maxX = screenFrame.maxX - margin
        let minY = screenFrame.minY + margin
        let maxY = screenFrame.maxY - margin
        return CGPoint(
            x: min(max(point.x, minX), maxX),
            y: min(max(point.y, minY), maxY)
        )
    }

    /// Clear stored position so `resolvedPosition` uses the fallback again.
    mutating func resetPosition() {
        defaults.removeObject(forKey: Key.positionX)
        defaults.removeObject(forKey: Key.positionY)
    }

    /// Remove all pet-related keys from `UserDefaults` (useful for testing / reset).
    func removeAll() {
        for key in [Key.enabled, Key.selected, Key.positionX, Key.positionY,
                    Key.hideInFullscreen, Key.idleSleepMinutes] {
            defaults.removeObject(forKey: key)
        }
    }
}
