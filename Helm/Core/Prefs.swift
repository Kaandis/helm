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
    /// "cream" or "glass" (Liquid Glass, macOS 26 and later), as in Ferry.
    static let panelStyle = "panelStyle"
    /// The helm's rim and handles: one of HarborKit's accents.
    static let accentColor = "accentColor"
    /// How see-through the helm's ring is, 0 (solid) to 0.8.
    static let helmTransparency = "helmTransparency"
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
            panelStyle: Self.glassAvailable ? "glass" : "cream",
            accentColor: "graphite",
            helmTransparency: 0.3,
            excludedApps: [String](),
            isPaused: false,
            hasCompletedOnboarding: false,
        ])
    }

    static var glassAvailable: Bool {
        if #available(macOS 26, *) { true } else { false }
    }

    static func bool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
    static func string(_ key: String) -> String { UserDefaults.standard.string(forKey: key) ?? "" }
    static var excluded: Set<String> { Set(UserDefaults.standard.stringArray(forKey: excludedApps) ?? []) }
}
