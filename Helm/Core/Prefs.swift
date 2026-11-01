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
    /// "low", "normal" or "high": how small and slow a shake may be.
    static let shakeSensitivity = "shakeSensitivity"
    /// "hold": a wheel shows while its key is down. "toggle": a press picks
    /// it until pressed again.
    static let keyMode = "keyMode"
    /// "small", "medium" or "large".
    static let helmSize = "helmSize"
    /// "round" or "square".
    static let helmShape = "helmShape"
    static let showHandles = "showHandles"
    /// False to show only the tools in `bigHelmTools` on the big helm.
    static let bigHelmShowsAll = "bigHelmShowsAll"
    /// Tools (raw values) the big helm shows when it doesn't show them all.
    static let bigHelmTools = "bigHelmTools"
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
            shakeSensitivity: "normal",
            keyMode: "hold",
            helmSize: "medium",
            helmShape: "round",
            showHandles: true,
            bigHelmShowsAll: true,
            bigHelmTools: Tool.allCases.map(\.rawValue),
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
