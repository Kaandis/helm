import AppKit
import HarborKit
import Observation
import SwiftUI

/// What the wheel shows right now.
@MainActor
@Observable
final class WheelModel {
    var menu = DragWatcher.Menu.wheel(.convert)
    /// Wheel slices, or palette tiles in reading order.
    var tools: [Tool] = []
    /// The palette's groups (empty for a wheel).
    var sections: [(kind: WheelKind, tools: [Tool])] = []
    var palette = PaletteMetrics.Layout()
    var files: [URL] = []
    var hovered: Int?

    /// The wheel on show; nil while every tool is.
    var kind: WheelKind? {
        if case .wheel(let kind) = menu { kind } else { nil }
    }
}

/// Geometry shared by the drawing and the drop target.
enum WheelMetrics {
    static let outer: CGFloat = 150
    static let inner: CGFloat = 54
    /// Room around the wheel for its shadow and the key legend below.
    static let panel = CGSize(width: 380, height: 430)
    /// The wheel's centre within the panel's content (y up, AppKit).
    static let center = CGPoint(x: panel.width / 2, y: panel.height - 190)

    /// Which slice a point (content coordinates, y up) is over; nil over
    /// the hub, which cancels, or outside the wheel.
    static func slice(at point: CGPoint, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let dx = point.x - center.x, dy = point.y - center.y
        let distance = hypot(dx, dy)
        guard distance > inner, distance < outer + 24 else { return nil }
        // Clockwise from the top.
        var angle = atan2(dx, dy)
        if angle < 0 { angle += 2 * .pi }
        let width = 2 * .pi / CGFloat(count)
        return Int((angle + width / 2) / width) % count
    }
}

/// The palette a shaken drag opens: every tool that fits, grouped by wheel.
/// Coordinates are top-left, in the panel's content, which leaves `margin`
/// around the card for its shadow.
enum PaletteMetrics {
    static let tile = CGSize(width: 88, height: 74)
    static let gap: CGFloat = 6
    static let padding: CGFloat = 14
    static let header: CGFloat = 26
    static let footer: CGFloat = 34
    static let margin: CGFloat = 24
    /// How far above (or below) the pointer the card sits, so letting go
    /// where the palette opened cancels.
    static let clearance: CGFloat = 18

    struct Layout {
        var size = CGSize(width: 1, height: 1)
        var tiles: [CGRect] = []
        var headers: [CGPoint] = []
        var card: CGRect { CGRect(origin: .zero, size: size).insetBy(dx: margin, dy: margin) }
    }

    static func layout(_ sections: [(kind: WheelKind, tools: [Tool])]) -> Layout {
        let columns = min(7, max(3, sections.map(\.tools.count).max() ?? 3))
        let width = padding * 2 + CGFloat(columns) * tile.width + CGFloat(columns - 1) * gap
        var layout = Layout()
        var y = margin + padding
        for section in sections {
            layout.headers.append(CGPoint(x: margin + padding + 4, y: y))
            y += header
            for index in section.tools.indices {
                let column = CGFloat(index % columns), row = CGFloat(index / columns)
                layout.tiles.append(CGRect(x: margin + padding + column * (tile.width + gap),
                                           y: y + row * (tile.height + gap), width: tile.width, height: tile.height))
            }
            let rows = CGFloat((section.tools.count + columns - 1) / columns)
            y += rows * tile.height + (rows - 1) * gap + 10
        }
        layout.size = CGSize(width: width + margin * 2, height: y - 10 + footer + padding + margin)
        return layout
    }

    static func tile(at point: CGPoint, in layout: Layout) -> Int? {
        layout.tiles.firstIndex { $0.insetBy(dx: -gap / 2, dy: -gap / 2).contains(point) }
    }
}

/// The wheel: a panel that appears under the pointer while files are
/// dragged, and takes the drop on one of its slices. After a shake it shows
/// the palette of every tool instead.
@MainActor
final class WheelController {
    let model = WheelModel()
    var onRun: ((Tool, [URL]) -> Void)?

    private var panel: NSPanel?
    private var isShown = false
    private var anchor = CGPoint.zero

    func show(_ drag: DragWatcher.Drag) {
        let wasPalette = model.kind == nil
        model.menu = drag.menu
        model.files = drag.files
        model.hovered = nil
        let size: CGSize
        switch drag.menu {
        case .wheel(let kind):
            model.sections = []
            model.tools = Tool.tools(for: kind, files: drag.files)
            size = WheelMetrics.panel
        case .all:
            model.sections = Tool.sections(for: drag.files)
            model.tools = model.sections.flatMap(\.tools)
            model.palette = PaletteMetrics.layout(model.sections)
            size = model.palette.size
        }

        let panel = panel ?? makePanel()
        // Switching between a wheel and the palette re-seats the panel
        // around the pointer; switching wheels keeps it where it is.
        guard !isShown || wasPalette != (model.kind == nil) else { return }
        let location = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(location) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        var origin: CGPoint
        if model.kind != nil {
            // Centred on the pointer.
            origin = CGPoint(x: location.x - WheelMetrics.center.x, y: location.y - WheelMetrics.center.y)
        } else {
            // Above the pointer, or below it when there's no room.
            let margin = PaletteMetrics.margin, clearance = PaletteMetrics.clearance
            origin = CGPoint(x: location.x - size.width / 2, y: location.y + clearance - margin)
            if origin.y + size.height > visible.maxY {
                origin.y = location.y - clearance + margin - size.height
            }
        }
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
        isShown = true
        guard let content = panel.contentView else { return }
        anchor = panel.convertPoint(fromScreen: location)
        PanelMotion.setHidden(content, anchor: anchor, hiddenScale: 0.8)
        panel.orderFrontRegardless()
        PanelMotion.animate(content, presented: true, anchor: anchor, hiddenScale: 0.8)
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
    fileprivate func index(at point: CGPoint, height: CGFloat) -> Int? {
        if model.kind != nil { return WheelMetrics.slice(at: point, count: model.tools.count) }
        return PaletteMetrics.tile(at: CGPoint(x: point.x, y: height - point.y), in: model.palette)
    }

    fileprivate func dropped(on index: Int, files: [URL]) {
        guard model.tools.indices.contains(index) else { return }
        let tool = model.tools[index]
        hide()
        onRun?(tool, files)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: WheelMetrics.panel),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        let drop = WheelDropView(frame: CGRect(origin: .zero, size: WheelMetrics.panel))
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
            guard let controller, let index = controller.index(at: point, height: self.bounds.height),
                  !files.isEmpty else { return false }
            controller.dropped(on: index, files: files)
            return true
        }
    }

    private func update(_ sender: NSDraggingInfo) -> NSDragOperation {
        let point = convert(sender.draggingLocation, from: nil)
        return MainActor.assumeIsolated {
            guard let controller else { return [] }
            let index = controller.index(at: point, height: self.bounds.height)
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
