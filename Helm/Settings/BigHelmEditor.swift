import HarborKit
import SwiftUI
import UniformTypeIdentifiers

/// The big helm, laid out by hand: a live helm in the shape and look you
/// chose, and the tools that aren't on it as tiles below. Drag a tile onto
/// the helm where you want it, drag a tool round the helm to move it, drag
/// it off to take it away. A click on a tile adds it at the end.
struct BigHelmEditor: View {
    @AppStorage(Prefs.bigHelmShowsAll) private var showsAll = true
    @AppStorage(Prefs.helmShape) private var shape = "round"
    @AppStorage(Prefs.helmSize) private var size = "medium"
    @AppStorage(Prefs.panelStyle) private var style = "glass"
    @State private var model = WheelModel()
    /// The helm's tools, clockwise from the top.
    @State private var onHelm: [Tool] = []
    /// What's being dragged: from the helm, or a tile.
    @State private var dragging: Tool?

    /// The preview is drawn at the real size and scaled to fit.
    private let previewWidth: CGFloat = 420

    var body: some View {
        Form {
            Section {
                Picker("The big helm shows", selection: $showsAll) {
                    Text("Every tool that fits").tag(true)
                    Text("Only the tools I pick").tag(false)
                }
                .pickerStyle(.radioGroup)
                Text("Drag tiles onto the helm, round it to reorder, or off it to remove. Only tools that fit the files you drag ever show.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                helm
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }

            ForEach(WheelKind.allCases, id: \.self) { kind in
                let off = Tool.allCases.filter { $0.wheel == kind && !onHelm.contains($0) }
                if !off.isEmpty {
                    Section {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 78, maximum: 90), spacing: 8)], spacing: 8) {
                            ForEach(off, id: \.self) { tool in
                                ToolTile(tool: tool)
                                    .onDrag { dragging = tool; return provider(tool) }
                                    .onTapGesture { add(tool, at: onHelm.count) }
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityHint(Text("Adds it to the big helm"))
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Add from \(kind.title)")
                    }
                }
            }
        }
        .formStyle(.grouped)
        // Dropped anywhere off the helm, a tool from the helm comes off it.
        .onDrop(of: [.text], isTargeted: nil) { _ in
            if let tool = dragging, onHelm.contains(tool) { remove(tool) }
            dragging = nil
            return true
        }
        .onAppear(perform: load)
        .onChange(of: showsAll) { _, _ in load() }
        .onChange(of: shape) { _, _ in rebuild() }
        .onChange(of: size) { _, _ in rebuild() }
    }

    private var helm: some View {
        let metrics = model.metrics
        let scale = min(previewWidth / metrics.panel.width, 1)
        let center = CGPoint(x: metrics.panel.width / 2, y: metrics.panel.height - metrics.center.y)
        let count = onHelm.count
        return ZStack(alignment: .topLeading) {
            WheelView(model: model)
                .allowsHitTesting(false)
            // A grip over each tool, to pick it up.
            ForEach(Array(onHelm.enumerated()), id: \.element) { index, tool in
                let angle = Double(index) / Double(max(count, 1)) * 2 * .pi - .pi / 2
                let radius = (metrics.inner + metrics.outer) / 2
                Circle()
                    .fill(Color.clear)
                    .contentShape(Circle())
                    .frame(width: 38, height: 38)
                    .position(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                    .onDrag { dragging = tool; return provider(tool) }
                    .help(tool.longTitle)
                    .contextMenu { Button("Remove from Big Helm") { remove(tool) } }
                    .accessibilityLabel(Text(tool.longTitle))
            }
        }
        .frame(width: metrics.panel.width, height: metrics.panel.height)
        .onDrop(of: [.text], delegate: HelmDrop(center: center, metrics: metrics, count: count,
                                                 hovered: { model.hovered = $0 },
                                                 dropped: drop))
        .scaleEffect(scale)
        .frame(width: metrics.panel.width * scale, height: metrics.panel.height * scale)
    }

    private func provider(_ tool: Tool) -> NSItemProvider {
        NSItemProvider(object: tool.rawValue as NSString)
    }

    /// A drop on the helm at `angle` (radians clockwise from the top).
    private func drop(at angle: Double) {
        model.hovered = nil
        guard let tool = dragging else { return }
        dragging = nil
        var tools = onHelm
        tools.removeAll { $0 == tool }
        let slots = tools.count + 1
        let width = 2 * Double.pi / Double(slots)
        let index = Int((angle + width / 2) / width) % slots
        tools.insert(tool, at: index)
        save(tools)
    }

    private func add(_ tool: Tool, at index: Int) {
        var tools = onHelm
        tools.insert(tool, at: min(index, tools.count))
        save(tools)
    }

    private func remove(_ tool: Tool) {
        save(onHelm.filter { $0 != tool })
    }

    /// Writes the helm: its order, and a switch per tool (which Harbor shows
    /// too). Taking any tool off means you're picking.
    private func save(_ tools: [Tool]) {
        let defaults = UserDefaults.standard
        let rest = Prefs.inBigHelmOrder(Tool.allCases.filter { !tools.contains($0) })
        defaults.set((tools + rest).map(\.rawValue), forKey: Prefs.bigHelmOrder)
        for tool in Tool.allCases { defaults.set(tools.contains(tool), forKey: Prefs.bigHelm(tool)) }
        if tools.count < Tool.allCases.count { showsAll = false }
        withAnimation(.harborSelect) { onHelm = tools }
        rebuild()
    }

    private func load() {
        let all = Prefs.inBigHelmOrder(Tool.allCases)
        onHelm = showsAll ? all : all.filter { Prefs.bool(Prefs.bigHelm($0)) }
        rebuild()
    }

    private func rebuild() {
        model.menu = .all
        model.files = []
        model.tools = onHelm
        model.sections = Tool.runs(onHelm)
        // Roomier than the real one: it holds every tool you pick, not just
        // the ones that fit some files.
        let chosen = WheelMetrics.chosen(full: true)
        model.metrics = WheelMetrics(outer: (chosen.outer * 1.25).rounded(), inner: chosen.inner, square: chosen.square)
    }
}

/// Where a tool would land on the helm while it's dragged over it.
private struct HelmDrop: DropDelegate {
    let center: CGPoint
    let metrics: WheelMetrics
    let count: Int
    let hovered: (Int?) -> Void
    let dropped: (Double) -> Void

    private func angle(_ info: DropInfo) -> Double {
        var angle = atan2(info.location.x - center.x, center.y - info.location.y)
        if angle < 0 { angle += 2 * .pi }
        return angle
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let width = 2 * Double.pi / Double(max(count, 1))
        hovered(count > 0 ? Int((angle(info) + width / 2) / width) % count : nil)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) { hovered(nil) }

    func performDrop(info: DropInfo) -> Bool {
        dropped(angle(info))
        return true
    }
}

/// A tool waiting to go on the helm: a small square tile.
private struct ToolTile: View {
    let tool: Tool
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: tool.symbol)
                .font(.system(size: 17, weight: .medium))
                .frame(height: 20)
            Text(tool.wheel == .convert ? tool.longTitle : tool.title)
                .font(.system(size: 10, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(Theme.ink)
        .padding(6)
        .frame(width: 80, height: 70)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.raised))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(hovering ? Theme.ink.opacity(0.25) : Theme.hairline))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { hovering = $0 }
        .help(tool.longTitle)
    }
}
