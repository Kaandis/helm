import AppKit
import HarborKit
import Observation
import SwiftUI

@MainActor
@Observable
final class ShelfModel {
    var files: [URL] = []
}

/// The Cut that Finder doesn't have. Files you cut wait on a small shelf in
/// the corner, untouched, until you drag the shelf into a folder (which moves
/// them there) or paste them in one with ⌥⌘V. Closing the shelf forgets them.
@MainActor
final class Shelf {
    let model = ShelfModel()
    /// How many files left their place since the last look.
    var onMoved: ((Int) -> Void)?

    private var panel: NSPanel?
    private var watch: Timer?
    static let size = CGSize(width: 150, height: 164)
    static let margin: CGFloat = 14

    func add(_ files: [URL]) {
        for file in files where !model.files.contains(file) { model.files.append(file) }
        // Also on the clipboard, so ⌥⌘V in Finder moves them.
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(model.files as [NSURL])
        present()
        startWatching()
    }

    func clear() {
        model.files = []
        dismiss()
    }

    /// Lets go of files that are no longer where they were cut from.
    func refresh() {
        let remaining = model.files.filter { FileManager.default.fileExists(atPath: $0.path) }
        let moved = model.files.count - remaining.count
        guard moved > 0 else { return }
        model.files = remaining
        onMoved?(moved)
        if remaining.isEmpty { dismiss() }
    }

    private func startWatching() {
        guard watch == nil else { return }
        // A pasted move happens in Finder; a glance a second is plenty.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        watch = timer
    }

    private var anchor: CGPoint { CGPoint(x: Self.size.width - Self.margin - 20, y: Self.size.height - Self.margin - 20) }

    private func present() {
        let panel = panel ?? makePanel()
        let frame = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        if !panel.isVisible {
            panel.setFrameOrigin(CGPoint(x: frame.maxX - Self.size.width - 6, y: frame.maxY - Self.size.height - 6))
            if let content = panel.contentView { PanelMotion.setHidden(content, anchor: anchor, hiddenScale: 0.85) }
        }
        panel.orderFrontRegardless()
        if let content = panel.contentView { PanelMotion.animate(content, presented: true, anchor: anchor, hiddenScale: 0.85) }
    }

    private func dismiss() {
        watch?.invalidate()
        watch = nil
        guard let panel, let content = panel.contentView else { return }
        PanelMotion.animate(content, presented: false, anchor: anchor, hiddenScale: 0.85) { [weak self] in
            guard self?.model.files.isEmpty == true else { return }
            panel.orderOut(nil)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: Self.size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = ShelfDragView(frame: CGRect(origin: .zero, size: Self.size))
        view.shelf = self
        let hosting = NSHostingView(rootView: ShelfView(model: model))
        hosting.frame = view.bounds
        hosting.autoresizingMask = [.width, .height]
        view.addSubview(hosting)
        view.wantsLayer = true
        panel.contentView = view
        self.panel = panel
        return panel
    }
}

/// Drags the files out as a move, takes more files dropped on it, and closes
/// from its corner button. SwiftUI only draws.
private final class ShelfDragView: NSView, NSDraggingSource {
    weak var shelf: Shelf?
    private var started = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.insetBy(dx: Shelf.margin, dy: Shelf.margin).contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// The close button, top right of the card (y up).
    private var closeRect: CGRect {
        CGRect(x: bounds.maxX - Shelf.margin - 30, y: bounds.maxY - Shelf.margin - 30, width: 30, height: 30)
    }

    override func mouseDown(with event: NSEvent) {
        started = false
    }

    override func mouseUp(with event: NSEvent) {
        guard !started, closeRect.contains(convert(event.locationInWindow, from: nil)) else { return }
        MainActor.assumeIsolated { shelf?.clear() }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !started, let files = MainActor.assumeIsolated({ shelf?.model.files }), !files.isEmpty else { return }
        started = true
        let point = convert(event.locationInWindow, from: nil)
        let items = files.enumerated().map { index, file in
            let item = NSDraggingItem(pasteboardWriter: file as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: file.path)
            let offset = CGFloat(min(index, 4)) * 4
            item.setDraggingFrame(CGRect(x: point.x - 24 + offset, y: point.y - 24 - offset, width: 48, height: 48), contents: icon)
            return item
        }
        beginDraggingSession(with: items, event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Out of the shelf is always a move: that's what cutting means.
        context == .outsideApplication ? .move : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        // Finder finishes the move a moment later.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.shelf?.refresh() }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        (sender.draggingSource as AnyObject?) === self ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let files = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                          options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard !files.isEmpty else { return false }
        MainActor.assumeIsolated { shelf?.add(files) }
        return true
    }
}

private struct ShelfView: View {
    let model: ShelfModel

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                ForEach(Array(model.files.prefix(3).enumerated().reversed()), id: \.element) { index, file in
                    Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                        .resizable()
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(Double(index) * 7))
                        .offset(x: CGFloat(index) * 5, y: CGFloat(index) * -2)
                }
            }
            .frame(height: 60)
            Text(model.files.count == 1 ? model.files[0].lastPathComponent : String(localized: "\(model.files.count) items"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .truncationMode(.middle)
            Text("Drag to a folder to move")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .frame(width: Shelf.size.width - Shelf.margin * 2, height: Shelf.size.height - Shelf.margin * 2, alignment: .top)
        .background(HarborSurface(cornerRadius: 20))
        .overlay(alignment: .topTrailing) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.ink2)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Theme.raised))
                .padding(7)
                .accessibilityLabel(Text("Close"))
        }
        .overlay(alignment: .topLeading) {
            Image(systemName: "scissors")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.ink3)
                .padding(10)
        }
        .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
        .frame(width: Shelf.size.width, height: Shelf.size.height)
    }
}
