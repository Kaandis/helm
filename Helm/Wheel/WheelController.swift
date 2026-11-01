import AppKit
import HarborKit
import Observation
import SwiftUI

/// What the wheel shows right now.
@MainActor
@Observable
final class WheelModel {
    var kind = WheelKind.convert
    var tools: [Tool] = []
    var files: [URL] = []
    var hovered: Int?
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

/// The wheel: a panel that appears under the pointer while files are
/// dragged, and takes the drop on one of its slices.
@MainActor
final class WheelController {
    let model = WheelModel()
    var onRun: ((Tool, [URL]) -> Void)?

    private var panel: NSPanel?
    private var isShown = false

    func show(_ drag: DragWatcher.Drag) {
        let tools = Tool.tools(for: drag.kind, files: drag.files)
        model.kind = drag.kind
        model.tools = tools
        model.files = drag.files
        model.hovered = nil

        let panel = panel ?? makePanel()
        if !isShown {
            // Centred on the pointer, kept on the screen it's on.
            let screen = NSScreen.screens.first { $0.frame.contains(drag.location) } ?? NSScreen.main
            var origin = CGPoint(x: drag.location.x - WheelMetrics.center.x, y: drag.location.y - WheelMetrics.center.y)
            if let frame = screen?.visibleFrame {
                origin.x = min(max(origin.x, frame.minX), frame.maxX - WheelMetrics.panel.width)
                origin.y = min(max(origin.y, frame.minY), frame.maxY - WheelMetrics.panel.height)
            }
            panel.setFrameOrigin(origin)
            isShown = true
            if let content = panel.contentView {
                let anchor = panel.convertPoint(fromScreen: drag.location)
                PanelMotion.setHidden(content, anchor: anchor, hiddenScale: 0.8)
                panel.orderFrontRegardless()
                PanelMotion.animate(content, presented: true, anchor: anchor, hiddenScale: 0.8)
            }
        }
    }

    func hide() {
        guard isShown, let panel, let content = panel.contentView else { return }
        isShown = false
        let anchor = CGPoint(x: WheelMetrics.center.x, y: WheelMetrics.center.y)
        PanelMotion.animate(content, presented: false, anchor: anchor, hiddenScale: 0.9) { [weak self] in
            guard let self, !self.isShown else { return }
            panel.orderOut(nil)
        }
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
            guard let controller, let index = WheelMetrics.slice(at: point, count: controller.model.tools.count),
                  !files.isEmpty else { return false }
            controller.dropped(on: index, files: files)
            return true
        }
    }

    private func update(_ sender: NSDraggingInfo) -> NSDragOperation {
        let point = convert(sender.draggingLocation, from: nil)
        return MainActor.assumeIsolated {
            guard let controller else { return [] }
            let index = WheelMetrics.slice(at: point, count: controller.model.tools.count)
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
