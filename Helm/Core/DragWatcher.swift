import AppKit

/// Notices when files are being dragged anywhere on the Mac while one of the
/// wheel keys is held, or when the drag is shaken.
///
/// Nothing runs between drags. A mouse-down anywhere starts a short check
/// that lasts only while the button stays down; it watches the system's drag
/// pasteboard, which changes the moment a drag of files begins, and the
/// modifier keys. Reading those needs no permission.
@MainActor
final class DragWatcher {
    /// What opens: every tool that fits (after a shake), or one wheel.
    enum Menu: Equatable {
        case all
        case wheel(WheelKind)
    }

    struct Drag: Equatable {
        let menu: Menu
        let files: [URL]
        /// Where the pointer is, in screen coordinates.
        let location: CGPoint
    }

    /// Called when a wheel should open or switch (with the drag), and when
    /// the button comes up (nil).
    var onDrag: ((Drag?) -> Void)?

    private var downMonitor: Any?
    private var timer: Timer?
    private var baseline = 0
    private var files: [URL]?
    private var current: Menu?
    private var shake = ShakeDetector()
    /// In toggle mode, the wheel a key press picked, until pressed again.
    private var toggled: WheelKind?
    private var lastHeld: WheelKind?
    /// Counts drags, so a late hide doesn't close the next drag's helm.
    private var generation = 0

    func start() {
        guard downMonitor == nil else { return }
        downMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseDown() }
        }
    }

    func stop() {
        if let downMonitor { NSEvent.removeMonitor(downMonitor) }
        downMonitor = nil
        endCheck()
    }

    private func mouseDown() {
        guard !Prefs.bool(Prefs.isPaused) else { return }
        baseline = NSPasteboard(name: .drag).changeCount
        files = nil
        current = nil
        toggled = nil
        lastHeld = nil
        generation += 1
        shake = ShakeDetector(sensitivity: Prefs.string(Prefs.shakeSensitivity))
        timer?.invalidate()
        // Sixty times a second while the button is down, so the helm opens
        // within a frame of the key or the shake.
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard NSEvent.pressedMouseButtons & 1 != 0 else {
            let wasOpen = current != nil
            endCheck()
            guard wasOpen else { return }
            // The drop reaches the helm a moment after the button comes up;
            // closing it at once could lose the drop. A drop closes it
            // itself; this only tidies up a drag let go elsewhere.
            let drag = generation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, self.generation == drag, self.current == nil else { return }
                self.onDrag?(nil)
            }
            return
        }
        let pasteboard = NSPasteboard(name: .drag)
        guard pasteboard.changeCount != baseline else { return }
        if files == nil {
            // Read once per drag: the files don't change while it lasts.
            let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
            files = urls ?? []
            if files?.isEmpty == false && !Self.isAllowedHere {
                files = []
            }
        }
        guard let files, !files.isEmpty else { return }
        let location = NSEvent.mouseLocation
        if Prefs.bool(Prefs.shakeToOpen) { shake.add(location, at: ProcessInfo.processInfo.systemUptime) }
        let held = WheelKind.held(NSEvent.modifierFlags)
        let menu: Menu
        if Prefs.string(Prefs.keyMode) == "toggle" {
            // A press picks a wheel and it stays; pressing it again goes back.
            if let held, held != lastHeld { toggled = toggled == held ? nil : held }
            lastHeld = held
            if let toggled {
                menu = .wheel(toggled)
            } else if shake.isShaken {
                menu = .all
            } else {
                // Pressed again before any shake: put the wheel away.
                if current != nil { current = nil; onDrag?(nil) }
                return
            }
        } else if let held {
            // A held key picks its wheel; let go, a shaken drag goes back to
            // every tool, and a wheel opened by a key alone stays open.
            menu = .wheel(held)
        } else if shake.isShaken {
            menu = .all
        } else if let current {
            menu = current
        } else {
            return
        }
        guard menu != current else { return }
        current = menu
        onDrag?(Drag(menu: menu, files: files, location: location))
    }

    private func endCheck() {
        timer?.invalidate()
        timer = nil
        files = nil
        current = nil
    }

    /// Not over an app you excluded, nor over one playing full screen.
    private static var isAllowedHere: Bool {
        guard let front = NSWorkspace.shared.frontmostApplication else { return true }
        if Prefs.excluded.contains(front.bundleIdentifier ?? "") { return false }
        if Prefs.bool(Prefs.skipFullScreen) && isFullScreen(front.processIdentifier) { return false }
        return true
    }

    /// Whether the app has a window covering a whole display, as full-screen
    /// apps and games do.
    private static func isFullScreen(_ pid: pid_t) -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return false }
        let screens = NSScreen.screens.map(\.frame.size)
        return windows.contains { window in
            guard window[kCGWindowOwnerPID as String] as? pid_t == pid,
                  window[kCGWindowLayer as String] as? Int == 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds) else { return false }
            return screens.contains { $0 == frame.size }
        }
    }
}

/// Tells a deliberate shake from an ordinary drag: there and back and
/// there again (left, right, left, or up, down, up), each leg long enough,
/// quickly. How long and how quick depends on the sensitivity setting.
struct ShakeDetector {
    private(set) var isShaken = false
    private var x: Axis
    private var y: Axis

    init(sensitivity: String = "normal") {
        let (travel, window): (CGFloat, TimeInterval) = switch sensitivity {
        case "low": (48, 0.7)
        case "high": (22, 1.1)
        default: (32, 0.9)
        }
        x = Axis(travel: travel, window: window)
        y = Axis(travel: travel, window: window)
    }

    mutating func add(_ point: CGPoint, at time: TimeInterval) {
        guard !isShaken else { return }
        if x.add(point.x, at: time) || y.add(point.y, at: time) { isShaken = true }
    }

    /// Turns along one axis; two in the window make a shake.
    private struct Axis {
        let travel: CGFloat
        let window: TimeInterval
        private var extreme: CGFloat?
        private var direction: CGFloat = 0
        private var turns: [TimeInterval] = []

        init(travel: CGFloat, window: TimeInterval) {
            self.travel = travel
            self.window = window
        }

        mutating func add(_ value: CGFloat, at time: TimeInterval) -> Bool {
            guard let last = extreme else { extreme = value; return false }
            let moved = value - last
            if direction == 0 {
                if abs(moved) > travel { direction = moved > 0 ? 1 : -1; extreme = value }
            } else if moved * direction > 0 {
                extreme = value
            } else if abs(moved) > travel {
                direction = -direction
                extreme = value
                turns.append(time)
            }
            turns.removeAll { time - $0 > window }
            return turns.count >= 2
        }
    }
}

/// The three wheels, each opened by holding its key while dragging.
enum WheelKind: String, CaseIterable, Sendable {
    case convert, tools, actions

    var prefKey: String {
        switch self {
        case .convert: Prefs.convertKey
        case .tools: Prefs.toolsKey
        case .actions: Prefs.actionsKey
        }
    }

    var modifier: NSEvent.ModifierFlags { Self.flags(for: Prefs.string(prefKey)) }

    static func flags(for name: String) -> NSEvent.ModifierFlags {
        switch name {
        case "command": .command
        case "control": .control
        case "option": .option
        default: .shift
        }
    }

    static func symbol(for name: String) -> String {
        switch name {
        case "command": "⌘"
        case "control": "⌃"
        case "option": "⌥"
        default: "⇧"
        }
    }

    /// The wheel whose key is held on its own; none if no wheel key, or
    /// more than one, is down.
    static func held(_ flags: NSEvent.ModifierFlags) -> WheelKind? {
        let relevant: NSEvent.ModifierFlags = [.shift, .command, .control, .option]
        let down = flags.intersection(relevant)
        return allCases.first { down == $0.modifier }
    }
}
