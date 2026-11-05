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
            MenuBarLabel(isPaused: isPaused)
        }

        Settings {
            SettingsView()
        }
    }
}

/// The menu bar icon. It is always drawn, so it also keeps SwiftUI's way of
/// opening the Settings window at hand for code outside any view.
private struct MenuBarLabel: View {
    let isPaused: Bool
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Image(systemName: isPaused ? "pause.circle" : "helm")
            .onAppear { AppDelegate.openSettingsWindow = { openSettings() } }
    }
}

private struct MenuContent: View {
    @Binding var isPaused: Bool

    var body: some View {
        Toggle("Pause Helm", isOn: $isPaused)
        Divider()
        Button("Settings…") { AppDelegate.showSettings() }
            .keyboardShortcut(",")
        Button("Arrange the Big Helm…") { AppDelegate.showOwnSettings(tab: "bighelm") }
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
        Prefs.migrateBigHelmTools()
        Prefs.migrateToEverydayHelm()
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
        // `Helm --settings <tab>` opens Helm's own settings window on a tab.
        if let i = args.firstIndex(of: "--settings") {
            let tab = i + 1 < args.count ? args[i + 1] : nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { Self.showOwnSettings(tab: tab) }
        }
        // `Helm --transfer move|copy <folder> <file>…` runs Move to… or Copy to… without the panel.
        if let i = args.firstIndex(of: "--transfer"), i + 3 < args.count {
            let files = args[(i + 3)...].map { URL(fileURLWithPath: $0) }
            let outcome = try? ToolRunner.transfer(files, to: URL(fileURLWithPath: args[i + 2]), move: args[i + 1] == "move")
            print("transfer: \(outcome?.outputs.map(\.path) ?? []) \(outcome?.message ?? "failed")")
            exit(0)
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
        wheel.prepare()
        listenForHarbor()

        if !Prefs.bool(Prefs.hasCompletedOnboarding) { Guide.show() }
        log.notice("Launched")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Self.showSettings()
        return true
    }

    private func run(_ tool: Tool, on files: [URL]) {
        if tool == .moveTo || tool == .copyTo {
            chooseFolder(for: tool, files: files)
            return
        }
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

    /// Asks where, starting where you last put something, then moves or
    /// copies there and says so, with a button to show the result.
    private func chooseFolder(for tool: Tool, files: [URL]) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = tool == .moveTo ? String(localized: "Move Here") : String(localized: "Copy Here")
        panel.message = files.count == 1 ? files[0].lastPathComponent : String(localized: "\(files.count) items")
        if let last = UserDefaults.standard.url(forKey: Prefs.lastFolder) { panel.directoryURL = last }
        NSApp.activate()
        panel.begin { [weak self] response in
            guard response == .OK, let folder = panel.url, let self else { return }
            UserDefaults.standard.set(folder, forKey: Prefs.lastFolder)
            do {
                let outcome = try ToolRunner.transfer(files, to: folder, move: tool == .moveTo)
                self.toast.start(tool)
                self.toast.finish(outcome)
            } catch {
                self.toast.start(tool)
                self.toast.fail(error)
            }
        }
    }

    /// Opens Helm's Settings window; set once the menu bar icon is drawn.
    static var openSettingsWindow: (() -> Void)?

    /// With Harbor installed, settings live there; otherwise in Helm's own window.
    static func showSettings() {
        guard !HarborLink.openSettings(appID: "helm") else { return }
        showOwnSettings()
    }

    /// Helm's own window, on `tab` if given. Harbor sends people here for
    /// what its schema can't draw, like arranging the big helm.
    static func showOwnSettings(tab: String? = nil) {
        if let tab { UserDefaults.standard.set(tab, forKey: Prefs.settingsTab) }
        NSApp.activate()
        openSettingsWindow?()
    }

    /// Harbor asks running apps by notification, and launches others with
    /// `--open-settings <section>`.
    private func listenForHarbor() {
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.harbor.openOwnSettings"),
                                                            object: Bundle.main.bundleIdentifier, queue: .main) { note in
            let section = note.userInfo?["section"] as? String
            MainActor.assumeIsolated { Self.showOwnSettings(tab: section) }
        }
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--open-settings"), i + 1 < args.count {
            let section = args[i + 1]
            // The menu bar icon has to be drawn before Settings can open.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { Self.showOwnSettings(tab: section) }
        }
    }
}
