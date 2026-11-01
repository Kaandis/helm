import HarborKit
import SwiftUI

/// Gives floating content the look chosen in settings: cream or Liquid
/// Glass, and the colour of the helm's rim.
struct Styled<Content: View>: View {
    @AppStorage(Prefs.panelStyle) private var style = "glass"
    @AppStorage(Prefs.accentColor) private var accent = "graphite"
    @ViewBuilder var content: Content

    var body: some View {
        content
            .environment(\.palette, .named(style))
            .environment(\.accent, .named(accent))
    }
}
