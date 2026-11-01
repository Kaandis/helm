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
        shake = ShakeDetector()
        timer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard NSEvent.pressedMouseButtons & 1 != 0 else {
            endCheck()
            onDrag?(nil)
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
        if Prefs.bool(Prefs.shakeToOpen) { shake.add(location.x, at: ProcessInfo.processInfo.systemUptime) }
        // A held key picks its wheel. Otherwise a shaken drag shows every
        // tool, and a wheel opened by a key stays open after the key is let go.
        let menu: Menu
        if let kind = WheelKind.held(NSEvent.modifierFlags) {
            menu = .wheel(kind)
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

/// Tells a deliberate side-to-side shake from an ordinary drag: three quick
/// turns, each after at least 40 points of travel, within a second.
struct ShakeDetector {
    private(set) var isShaken = false
    private var extreme: CGFloat?
    private var direction: CGFloat = 0
    private var turns: [TimeInterval] = []

    mutating func add(_ x: CGFloat, at time: TimeInterval) {
        guard !isShaken else { return }
        guard let last = extreme else { extreme = x; return }
        let travel = x - last
        if direction == 0 {
            if abs(travel) > 40 { direction = travel > 0 ? 1 : -1; extreme = x }
        } else if travel * direction > 0 {
            extreme = x
        } else if abs(travel) > 40 {
            direction = -direction
            extreme = x
            turns.append(time)
        }
        turns.removeAll { time - $0 > 1 }
        if turns.count >= 3 { isShaken = true }
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
