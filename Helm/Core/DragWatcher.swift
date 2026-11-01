import AppKit

/// Notices when files are being dragged anywhere on the Mac while one of the
/// wheel keys is held.
///
/// Nothing runs between drags. A mouse-down anywhere starts a short check
/// that lasts only while the button stays down; it watches the system's drag
/// pasteboard, which changes the moment a drag of files begins, and the
/// modifier keys. Reading those needs no permission.
@MainActor
final class DragWatcher {
    struct Drag: Equatable {
        let kind: WheelKind
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
    private var current: WheelKind?

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
        // The wheel stays open once shown; another key switches it.
        guard let kind = WheelKind.held(NSEvent.modifierFlags) else { return }
        guard kind != current else { return }
        current = kind
        onDrag?(Drag(kind: kind, files: files, location: NSEvent.mouseLocation))
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
