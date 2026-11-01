import AppKit
import HarborKit
import Observation
import SwiftUI

/// What the wheel shows right now.
@MainActor
@Observable
final class WheelModel {
    var menu = DragWatcher.Menu.wheel(.convert)
    /// The helm's slices, clockwise from the top.
    var tools: [Tool] = []
    /// The big helm's groups (empty for one wheel).
    var sections: [(kind: WheelKind, tools: [Tool])] = []
    var files: [URL] = []
    var hovered: Int?

    /// The wheel on show; nil while every tool is.
    var kind: WheelKind? {
        if case .wheel(let kind) = menu { kind } else { nil }
    }

    /// Set when the helm opens, so drawing and hit-testing agree.
    var metrics = WheelMetrics.keyed
}

/// Geometry shared by the drawing and the drop target: the small helm a
/// key opens, or the big one a shake opens.
struct WheelMetrics {
    let outer: CGFloat
    let inner: CGFloat
    /// A rounded square instead of a circle.
    var square = false

    static let keyed = WheelMetrics(outer: 138, inner: 50)
    static let full = WheelMetrics(outer: 168, inner: 62)

    /// The small or big helm at the size and shape chosen in settings.
    static func chosen(full: Bool) -> WheelMetrics {
        let base = full ? Self.full : keyed
        let scale: CGFloat = switch Prefs.string(Prefs.helmSize) {
        case "small": 0.85
        case "large": 1.18
        default: 1
        }
        return WheelMetrics(outer: (base.outer * scale).rounded(), inner: (base.inner * scale).rounded(),
                            square: Prefs.string(Prefs.helmShape) == "square")
    }
    /// How far the handles reach past the rim.
    static let handle: CGFloat = 13
    /// Room around the helm for its shadow, and for the key legend below.
    static let room: CGFloat = 20, legend: CGFloat = 50

    var panel: CGSize {
        let side = (outer + Self.handle + Self.room) * 2
        return CGSize(width: side, height: side + Self.legend)
    }

    /// The helm's centre within the panel's content (y up, AppKit).
    var center: CGPoint { CGPoint(x: panel.width / 2, y: panel.height - outer - Self.handle - Self.room) }

    /// Which slice a point (content coordinates, y up) is over; nil over
    /// the hub, which cancels, or well outside the helm. A little past the
    /// rim still counts: a drop that lands just outside meant the slice.
    func slice(at point: CGPoint, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let dx = point.x - center.x, dy = point.y - center.y
        let distance = square ? max(abs(dx), abs(dy)) : hypot(dx, dy)
        guard distance > inner, distance < outer + Self.handle + Self.room else { return nil }
        // Clockwise from the top.
        var angle = atan2(dx, dy)
        if angle < 0 { angle += 2 * .pi }
        let width = 2 * .pi / CGFloat(count)
        return Int((angle + width / 2) / width) % count
    }
}

/// The wheel: a panel that appears under the pointer while files are
/// dragged, and takes the drop on one of its slices. After a shake it shows
/// the big helm of every tool instead.
@MainActor
final class WheelController {
    let model = WheelModel()
    var onRun: ((Tool, [URL]) -> Void)?

    private var panel: NSPanel?
    private var isShown = false
    private var anchor = CGPoint.zero

    func show(_ drag: DragWatcher.Drag) {
        let wasFull = model.kind == nil
        model.menu = drag.menu
        model.files = drag.files
        model.hovered = nil
        switch drag.menu {
        case .wheel(let kind):
            model.sections = []
            model.tools = Tool.tools(for: kind, files: drag.files)
        case .all:
            // Every tool that fits, or only the ones chosen in settings.
            let showsAll = Prefs.bool(Prefs.bigHelmShowsAll)
            let fitting = Tool.sections(for: drag.files).flatMap(\.tools)
            model.tools = Prefs.inBigHelmOrder(fitting.filter { showsAll || Prefs.bool(Prefs.bigHelm($0)) })
            model.sections = Tool.runs(model.tools)
        }
        model.metrics = .chosen(full: model.kind == nil)

        let panel = panel ?? makePanel()
        // Switching between the small and the big helm re-centres it on the
        // pointer; switching wheels keeps it where it is.
        guard !isShown || wasFull != (model.kind == nil) else { return }
        let metrics = model.metrics, size = metrics.panel
        let location = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(location) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        var origin = CGPoint(x: location.x - metrics.center.x, y: location.y - metrics.center.y)
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
        panel.contentView?.needsLayout = true
        isShown = true
        guard let content = panel.contentView else { return }
        panel.alphaValue = 1
        anchor = panel.convertPoint(fromScreen: location)
        PanelMotion.setHidden(content, anchor: anchor, hiddenScale: 0.9)
        panel.orderFrontRegardless()
        PanelMotion.animate(content, presented: true, anchor: anchor, hiddenScale: 0.9)
    }

    /// Builds the panel and draws it once, off screen, at launch, so the
    /// first drag doesn't wait for SwiftUI and the glass to warm up.
    func prepare() {
        let panel = panel ?? makePanel()
        model.menu = .all
        model.metrics = .chosen(full: true)
        panel.setFrame(CGRect(origin: CGPoint(x: -10_000, y: -10_000), size: model.metrics.panel), display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, !self.isShown else { return }
            panel.orderOut(nil)
            panel.alphaValue = 1
        }
    }

    func hide() {
        guard isShown, let panel, let content = panel.contentView else { return }
        isShown = false
        PanelMotion.animate(content, presented: false, anchor: anchor, hiddenScale: 0.9) { [weak self] in
            guard let self, !self.isShown else { return }
            panel.orderOut(nil)
        }
    }

    /// The tool under a point in the panel's content (y up), if any.
    fileprivate func index(at point: CGPoint) -> Int? {
        model.metrics.slice(at: point, count: model.tools.count)
    }

    fileprivate func dropped(on index: Int, files: [URL]) {
        guard model.tools.indices.contains(index) else { return }
        let tool = model.tools[index]
        hide()
        onRun?(tool, files)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: WheelMetrics.keyed.panel),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        // Left to itself, a clear window lets the pointer (and drags) fall
        // through wherever it draws nothing it counts as solid: the glass
        // and see-through ring included. Then a drag only registers over an
        // icon or a line. Said outright, the whole window takes them; the
        // drop view decides which parts mean anything.
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        let drop = WheelDropView(frame: CGRect(origin: .zero, size: WheelMetrics.keyed.panel))
        drop.controller = self
        let hosting = NSHostingView(rootView: WheelView(model: model))
        hosting.frame = drop.bounds
        hosting.autoresizingMask = [.width, .height]
        drop.addSubview(hosting)
        drop.wantsLayer = true
        panel.contentView = drop
        self.panel = panel
        return panel
    }
}

/// Takes the drop. SwiftUI draws the wheel; this view underneath knows
/// which slice the files are over and runs that tool when they land.
private final class WheelDropView: NSView {
    weak var controller: WheelController?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError() }

    // The SwiftUI drawing on top mustn't swallow the drag.
    override func hitTest(_ point: NSPoint) -> NSView? { self }

    /// A disc under the whole helm, all but invisible, so the window server
    /// sees something to hand the drag to everywhere the helm is.
    private let catcher = CAShapeLayer()

    override func layout() {
        super.layout()
        guard let layer, let metrics = MainActor.assumeIsolated({ controller?.model.metrics }) else { return }
        if catcher.superlayer == nil {
            catcher.fillColor = NSColor(white: 0, alpha: 0.012).cgColor
            layer.insertSublayer(catcher, at: 0)
        }
        let radius = metrics.outer + WheelMetrics.handle + WheelMetrics.room
        let rect = CGRect(x: metrics.center.x - radius, y: metrics.center.y - radius, width: radius * 2, height: radius * 2)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        catcher.frame = bounds
        catcher.path = metrics.square
            ? CGPath(roundedRect: rect, cornerWidth: radius * HelmRing.corner, cornerHeight: radius * HelmRing.corner, transform: nil)
            : CGPath(ellipseIn: rect, transform: nil)
        CATransaction.commit()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { update(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { update(sender) }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        MainActor.assumeIsolated { controller?.model.hovered = nil }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let point = convert(sender.draggingLocation, from: nil)
        let files = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                          options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return MainActor.assumeIsolated {
            guard let controller, let index = controller.index(at: point),
                  !files.isEmpty else { return false }
            controller.dropped(on: index, files: files)
            return true
        }
    }

    private func update(_ sender: NSDraggingInfo) -> NSDragOperation {
        let point = convert(sender.draggingLocation, from: nil)
        return MainActor.assumeIsolated {
            guard let controller else { return [] }
            let index = controller.index(at: point)
            if controller.model.hovered != index { controller.model.hovered = index }
            return index == nil ? [] : Self.operation(allowed: sender.draggingSourceOperationMask)
        }
    }

    /// Helm only reads the files, so any operation the source allows will
    /// do; holding ⌘ in Finder, for one, allows only a move.
    private static func operation(allowed: NSDragOperation) -> NSDragOperation {
        [NSDragOperation.copy, .generic, .move, .link].first { allowed.contains($0) } ?? []
    }
}
