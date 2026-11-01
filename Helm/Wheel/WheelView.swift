import HarborKit
import SwiftUI

/// The helm: a ring of tools around a hub, with the wheel keys below; or,
/// after a shake, the palette of every tool.
struct WheelView: View {
    let model: WheelModel

    var body: some View {
        if model.kind == nil {
            PaletteView(model: model)
        } else {
            RingView(model: model)
        }
    }
}

private struct RingView: View {
    let model: WheelModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var center: CGPoint {
        CGPoint(x: WheelMetrics.panel.width / 2, y: WheelMetrics.panel.height - WheelMetrics.center.y)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ring
                .frame(width: WheelMetrics.outer * 2, height: WheelMetrics.outer * 2)
                .position(center)
            legend
                .position(x: center.x, y: center.y + WheelMetrics.outer + 34)
        }
        .frame(width: WheelMetrics.panel.width, height: WheelMetrics.panel.height)
    }

    private var ring: some View {
        let count = model.tools.count
        return ZStack {
            // The ring itself: material with Harbor's warm tint, and a hairline.
            Annulus(inner: WheelMetrics.inner)
                .fill(.regularMaterial, style: FillStyle(eoFill: true))
                .overlay(Annulus(inner: WheelMetrics.inner).fill(Theme.surfaceTint, style: FillStyle(eoFill: true)))
                .overlay(Annulus(inner: WheelMetrics.inner).stroke(Theme.hairline, lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 22, y: 10)

            if let hovered = model.hovered, count > 0 {
                Sector(index: hovered, count: count, inner: WheelMetrics.inner + 4, outer: WheelMetrics.outer - 4)
                    .fill(Theme.ink.opacity(0.1))
                    .transition(.opacity)
            }

            // Spokes between the slices.
            ForEach(0..<count, id: \.self) { index in
                Spoke(index: index, count: count, inner: WheelMetrics.inner + 10, outer: WheelMetrics.outer - 10)
                    .stroke(Theme.hairline, lineWidth: 1)
            }

            ForEach(Array(model.tools.enumerated()), id: \.element) { index, tool in
                ToolLabel(tool: tool, highlighted: model.hovered == index)
                    .offset(WheelView.offset(index: index, count: count, radius: (WheelMetrics.inner + WheelMetrics.outer) / 2))
            }

            hub
        }
        .animation(reduceMotion ? nil : .harborSelect, value: model.hovered)
        .animation(reduceMotion ? nil : .harborPresent, value: model.kind)
    }

    private var hub: some View {
        VStack(spacing: 2) {
            if model.tools.isEmpty {
                Text("Nothing here")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
            } else {
                Text(model.files.count == 1 ? model.files[0].pathExtension.uppercased() : "\(model.files.count)")
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(model.kind?.title ?? "")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .frame(width: WheelMetrics.inner * 2, height: WheelMetrics.inner * 2)
        .background(Circle().fill(Theme.card))
        .overlay(Circle().strokeBorder(Theme.hairline))
        .transaction { $0.animation = nil }
    }

    /// Which key opens which wheel, the open one stronger.
    private var legend: some View {
        KeyLegend(selected: model.kind)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Theme.card))
            .overlay(Capsule().strokeBorder(Theme.hairline))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .transaction { $0.animation = nil }
    }

    static func offset(index: Int, count: Int, radius: CGFloat) -> CGSize {
        WheelView.offset(index: index, count: count, radius: radius)
    }
}

extension WheelView {
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

/// Every tool that fits, grouped under the key that narrows to it. The card
/// sits just off the pointer, so letting go where it opened cancels.
private struct PaletteView: View {
    let model: WheelModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let layout = model.palette
        let card = layout.card
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.regularMaterial)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surfaceTint))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline))
                .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
                .frame(width: card.width, height: card.height)
                .offset(x: card.minX, y: card.minY)

            ForEach(Array(model.sections.enumerated()), id: \.offset) { index, section in
                if layout.headers.indices.contains(index) {
                    HStack(spacing: 6) {
                        Text(section.kind.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                        Text(WheelKind.symbol(for: Prefs.string(section.kind.prefKey)))
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Theme.ink3)
                    }
                    .offset(x: layout.headers[index].x, y: layout.headers[index].y + 2)
                }
            }

            ForEach(Array(model.tools.enumerated()), id: \.offset) { index, tool in
                if layout.tiles.indices.contains(index) {
                    let rect = layout.tiles[index]
                    let on = model.hovered == index
                    ToolLabel(tool: tool, highlighted: on, lines: 2)
                        .frame(width: rect.width, height: rect.height)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(on ? Theme.ink.opacity(0.1) : Theme.ink.opacity(0.035)))
                        .offset(x: rect.minX, y: rect.minY)
                }
            }

            HStack(spacing: 8) {
                Text("Hold a key to narrow it down")
                Text("·")
                Text("Drop outside to cancel")
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.ink3)
            .frame(width: card.width, height: PaletteMetrics.footer)
            .offset(x: card.minX, y: card.maxY - PaletteMetrics.footer - 6)
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .animation(reduceMotion ? nil : .harborSelect, value: model.hovered)
    }
}

private struct ToolLabel: View {
    let tool: Tool
    let highlighted: Bool
    var lines = 2

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: tool.symbol)
                .font(.system(size: 18, weight: .medium))
                .frame(height: 22)
            Text(tool.title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(lines)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: lines > 1)
        }
        .frame(width: lines > 1 ? 80 : 74)
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

/// One slice of the ring, centred on its tool.
private struct Sector: Shape {
    let index: Int
    let count: Int
    let inner: CGFloat
    let outer: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let width = 360 / Double(count)
        let mid = -90 + Double(index) * width
        let start = Angle.degrees(mid - width / 2 + 1), end = Angle.degrees(mid + width / 2 - 1)
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}

/// The line between two slices.
private struct Spoke: Shape {
    let index: Int
    let count: Int
    let inner: CGFloat
    let outer: CGFloat

    func path(in rect: CGRect) -> Path {
        guard count > 1 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let angle = (-90 + (Double(index) + 0.5) * 360 / Double(count)) * .pi / 180
        var path = Path()
        path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
        path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
        return path
    }
}
