import Foundation

/// UserDefaults keys shared by @AppStorage and the services. Every key a
/// user can change is also described in `Resources/settings-schema.json`, so
/// Harbor can show these settings too.
enum Prefs {
    /// The key held while dragging that opens each wheel: "shift",
    /// "command", "control" or "option".
    static let convertKey = "convertKey"
    static let toolsKey = "toolsKey"
    static let actionsKey = "actionsKey"
    /// "nextToOriginal" or "downloads".
    static let saveLocation = "saveLocation"
    static let revealResults = "revealResults"
    /// No wheel while an app is full screen (games, video).
    static let skipFullScreen = "skipFullScreen"
    /// Shaking a drag side to side shows every tool that fits.
    static let shakeToOpen = "shakeToOpen"
    /// Bundle identifiers where wheels never open, for apps whose own
    /// drag shortcuts would clash (Photoshop, games).
    static let excludedApps = "excludedApps"
    static let isPaused = "isPaused"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            convertKey: "shift",
            toolsKey: "command",
            actionsKey: "control",
            saveLocation: "nextToOriginal",
            revealResults: false,
            skipFullScreen: true,
            shakeToOpen: true,
            excludedApps: [String](),
            isPaused: false,
            hasCompletedOnboarding: false,
        ])
    }

    static func bool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
    static func string(_ key: String) -> String { UserDefaults.standard.string(forKey: key) ?? "" }
    static var excluded: Set<String> { Set(UserDefaults.standard.stringArray(forKey: excludedApps) ?? []) }
}
