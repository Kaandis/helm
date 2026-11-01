import HarborKit
import SwiftUI

/// The helm: a ring of tools around a hub, a thin rim with handles past it,
/// and the wheel keys below. A held key shows one wheel with names; a shake
/// shows the big helm with every tool that fits, as icons, and the name of
/// the one under the pointer in the hub.
///
/// It reads the look from settings: cream or Liquid Glass, how see-through
/// the ring is, and the colour of the rim and handles.
struct WheelView: View {
    let model: WheelModel
    @AppStorage(Prefs.helmTransparency) private var transparency = 0.3

    var body: some View {
        Styled { HelmView(model: model, transparency: transparency) }
    }

    static func offset(index: Int, count: Int, radius: CGFloat) -> CGSize {
        let angle = Double(index) / Double(max(count, 1)) * 2 * .pi
        return CGSize(width: sin(angle) * radius, height: -cos(angle) * radius)
    }

    /// The angle (radians, clockwise from the top) between tool `index`
    /// and the next.
    static func boundary(_ index: Int, _ count: Int) -> Double {
        (-90 + (Double(index) + 0.5) * 360 / Double(max(count, 1))) * .pi / 180
    }
}

private struct HelmView: View {
    let model: WheelModel
    let transparency: Double
    @Environment(\.palette) private var palette
    @Environment(\.accent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var metrics: WheelMetrics { model.metrics }
    private var isFull: Bool { model.kind == nil }
    private var rim: Color { accent.color }

    /// The helm's centre in SwiftUI's top-left coordinates.
    private var center: CGPoint {
        CGPoint(x: metrics.panel.width / 2, y: metrics.panel.height - metrics.center.y)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ring
                .frame(width: (metrics.outer + WheelMetrics.handle) * 2, height: (metrics.outer + WheelMetrics.handle) * 2)
                .position(center)
            legend
                .position(x: center.x, y: center.y + metrics.outer + WheelMetrics.handle + 20)
        }
        .frame(width: metrics.panel.width, height: metrics.panel.height)
    }

    private var ring: some View {
        let count = model.tools.count
        let outer = metrics.outer, inner = metrics.inner
        return ZStack {
            // Handles past the rim, as on a ship's wheel.
            ForEach(handles, id: \.self) { handle in
                Handle(angle: handle.angle, from: outer, to: outer + WheelMetrics.handle - (handle.major ? 0 : 3))
                    .stroke(rim, style: StrokeStyle(lineWidth: handle.major ? 5 : 3.5, lineCap: .round))
            }

            HelmSurface(inner: inner, transparency: transparency)
                .frame(width: outer * 2, height: outer * 2)

            // On the big helm, every other wheel's tools sit a shade darker.
            if isFull {
                ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                    if index % 2 == 1 {
                        Arc(first: group.first, last: group.last, count: count, inner: inner + 1, outer: outer - 2)
                            .fill(palette.ink.opacity(0.05))
                            .frame(width: outer * 2, height: outer * 2)
                    }
                }
            }

            if let hovered = model.hovered, count > 0 {
                Arc(first: hovered, last: hovered, count: count, inner: inner + 4, outer: outer - 5)
                    .fill(rim.opacity(0.2))
                    .frame(width: outer * 2, height: outer * 2)
                    .transition(.opacity)
            }

            // Spokes between the tools.
            ForEach(0..<count, id: \.self) { index in
                Handle(angle: WheelView.boundary(index, count), from: inner + 10, to: outer - 10)
                    .stroke(palette.hairline, lineWidth: 1)
            }

            // The rim.
            Circle()
                .strokeBorder(rim, lineWidth: 2.5)
                .frame(width: outer * 2, height: outer * 2)

            ForEach(Array(model.tools.enumerated()), id: \.offset) { index, tool in
                ToolLabel(tool: tool, highlighted: model.hovered == index, iconOnly: isFull)
                    .offset(WheelView.offset(index: index, count: count, radius: (inner + outer) / 2 + (isFull ? 2 : 0)))
            }

            hub
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
        .animation(reduceMotion ? nil : .harborSelect, value: model.hovered)
    }

    private var hub: some View {
        let hovered = model.hovered.flatMap { model.tools.indices.contains($0) ? model.tools[$0] : nil }
        return VStack(spacing: 2) {
            if model.tools.isEmpty {
                Text("Nothing here")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(palette.ink2)
            } else if isFull, let hovered {
                // The big helm shows icons only; the hub names the one you're on.
                Text(hovered.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(hoveredGroup?.title ?? "")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(palette.ink3)
            } else {
                Text(model.files.count == 1 ? model.files[0].pathExtension.uppercased() : "\(model.files.count)")
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                Text(model.kind?.title ?? String(localized: "All Tools"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(palette.ink3)
            }
        }
        .padding(.horizontal, 8)
        .frame(width: metrics.inner * 2, height: metrics.inner * 2)
        .background(HubSurface())
        .overlay(Circle().strokeBorder(rim, lineWidth: 2.5))
    }

    /// Which key opens which wheel: the open one, or on the big helm the
    /// one the pointer is over, stronger.
    private var legend: some View {
        KeyLegend(selected: model.kind ?? hoveredGroup)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(HarborSurface(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
            .animation(reduceMotion ? nil : .harborSelect, value: hoveredGroup)
    }

    /// Each wheel's run of tools on the big helm.
    private var groups: [(kind: WheelKind, first: Int, last: Int)] {
        var start = 0
        return model.sections.map { section in
            defer { start += section.tools.count }
            return (section.kind, start, start + section.tools.count - 1)
        }
    }

    private var hoveredGroup: WheelKind? {
        guard let hovered = model.hovered else { return nil }
        return groups.first { (it) in (it.first...it.last).contains(hovered) }?.kind
    }

    private struct HandleSpot: Hashable {
        let angle: Double
        let major: Bool
    }

    private var handles: [HandleSpot] {
        let count = model.tools.count
        // The big helm holds too many tools for a handle at every gap; it
        // gets eight, evenly round, like a real one, the top one stronger.
        // So does a wheel with too few tools to space them by.
        if isFull || count < 3 {
            return (0..<8).map { HandleSpot(angle: Double($0) * .pi / 4 - .pi / 2, major: $0 == 0) }
        }
        return (0..<count).map { HandleSpot(angle: WheelView.boundary($0, count), major: false) }
    }
}

/// The hub stays readable whatever the ring's transparency: a solid card,
/// or a denser Liquid Glass.
private struct HubSurface: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if palette.isGlass, !reduceTransparency, #available(macOS 26, *) {
            Color.clear.glassEffect(.regular.tint(Theme.surfaceTint.opacity(0.55)), in: Circle())
        } else {
            Circle().fill(palette.isGlass ? Color(nsColor: .windowBackgroundColor) : Theme.card)
        }
    }
}

/// The ring's body: Liquid Glass, or system blur under a cream tint, as
/// see-through as the setting asks; solid when Reduce Transparency is on.
private struct HelmSurface: View {
    let inner: CGFloat
    let transparency: Double
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let ring = Annulus(inner: inner)
        if reduceTransparency {
            ring.fill(palette.isGlass ? Color(nsColor: .windowBackgroundColor) : Theme.background)
        } else if palette.isGlass, #available(macOS 26, *) {
            Color.clear
                .glassEffect(transparency > 0.5 ? .clear : .regular.tint(Theme.surfaceTint.opacity((1 - transparency) * 0.5)),
                             in: ring)
        } else {
            ring.fill(.regularMaterial)
                .overlay(ring.fill(Theme.background.opacity(1 - transparency)))
                .overlay(ring.stroke(palette.hairline, lineWidth: 1))
        }
    }
}

/// Which key opens which wheel, the open one stronger.
private struct KeyLegend: View {
    let selected: WheelKind?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 14) {
            ForEach(WheelKind.allCases, id: \.self) { kind in
                HStack(spacing: 5) {
                    Text(WheelKind.symbol(for: Prefs.string(kind.prefKey)))
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(palette.raised))
                        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(palette.hairline))
                    Text(kind.title)
                        .font(.system(size: 11.5, weight: kind == selected ? .semibold : .regular))
                }
                .foregroundStyle(kind == selected ? palette.ink : palette.ink2)
            }
        }
    }
}

private struct ToolLabel: View {
    let tool: Tool
    let highlighted: Bool
    var lines = 2
    var iconOnly = false
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: tool.symbol)
                .font(.system(size: iconOnly ? 17 : 17, weight: .medium))
                .frame(height: 21)
            if !iconOnly {
                Text(tool.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(lines)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: lines > 1)
            }
        }
        .frame(width: iconOnly ? 34 : 74)
        .foregroundStyle(highlighted ? palette.ink : palette.ink2)
        .scaleEffect(highlighted ? (iconOnly ? 1.18 : 1.08) : 1)
        .accessibilityLabel(Text(tool.title))
    }
}

extension WheelKind {
    var title: String {
        switch self {
        case .convert: String(localized: "Convert")
        case .tools: String(localized: "Tools")
        case .actions: String(localized: "Actions")
        }
    }
}

/// A ring: the full circle minus the hub (fill it even-odd).
private struct Annulus: Shape {
    let inner: CGFloat

    // Outer circle one way, hub the other, so the hub stays open under any
    // fill rule, Liquid Glass's included.
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addArc(center: center, radius: rect.width / 2, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        path.closeSubpath()
        path.addArc(center: center, radius: inner, startAngle: .degrees(360), endAngle: .zero, clockwise: true)
        path.closeSubpath()
        return path
    }
}

/// A run of slices, from tool `first` to tool `last`, centred on them.
private struct Arc: Shape {
    let first: Int
    let last: Int
    let count: Int
    let inner: CGFloat
    let outer: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let width = 360 / Double(max(count, 1))
        let start = Angle.degrees(-90 + (Double(first) - 0.5) * width + 1)
        let end = Angle.degrees(-90 + (Double(last) + 0.5) * width - 1)
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}

/// A straight line out from the centre at `angle`: a spoke, or a handle.
private struct Handle: Shape {
    let angle: Double
    let from: CGFloat
    let to: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: CGPoint(x: center.x + cos(angle) * from, y: center.y + sin(angle) * from))
        path.addLine(to: CGPoint(x: center.x + cos(angle) * to, y: center.y + sin(angle) * to))
        return path
    }
}
