import HarborKit
import OSLog
import SwiftUI

let log = Logger(subsystem: "app.helm.Helm", category: "app")

@main
struct HelmApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(Prefs.isPaused) private var isPaused = false

    var body: some Scene {
        MenuBarExtra {
            MenuContent(isPaused: $isPaused)
        } label: {
            Image(systemName: isPaused ? "pause.circle" : "helm")
        }

        Settings {
            SettingsView()
        }
    }
}

private struct MenuContent: View {
    @Binding var isPaused: Bool

    var body: some View {
        Toggle("Pause Helm", isOn: $isPaused)
        Divider()
        Button("Settings…") { AppDelegate.showSettings() }
            .keyboardShortcut(",")
        Button("How to Use Helm…") { Guide.show() }
        Divider()
        Button("Quit Helm") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let watcher = DragWatcher()
    private let wheel = WheelController()
    private let toast = Toast()
    private let shelf = Shelf()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.registerDefaults()
        SettingsBridge.listen()
        #if DEBUG
        // `Helm --run <tool> <file>…` runs one tool, prints what it made and quits.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--run"), i + 2 < args.count, let tool = Tool(rawValue: args[i + 1]) {
            let files = args[(i + 2)...].map { URL(fileURLWithPath: $0) }
            Task.detached {
                do {
                    let outcome = try await ToolRunner.run(tool, on: files) { _ in }
                    print("ok \(tool.rawValue): \(outcome.outputs.map(\.lastPathComponent)) \(outcome.message ?? "")")
                    exit(0)
                } catch {
                    print("failed \(tool.rawValue): \(error.localizedDescription)")
                    exit(1)
                }
            }
            return
        }
        // `Helm --cut <file>…` puts files on the shelf, as the Cut tool does.
        if let i = args.firstIndex(of: "--cut"), i + 1 < args.count {
            run(.cut, on: args[(i + 1)...].map { URL(fileURLWithPath: $0) })
        }
        // `Helm --wheel <kind|all> <hovered> <file>…` shows a menu at the pointer, for screenshots.
        if let i = args.firstIndex(of: "--wheel"), i + 3 < args.count {
            let files = args[(i + 3)...].map { URL(fileURLWithPath: $0) }
            let menu = WheelKind(rawValue: args[i + 1]).map(DragWatcher.Menu.wheel) ?? .all
            wheel.show(DragWatcher.Drag(menu: menu, files: files, location: NSEvent.mouseLocation))
            wheel.model.hovered = Int(args[i + 2])
            return
        }
        #endif

        watcher.onDrag = { [weak self] drag in
            guard let self else { return }
            if let drag {
                log.notice("Menu \(String(describing: drag.menu), privacy: .public) for \(drag.files.count) files")
                self.wheel.show(drag)
            } else {
                self.wheel.hide()
            }
        }
        wheel.onRun = { [weak self] tool, files in self?.run(tool, on: files) }
        shelf.onMoved = { [weak self] count in
            self?.toast.start(.cut)
            self?.toast.finish(ToolRunner.Outcome(message: count == 1 ? String(localized: "Moved")
                                                                      : String(localized: "\(count) items moved")))
        }
        watcher.start()

        if !Prefs.bool(Prefs.hasCompletedOnboarding) { Guide.show() }
        log.notice("Launched")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Self.showSettings()
        return true
    }

    private func run(_ tool: Tool, on files: [URL]) {
        if tool == .cut {
            shelf.add(files)
            toast.start(tool)
            toast.finish(ToolRunner.Outcome(message: String(localized: "Drag the shelf into a folder, or press ⌥⌘V there.")))
            return
        }
        // Copy Path and the like finish at once; only real work shows progress.
        let quiet: Set<Tool> = [.airDrop, .openTerminal]
        if !quiet.contains(tool) { toast.start(tool) }
        Task {
            do {
                let outcome = try await Task.detached(priority: .userInitiated) {
                    try await ToolRunner.run(tool, on: files) { fraction in
                        Task { @MainActor in self.toast.progress(fraction) }
                    }
                }.value
                log.notice("\(tool.rawValue, privacy: .public) made \(outcome.outputs.count) files")
                guard !quiet.contains(tool) else { return }
                toast.finish(outcome)
                if Prefs.bool(Prefs.revealResults), !outcome.outputs.isEmpty {
                    NSWorkspace.shared.activateFileViewerSelecting(outcome.outputs)
                }
            } catch {
                log.error("\(tool.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                toast.start(tool)
                toast.fail(error)
            }
        }
    }

    /// With Harbor installed, settings live there; otherwise in Helm's own window.
    static func showSettings() {
        guard !HarborLink.openSettings(appID: "helm") else { return }
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
