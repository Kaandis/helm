import HarborKit
import SwiftUI

/// The helm: a ring of tools around a hub, with handles past its rim and
/// the wheel keys below. A held key shows one wheel; a shake shows the big
/// helm with every tool that fits, grouped by wheel.
struct WheelView: View {
    let model: WheelModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var metrics: WheelMetrics { model.metrics }
    private var isFull: Bool { model.kind == nil }

    /// The wheel's centre in SwiftUI's top-left coordinates.
    private var center: CGPoint {
        CGPoint(x: metrics.panel.width / 2, y: metrics.panel.height - metrics.center.y)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ring
                .frame(width: (metrics.outer + WheelMetrics.handle) * 2, height: (metrics.outer + WheelMetrics.handle) * 2)
                .position(center)
            legend
                .position(x: center.x, y: center.y + metrics.outer + WheelMetrics.handle + 24)
        }
        .frame(width: metrics.panel.width, height: metrics.panel.height)
    }

    private var ring: some View {
        let count = model.tools.count
        let outer = metrics.outer, inner = metrics.inner
        return ZStack {
            // Handles past the rim, as on a ship's wheel: one between every
            // two tools, heavier where one wheel's tools give way to the next.
            ForEach(handles, id: \.self) { handle in
                Handle(angle: handle.angle, from: outer - 2, to: outer + WheelMetrics.handle - (handle.major ? 0 : 6))
                    .stroke(Theme.ink.opacity(0.88), style: StrokeStyle(lineWidth: handle.major ? 12 : 9, lineCap: .round))
            }

            // The ring itself: material with Harbor's warm tint.
            Annulus(inner: inner)
                .fill(.regularMaterial, style: FillStyle(eoFill: true))
                .overlay(Annulus(inner: inner).fill(Theme.surfaceTint, style: FillStyle(eoFill: true)))
                .frame(width: outer * 2, height: outer * 2)

            // On the big helm, every other wheel's tools sit a shade darker.
            if isFull {
                ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                    if index % 2 == 1 {
                        Arc(first: group.first, last: group.last, count: count, inner: inner + 2, outer: outer - 4)
                            .fill(Theme.ink.opacity(0.06))
                            .frame(width: outer * 2, height: outer * 2)
                    }
                }
            }

            if let hovered = model.hovered, count > 0 {
                Arc(first: hovered, last: hovered, count: count, inner: inner + 4, outer: outer - 7)
                    .fill(Theme.ink.opacity(0.1))
                    .frame(width: outer * 2, height: outer * 2)
                    .transition(.opacity)
            }

            // Spokes between the tools.
            ForEach(0..<count, id: \.self) { index in
                Handle(angle: Self.boundary(index, count), from: inner + 10, to: outer - 12)
                    .stroke(Theme.hairline, lineWidth: 1)
            }

            // The rim.
            Circle()
                .strokeBorder(Theme.ink.opacity(0.88), lineWidth: isFull ? 6 : 5)
                .frame(width: outer * 2, height: outer * 2)

            ForEach(Array(model.tools.enumerated()), id: \.offset) { index, tool in
                ToolLabel(tool: tool, highlighted: model.hovered == index, compact: isFull)
                    .offset(WheelView.offset(index: index, count: count, radius: (inner + outer) / 2 + (isFull ? 4 : 0)))
            }

            hub
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.2), radius: 22, y: 10)
        .animation(reduceMotion ? nil : .harborSelect, value: model.hovered)
    }

    private var hub: some View {
        VStack(spacing: 2) {
            if model.tools.isEmpty {
                Text("Nothing here")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
            } else {
                Text(model.files.count == 1 ? model.files[0].pathExtension.uppercased() : "\(model.files.count)")
                    .font(.system(size: isFull ? 19 : 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(model.kind?.title ?? String(localized: "All Tools"))
                    .font(.system(size: isFull ? 11.5 : 10.5, weight: .medium))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .frame(width: metrics.inner * 2, height: metrics.inner * 2)
        .background(Circle().fill(Theme.card))
        .overlay(Circle().strokeBorder(Theme.ink.opacity(0.88), lineWidth: isFull ? 6 : 5))
        .transaction { $0.animation = nil }
    }

    /// Which key opens which wheel: the open one, or on the big helm the
    /// one the pointer is over, stronger.
    private var legend: some View {
        KeyLegend(selected: model.kind ?? hoveredGroup)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Theme.card))
            .overlay(Capsule().strokeBorder(Theme.hairline))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
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
        // Too few tools to space handles by: four, like a plain wheel.
        guard count >= 3 else {
            return (0..<4).map { HandleSpot(angle: Double($0) * .pi / 2 - .pi / 4, major: false) }
        }
        // The last tool of each wheel, where the next wheel begins.
        // The big helm holds too many tools for a handle at every gap; it
        // gets eight, evenly round, like a real one, the top one heavier.
        if isFull {
            return (0..<8).map { HandleSpot(angle: Double($0) * .pi / 4 - .pi / 2, major: $0 == 0) }
        }
        return (0..<count).map { HandleSpot(angle: Self.boundary($0, count), major: false) }
    }

    /// The angle (radians, clockwise from the top) between tool `index`
    /// and the next.
    static func boundary(_ index: Int, _ count: Int) -> Double {
        (-90 + (Double(index) + 0.5) * 360 / Double(max(count, 1))) * .pi / 180
    }

    static func offset(index: Int, count: Int, radius: CGFloat) -> CGSize {
        let angle = Double(index) / Double(max(count, 1)) * 2 * .pi
        return CGSize(width: sin(angle) * radius, height: -cos(angle) * radius)
    }
}

/// Which key opens which wheel, the open one stronger.
private struct KeyLegend: View {
    let selected: WheelKind?

    var body: some View {
        HStack(spacing: 14) {
            ForEach(WheelKind.allCases, id: \.self) { kind in
                HStack(spacing: 5) {
                    Text(WheelKind.symbol(for: Prefs.string(kind.prefKey)))
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Theme.raised))
                        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Theme.hairline))
                    Text(kind.title)
                        .font(.system(size: 11.5, weight: kind == selected ? .semibold : .regular))
                }
                .foregroundStyle(kind == selected ? Theme.ink : Theme.ink2)
            }
        }
    }
}

private struct ToolLabel: View {
    let tool: Tool
    let highlighted: Bool
    var lines = 2
    var compact = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: tool.symbol)
                .font(.system(size: compact ? 16 : 18, weight: .medium))
                .frame(height: compact ? 19 : 22)
            Text(tool.title)
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
                .lineLimit(lines)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: lines > 1)
        }
        .frame(width: compact ? 66 : 76)
        .foregroundStyle(highlighted ? Theme.ink : Theme.ink2)
        .scaleEffect(highlighted ? 1.08 : 1)
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

    func path(in rect: CGRect) -> Path {
        var path = Path(ellipseIn: rect)
        path.addEllipse(in: rect.insetBy(dx: rect.width / 2 - inner, dy: rect.height / 2 - inner))
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
