import AppKit
import HarborKit
import Observation
import SwiftUI

/// A small pill under the menu bar while a tool runs, then what came of it.
@MainActor
@Observable
final class ToastModel {
    enum Phase: Equatable {
        case working(Double)
        case done(String?)
        case failed(String)
    }

    var title = ""
    var symbol = "gearshape"
    var phase = Phase.working(0)
    var outputs: [URL] = []
}

@MainActor
final class Toast {
    let model = ToastModel()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    private static let size = CGSize(width: 360, height: 76)

    func start(_ tool: Tool) {
        hideWork?.cancel()
        model.title = tool.title
        model.symbol = tool.symbol
        model.phase = .working(0)
        model.outputs = []
        present()
    }

    func progress(_ fraction: Double) {
        if case .working = model.phase { model.phase = .working(fraction) }
    }

    func finish(_ outcome: ToolRunner.Outcome) {
        model.outputs = outcome.outputs
        model.phase = .done(outcome.message)
        dismiss(after: outcome.message == nil ? 3.5 : 6)
    }

    func fail(_ error: Error) {
        model.phase = .failed(error.localizedDescription)
        dismiss(after: 6)
    }

    func revealOutputs() {
        guard !model.outputs.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(model.outputs)
        dismiss(after: 0)
    }

    private func present() {
        let panel = panel ?? makePanel()
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.visibleFrame
        panel.setFrameOrigin(CGPoint(x: frame.midX - Self.size.width / 2, y: frame.maxY - Self.size.height - 8))
        guard let content = panel.contentView else { return }
        let anchor = CGPoint(x: Self.size.width / 2, y: Self.size.height)
        if !panel.isVisible { PanelMotion.setHidden(content, anchor: anchor, hiddenScale: 0.92, offset: CGSize(width: 0, height: 8)) }
        panel.orderFrontRegardless()
        PanelMotion.animate(content, presented: true, anchor: anchor, hiddenScale: 0.92, offset: CGSize(width: 0, height: 8))
    }

    private func dismiss(after delay: TimeInterval) {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let panel = self.panel, let content = panel.contentView else { return }
            let anchor = CGPoint(x: Self.size.width / 2, y: Self.size.height)
            PanelMotion.animate(content, presented: false, anchor: anchor, hiddenScale: 0.92,
                                offset: CGSize(width: 0, height: 8)) { [weak self] in
                guard self?.hideWork == nil || self?.hideWork?.isCancelled == false else { return }
                panel.orderOut(nil)
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: Self.size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        let host = NSHostingView(rootView: Styled { ToastView(model: model, reveal: { [weak self] in self?.revealOutputs() }) })
        host.frame = CGRect(origin: .zero, size: Self.size)
        host.wantsLayer = true
        panel.contentView = host
        self.panel = panel
        return panel
    }
}

private struct ToastView: View {
    let model: ToastModel
    let reveal: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.raised))
            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                detail
            }
            Spacer(minLength: 8)
            if case .done = model.phase, !model.outputs.isEmpty {
                Button("Show") { reveal() }
                    .buttonStyle(HarborButtonStyle(prominent: false))
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .frame(width: 344, height: 60)
        .background(HarborSurface(cornerRadius: 18))
        .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
        .frame(width: 360, height: 76)
        .animation(reduceMotion ? nil : .harborSelect, value: model.phase)
    }

    private var icon: String {
        switch model.phase {
        case .working: model.symbol
        case .done: "checkmark"
        case .failed: "exclamationmark.triangle"
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.phase {
        case .working(let fraction):
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(Theme.ink)
                .frame(width: 200)
        case .done(let message):
            Text(message ?? doneText)
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink2)
                .lineLimit(2)
        case .failed(let message):
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink2)
                .lineLimit(2)
        }
    }

    private var doneText: String {
        switch model.outputs.count {
        case 0: String(localized: "Done")
        case 1: model.outputs[0].lastPathComponent
        default: String(localized: "\(model.outputs.count) files")
        }
    }
}
