import AppKit
import CoreGraphics

extension NSScreen {
    /// Returns the primary MacBook display with a hardware notch, if present.
    static var notched: NSScreen? {
        screens.first { $0.safeAreaInsets.top > 0 }
    }

    /// Core Graphics display identifier for Quartz coordinate queries.
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// Screen bounds in Quartz global coordinates (top-left origin) for matching `CGWindowListCopyWindowInfo`.
    var quartzBounds: CGRect? {
        displayID.map { CGDisplayBounds($0) }
    }

    /// Height of the top menu bar / hardware notch region in points.
    var topMenuBarHeight: CGFloat {
        let menuBarDelta = frame.maxY - visibleFrame.maxY
        return max(safeAreaInsets.top, menuBarDelta, 24)
    }
}
