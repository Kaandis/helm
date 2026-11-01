import AppKit
import HarborKit
import SwiftUI

/// The welcome window: how the wheels open, shown once and again from the menu.
@MainActor
enum Guide {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 600),
                                  styleMask: [.titled, .closable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(Theme.background)
            window.title = String(localized: "Welcome to Helm")
            window.contentView = NSHostingView(rootView: GuideView { close() })
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    static func close() {
        UserDefaults.standard.set(true, forKey: Prefs.hasCompletedOnboarding)
        window?.close()
    }
}

struct GuideView: View {
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Drag, hold a key, drop")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
            Text("Helm turns, shrinks and sends your files right where you drag them, with nothing to open first.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            WheelDemo()
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .padding(.top, 18)

            VStack(alignment: .leading, spacing: 14) {
                Step(number: 1, text: "Start dragging files in Finder or on the desktop.")
                Step(number: 2, text: "Hold ⇧ to convert, ⌘ for tools, or ⌃ for actions. A wheel opens under the pointer. Or shake the files side to side to see every tool at once.")
                Step(number: 3, text: "Drop on a tool. The result lands next to the original; drop in the middle, or outside, to cancel.")
            }
            .padding(.top, 18)

            Text("Helm stays out of full-screen apps, and you can turn it off for apps whose own drag shortcuts clash, or pause it from the menu bar.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Spacer(minLength: 16)
            HStack {
                Spacer()
                Button("Got It", action: onDone)
                    .buttonStyle(HarborButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 36)
        .padding(.top, 44)
        .padding(.bottom, 28)
        .frame(width: 580, height: 600)
        .background(Theme.background)
    }
}

private struct Step: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.background)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Theme.ink))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A file is dragged, ⇧ is held, the wheel blooms and JPG is chosen. Plays
/// three times while the window is open; holds still with Reduce Motion.
private struct WheelDemo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    private let labels = ["JPG", "PNG", "HEIC", "PDF", "TIFF"]

    var body: some View {
        let open = phase >= 2
        ZStack {
            // The wheel.
            ZStack {
                Circle().fill(Theme.card)
                    .overlay(Circle().strokeBorder(Theme.hairline))
                    .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
                if phase >= 3 {
                    Circle()
                        .trim(from: 0.9, to: 1.1)
                        .stroke(Theme.ink.opacity(0.1), lineWidth: 52)
                        .frame(width: 128, height: 128)
                        .rotationEffect(.degrees(-90))
                }
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    let angle = Double(index) / Double(labels.count) * 2 * .pi
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(index == 0 && phase >= 3 ? Theme.ink : Theme.ink2)
                        .offset(x: sin(angle) * 64, y: -cos(angle) * 64)
                }
                Circle().fill(Theme.background).frame(width: 52, height: 52)
                    .overlay(Text("HEIC").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.ink))
            }
            .frame(width: 180, height: 180)
            .scaleEffect(open ? 1 : 0.8)
            .opacity(open ? 1 : 0)

            // The file being dragged.
            Image(systemName: "photo")
                .font(.system(size: 26))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 52)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.hairline))
                .offset(fileOffset)
                .opacity(phase == 4 ? 0 : 1)

            Keycap(key: "⇧")
                .offset(x: 120, y: -70)
                .opacity(phase == 2 || phase == 3 ? 1 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("A photo is dragged with Shift held; the wheel opens and the photo is dropped on JPG."))
        .task {
            guard !reduceMotion else { phase = 3; return }
            for _ in 0..<3 where !Task.isCancelled {
                for next in [1, 2, 3, 4, 0] {
                    try? await Task.sleep(for: .seconds(next == 0 ? 1.4 : 1.1))
                    withAnimation(.spring(response: 0.45, dampingFraction: 1)) { phase = next }
                }
            }
        }
    }

    private var fileOffset: CGSize {
        switch phase {
        case 0: CGSize(width: -150, height: 40)
        case 1, 2: CGSize(width: 0, height: 0)
        case 3, 4: CGSize(width: 0, height: -64)
        default: .zero
        }
    }
}
