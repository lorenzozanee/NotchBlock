import Cocoa
import OSLog

/// Processes mouse events on the desktop pet window.
///
/// Handles click (with 0.3 s debounce), drag (3 pt threshold, direction
/// detection, edge clamping), hover (NSTrackingArea with scale + alpha
/// animation), and right-click context menu.
///
/// Mirrors `NotchTracker` for NSTrackingArea + debounce, `NotchPanelController`
/// for `show()` call pattern, and `OverlayWindowController` for logger + final
/// class conventions.
final class PetInteractionHandler {
    private let logger = Logger(subsystem: "com.notchblock.app", category: "PetInteraction")

    // MARK: - Callbacks

    /// Called on a debounced single click — consumer should call `NotchPanelController.show()`.
    var onClick: (() -> Void)?

    /// Called each drag frame with the new clamped position and detected direction.
    /// `direction` is nil when the drag is vertical-dominant.
    var onDragMoved: ((_ position: CGPoint, _ direction: PetState?) -> Void)?

    /// Called when the drag ends with the final clamped position.
    var onDragEnded: ((_ position: CGPoint) -> Void)?

    /// Called when the mouse enters the pet area (scale 1.1x + alpha 1.0).
    var onHoverEnter: (() -> Void)?

    /// Called when the mouse leaves the pet area (scale 1.0 + alpha 0.85).
    var onHoverExit: (() -> Void)?

    /// "Hide Pet" menu item selected.
    var onHidePet: (() -> Void)?

    /// "Switch Pet > …" menu item selected.
    var onSwitchPet: ((_ petID: String) -> Void)?

    /// "Pet Settings..." menu item selected.
    var onPetSettings: (() -> Void)?

    // MARK: - Constants

    static let dragThreshold: CGFloat = 3.0
    static let clickDebounce: TimeInterval = 0.3
    static let edgeMargin: CGFloat = 20.0
    static let hoverScale: CGFloat = 1.1
    static let exitAlpha: CGFloat = 0.85
    static let hoverAnimationDuration: TimeInterval = 0.2

    // MARK: - Internal State

    private var lastClickTime: Date?
    private var dragStartPoint: NSPoint?
    private var isDragging = false
    private var priorState: PetState = .idle
    private var currentScreen: NSScreen?

    // Weak back-reference to the interaction view for menu target wiring.
    private weak var interactionView: InteractionView?

    // MARK: - Public API

    /// Attach the interaction layer to a parent view.
    /// - Parameters:
    ///   - parentView: The container view (typically the NSPanel content view).
    ///   - frame: Initial frame for the interaction view (fills the pet render area).
    ///   - screen: The screen the pet window currently lives on (used for clamping).
    func attach(to parentView: NSView, frame: NSRect, screen: NSScreen?) {
        currentScreen = screen
        let view = InteractionView(frame: frame)
        view.handler = self
        parentView.addSubview(view)
        interactionView = view
    }

    /// Store the pet's state before a drag begins, so it can be restored on drag end.
    func setPriorState(_ state: PetState) {
        priorState = state
    }

    /// Read the state stored before the current drag.
    var priorDragState: PetState { priorState }

    /// Update the screen reference (call when the pet window moves to a different screen).
    func updateScreen(_ screen: NSScreen?) {
        currentScreen = screen
    }

    /// Force-reset debounce timer (useful after a drag operation resets click state).
    func resetDebounce() {
        lastClickTime = nil
    }

    // MARK: - Static Pure Logic (unit-testable)

    /// Returns true when the Euclidean distance between `start` and `current`
    /// meets or exceeds the drag threshold (3 pt).
    static func isDrag(from start: NSPoint, to current: NSPoint) -> Bool {
        let dx = current.x - start.x
        let dy = current.y - start.y
        return (dx * dx + dy * dy) >= (dragThreshold * dragThreshold)
    }

    /// Returns the horizontal drag direction, or nil when the drag is
    /// vertical-dominant or there is no horizontal bias.
    static func dragDirection(from start: NSPoint, to current: NSPoint) -> PetState? {
        let dx = current.x - start.x
        let dy = current.y - start.y
        guard abs(dx) > abs(dy) else { return nil }
        return dx < 0 ? .draggingLeft : .draggingRight
    }

    /// Clamp a point within the given screen frame, preserving `margin` pts
    /// from every edge.
    static func clampToScreen(_ point: NSPoint, screenFrame: CGRect, margin: CGFloat = edgeMargin) -> NSPoint {
        let minX = screenFrame.minX + margin
        let maxX = screenFrame.maxX - margin
        let minY = screenFrame.minY + margin
        let maxY = screenFrame.maxY - margin
        return NSPoint(
            x: min(max(point.x, minX), maxX),
            y: min(max(point.y, minY), maxY)
        )
    }

    // MARK: - Debounce (instance-level)

    /// Returns true if enough time has passed since the last click.
    func shouldAllowClick(now: Date = Date()) -> Bool {
        guard let last = lastClickTime else { return true }
        return now.timeIntervalSince(last) >= Self.clickDebounce
    }

    func recordClickTime(now: Date = Date()) {
        lastClickTime = now
    }

    // MARK: - Hover Effects

    func applyHoverEnter(to view: NSView) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Self.hoverAnimationDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view.animator().alphaValue = 1.0
        }
        view.layer?.add(scaleAnimation(from: 1.0, to: Self.hoverScale), forKey: "hoverEnter")
        onHoverEnter?()
    }

    func applyHoverExit(to view: NSView) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Self.hoverAnimationDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view.animator().alphaValue = Self.exitAlpha
        }
        view.layer?.add(scaleAnimation(from: Self.hoverScale, to: 1.0), forKey: "hoverExit")
        onHoverExit?()
    }

    private func scaleAnimation(from: CGFloat, to: CGFloat) -> CABasicAnimation {
        let anim = CABasicAnimation(keyPath: "transform.scale")
        anim.fromValue = from
        anim.toValue = to
        anim.duration = Self.hoverAnimationDuration
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        return anim
    }

    // MARK: - Context Menu

    func showContextMenu(at point: NSPoint, in view: NSView, availablePets: [String] = ["elysia"]) {
        let menu = NSMenu(title: "Pet")

        let hideItem = NSMenuItem(
            title: NSLocalizedString("Hide Pet", comment: ""),
            action: #selector(InteractionView.hidePetAction),
            keyEquivalent: ""
        )
        hideItem.target = interactionView
        menu.addItem(hideItem)

        let switchItem = NSMenuItem(
            title: NSLocalizedString("Switch Pet", comment: ""),
            action: nil,
            keyEquivalent: ""
        )
        let switchMenu = NSMenu(title: "Switch Pet")
        for petID in availablePets {
            let item = NSMenuItem(
                title: petID,
                action: #selector(InteractionView.switchPetAction(_:)),
                keyEquivalent: ""
            )
            item.target = interactionView
            item.representedObject = petID
            switchMenu.addItem(item)
        }
        switchItem.submenu = switchMenu
        menu.addItem(switchItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: NSLocalizedString("Pet Settings...", comment: ""),
            action: #selector(InteractionView.petSettingsAction),
            keyEquivalent: ""
        )
        settingsItem.target = interactionView
        menu.addItem(settingsItem)

        menu.popUp(positioning: nil, at: point, in: view)
    }

    // MARK: - Private clamp helper (uses instance screen reference)

    private func clampedScreenPoint(_ point: NSPoint) -> NSPoint {
        guard let screen = currentScreen ?? NSScreen.main else { return point }
        return Self.clampToScreen(point, screenFrame: screen.frame, margin: Self.edgeMargin)
    }

    // MARK: - Interaction View

    /// NSView subclass that overrides mouse events and delegates to the handler.
    /// Must be `final` so `@objc` selector dispatch is guaranteed.
    final class InteractionView: NSView {
        weak var handler: PetInteractionHandler?
        private var trackingArea: NSTrackingArea?

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
            setupTrackingArea()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func setupTrackingArea() {
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .enabledDuringMouseDrag],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            trackingArea = area
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let existing = trackingArea {
                removeTrackingArea(existing)
            }
            setupTrackingArea()
        }

        // MARK: - Mouse Events (single-finger drag, NOT gesture recognizer)

        override func mouseDown(with event: NSEvent) {
            guard let handler else { return }
            let point = convert(event.locationInWindow, from: nil)
            handler.dragStartPoint = point
            handler.isDragging = false
        }

        override func mouseDragged(with event: NSEvent) {
            guard let handler,
                  let start = handler.dragStartPoint,
                  let window = self.window
            else { return }

            let point = convert(event.locationInWindow, from: nil)

            // Guard: wait until movement exceeds 3 pt threshold before entering drag mode.
            if !handler.isDragging {
                guard PetInteractionHandler.isDrag(from: start, to: point) else { return }
                handler.isDragging = true
            }

            // Compute new window origin from the local delta.
            let deltaX = point.x - start.x
            let deltaY = point.y - start.y
            var newOrigin = window.frame.origin
            newOrigin.x += deltaX
            newOrigin.y += deltaY

            let clamped = handler.clampedScreenPoint(newOrigin)
            let direction = PetInteractionHandler.dragDirection(from: start, to: point)

            handler.onDragMoved?(clamped, direction)
        }

        override func mouseUp(with event: NSEvent) {
            guard let handler else { return }
            defer {
                handler.dragStartPoint = nil
                handler.isDragging = false
            }

            if handler.isDragging {
                // Drag ended — report final position.
                if let window = self.window {
                    let clamped = handler.clampedScreenPoint(window.frame.origin)
                    handler.onDragEnded?(clamped)
                }
                // Reset debounce so a drag-and-release doesn't block the next click.
                handler.recordClickTime()
            } else if handler.shouldAllowClick() {
                // Stationary click — debounce and fire.
                handler.recordClickTime()
                handler.onClick?()
            }
        }

        // MARK: - NSTrackingArea (hover)

        override func mouseEntered(with event: NSEvent) {
            handler?.applyHoverEnter(to: self)
        }

        override func mouseExited(with event: NSEvent) {
            handler?.applyHoverExit(to: self)
        }

        // MARK: - Right-Click (context menu)

        override func rightMouseDown(with event: NSEvent) {
            // Force-click suppression: only respond to explicit right-click,
            // not pressure / force-touch events.
            guard event.type != .pressure else { return }
            let point = convert(event.locationInWindow, from: nil)
            handler?.showContextMenu(at: point, in: self)
        }

        // MARK: - Menu Actions (target of NSMenu items)

        @objc func hidePetAction() {
            handler?.onHidePet?()
        }

        @objc func switchPetAction(_ sender: NSMenuItem) {
            guard let petID = sender.representedObject as? String else { return }
            handler?.onSwitchPet?(petID)
        }

        @objc func petSettingsAction() {
            handler?.onPetSettings?()
        }
    }
}
