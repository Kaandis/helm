import HarborKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

/// Helm's own settings window. With Harbor installed the same settings show
/// there too (see `settings-schema.json`); everything is a plain UserDefaults key.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            ExcludedApps()
                .tabItem { Label("Excluded Apps", systemImage: "nosign") }
        }
        .frame(width: 480)
    }
}

private struct GeneralSettings: View {
    @AppStorage(Prefs.convertKey) private var convertKey = "shift"
    @AppStorage(Prefs.toolsKey) private var toolsKey = "command"
    @AppStorage(Prefs.actionsKey) private var actionsKey = "control"
    @AppStorage(Prefs.saveLocation) private var saveLocation = "nextToOriginal"
    @AppStorage(Prefs.revealResults) private var revealResults = false
    @AppStorage(Prefs.skipFullScreen) private var skipFullScreen = true
    @AppStorage(Prefs.shakeToOpen) private var shakeToOpen = true
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
                KeyPicker(title: "Convert", selection: $convertKey)
                KeyPicker(title: "Tools", selection: $toolsKey)
                KeyPicker(title: "Actions", selection: $actionsKey)
                if Set([convertKey, toolsKey, actionsKey]).count < 3 {
                    Text("Give each wheel its own key.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Shake a drag to see every tool", isOn: $shakeToOpen)
            } header: {
                Text("Hold while dragging")
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
