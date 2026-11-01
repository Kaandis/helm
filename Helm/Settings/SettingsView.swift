import HarborKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

/// Helm's own settings window. With Harbor installed the same settings show
/// there too (see `settings-schema.json`); everything is a plain UserDefaults key.
struct SettingsView: View {
    /// The tab on show; Harbor and the menu can ask for one by name.
    @AppStorage(Prefs.settingsTab) private var tab = "general"

    var body: some View {
        TabView(selection: $tab) {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag("general")
            WheelSettings()
                .tabItem { Label("Opening", systemImage: "hand.draw") }
                .tag("opening")
            LookSettings()
                .tabItem { Label("Look", systemImage: "paintbrush") }
                .tag("look")
            BigHelmEditor()
                .tabItem { Label("Big Helm", systemImage: "circle.grid.cross") }
                .tag("bighelm")
            ExcludedApps()
                .tabItem { Label("Excluded Apps", systemImage: "nosign") }
                .tag("excluded")
        }
        .frame(width: 520, height: 640)
    }
}

private struct GeneralSettings: View {
    @AppStorage(Prefs.saveLocation) private var saveLocation = "nextToOriginal"
    @AppStorage(Prefs.revealResults) private var revealResults = false
    @AppStorage(Prefs.skipFullScreen) private var skipFullScreen = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var language = AppLanguage.current
    private let launchLanguage = AppLanguage.current

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }
            }

            Section {
                Picker("Save results", selection: $saveLocation) {
                    Text("Next to the original").tag("nextToOriginal")
                    Text("In Downloads").tag("downloads")
                }
                Toggle("Show results in Finder", isOn: $revealResults)
                Toggle("Stay out of full-screen apps", isOn: $skipFullScreen)
                Button("How to Use Helm…") { Guide.show() }
            }

            Section {
                Picker("Language", selection: $language) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: language) { _, language in language.apply() }
                if language != launchLanguage {
                    HStack {
                        Text("Restart Helm to switch languages.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Restart Now") { AppLanguage.relaunch() }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// How the helm opens: the wheel keys, and the shake.
private struct WheelSettings: View {
    @AppStorage(Prefs.convertKey) private var convertKey = "shift"
    @AppStorage(Prefs.toolsKey) private var toolsKey = "command"
    @AppStorage(Prefs.actionsKey) private var actionsKey = "control"
    @AppStorage(Prefs.keyMode) private var keyMode = "hold"
    @AppStorage(Prefs.shakeToOpen) private var shakeToOpen = true
    @AppStorage(Prefs.shakeSensitivity) private var sensitivity = "normal"

    var body: some View {
        Form {
            Section {
                KeyPicker(title: "Convert", selection: $convertKey)
                KeyPicker(title: "Tools", selection: $toolsKey)
                KeyPicker(title: "Actions", selection: $actionsKey)
                if Set([convertKey, toolsKey, actionsKey]).count < 3 {
                    Text("Give each wheel its own key.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker("Keys", selection: $keyMode) {
                    Text("Hold to show").tag("hold")
                    Text("Press to switch").tag("toggle")
                }
                .pickerStyle(.segmented)
                Text(keyMode == "hold"
                     ? "A wheel shows while you hold its key. After a shake, letting go brings the big helm back."
                     : "Press a key once and its wheel stays; press it again to go back.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("While dragging")
            }

            Section {
                Toggle("Shake a drag to see every tool", isOn: $shakeToOpen)
                Picker("Sensitivity", selection: $sensitivity) {
                    Text("Low").tag("low")
                    Text("Normal").tag("normal")
                    Text("High").tag("high")
                }
                .pickerStyle(.segmented)
                .disabled(!shakeToOpen)
                Text("There and back and there again, side to side or up and down. Higher sensitivity takes a smaller, slower shake.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Shake")
            }
        }
        .formStyle(.grouped)
    }
}

/// How the helm looks.
private struct LookSettings: View {
    @AppStorage(Prefs.panelStyle) private var panelStyle = "glass"
    @AppStorage(Prefs.accentColor) private var accentColor = "graphite"
    @AppStorage(Prefs.helmTransparency) private var transparency = 0.3
    @AppStorage(Prefs.helmSize) private var size = "medium"
    @AppStorage(Prefs.helmShape) private var shape = "round"
    @AppStorage(Prefs.showHandles) private var showHandles = true

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $panelStyle) {
                    Text("Cream").tag("cream")
                    if Prefs.glassAvailable {
                        Text("Liquid Glass").tag("glass")
                    }
                }
                .pickerStyle(.segmented)
                LabeledContent("Rim") {
                    AccentPicker(selection: $accentColor)
                }
                LabeledContent("Transparency") {
                    Slider(value: $transparency, in: 0...0.8) {
                        EmptyView()
                    } minimumValueLabel: {
                        Image(systemName: "circle.fill").font(.caption2)
                    } maximumValueLabel: {
                        Image(systemName: "circle.dotted").font(.caption2)
                    }
                    .frame(width: 220)
                }
            }

            Section {
                Picker("Size", selection: $size) {
                    Text("Small").tag("small")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                }
                .pickerStyle(.segmented)
                Picker("Shape", selection: $shape) {
                    Text("Round").tag("round")
                    Text("Square").tag("square")
                }
                .pickerStyle(.segmented)
                Toggle("Handles around the rim", isOn: $showHandles)
            }
        }
        .formStyle(.grouped)
    }
}

private struct KeyPicker: View {
    let title: LocalizedStringKey
    @Binding var selection: String

    var body: some View {
        Picker(title, selection: $selection) {
            Text("⇧ Shift").tag("shift")
            Text("⌘ Command").tag("command")
            Text("⌃ Control").tag("control")
            Text("⌥ Option").tag("option")
        }
    }
}

/// Apps where wheels never open, for apps whose own drag shortcuts clash.
private struct ExcludedApps: View {
    @State private var apps: [String] = UserDefaults.standard.stringArray(forKey: Prefs.excludedApps) ?? []

    var body: some View {
        Form {
            Section {
                if apps.isEmpty {
                    Text("No apps yet. Wheels open everywhere except full-screen apps.")
                        .foregroundStyle(.secondary)
                }
                ForEach(apps, id: \.self) { id in
                    HStack {
                        Text(name(for: id))
                        Spacer()
                        Button("Remove") { save(apps.filter { $0 != id }) }
                            .buttonStyle(.borderless)
                    }
                }
                Button("Add App…", action: add)
            } footer: {
                Text("Wheels don’t open while these apps are in front, so their own drag shortcuts keep working.")
            }
        }
        .formStyle(.grouped)
    }

    private func name(for id: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: id).map { $0.deletingPathExtension().lastPathComponent } ?? id
    }

    private func add() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        let ids = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        save(Array(Set(apps + ids)).sorted())
    }

    private func save(_ list: [String]) {
        apps = list
        UserDefaults.standard.set(list, forKey: Prefs.excludedApps)
    }
}
