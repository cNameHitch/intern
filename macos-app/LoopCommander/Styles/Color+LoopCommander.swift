import SwiftUI

// MARK: - Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        if hex.count == 6 {
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        } else {
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Design Tokens

extension Color {
    // -- Backgrounds --
    /// App root background. JSX: #0f1117
    static let lcBackground      = Color(hex: "0f1117")
    /// Modal / editor panel background. JSX: #1a1d23
    static let lcSurface         = Color(hex: "1a1d23")
    /// Subtle raised surface. JSX: rgba(255,255,255,0.02)
    static let lcSurfaceRaised   = Color.white.opacity(0.02)
    /// Card / table container. JSX: rgba(255,255,255,0.01)
    static let lcSurfaceContainer = Color.white.opacity(0.01)
    /// Code block background. JSX: rgba(0,0,0,0.3)
    static let lcCodeBackground  = Color.black.opacity(0.3)

    // -- Text --
    /// Primary text. JSX: #e2e8f0
    static let lcTextPrimary     = Color(hex: "e2e8f0")
    /// Secondary / detail text. JSX: #c8d0dc
    static let lcTextSecondary   = Color(hex: "c8d0dc")
    /// Muted text (labels, timestamps). JSX: rgba(255,255,255,0.4)
    static let lcTextMuted       = Color.white.opacity(0.4)
    /// Very muted text (sublabels, working dirs). JSX: rgba(255,255,255,0.35)
    static let lcTextSubtle      = Color.white.opacity(0.35)
    /// Faintest text (column headers). JSX: rgba(255,255,255,0.3)
    static let lcTextFaint       = Color.white.opacity(0.3)
    /// Dimmest text (log filter inactive). JSX: rgba(255,255,255,0.25)
    static let lcTextDimmest     = Color.white.opacity(0.25)

    // -- Accents --
    /// Primary accent (indigo). JSX: #818cf8
    static let lcAccent          = Color(hex: "818cf8")
    /// Accent pressed / gradient end. JSX: #6366f1
    static let lcAccentDeep      = Color(hex: "6366f1")
    /// Accent for active text / links. JSX: #a5b4fc
    static let lcAccentLight     = Color(hex: "a5b4fc")
    /// Accent background wash. JSX: rgba(129,140,248,0.15)
    static let lcAccentBg        = Color(hex: "818cf8").opacity(0.15)
    /// Accent background subtle (selected row). JSX: rgba(99,102,241,0.08)
    static let lcAccentBgSubtle  = Color(hex: "6366f1").opacity(0.08)
    /// Tag background. JSX: rgba(129,140,248,0.1)
    static let lcTagBg           = Color(hex: "818cf8").opacity(0.1)
    /// Focus ring / input focus. JSX: rgba(129,140,248,0.5)
    static let lcAccentFocus     = Color(hex: "818cf8").opacity(0.5)

    // -- Status: Active / Success --
    /// Green. JSX: #22c55e
    static let lcGreen           = Color(hex: "22c55e")
    /// Green background wash. JSX: rgba(34,197,94,0.1)
    static let lcGreenBg         = Color(hex: "22c55e").opacity(0.1)
    /// Green background subtle (log success). JSX: rgba(34,197,94,0.08)
    static let lcGreenBgSubtle   = Color(hex: "22c55e").opacity(0.08)

    // -- Status: Paused / Warning --
    /// Amber. JSX: #f59e0b
    static let lcAmber           = Color(hex: "f59e0b")
    /// Amber background wash. JSX: rgba(245,158,11,0.1)
    static let lcAmberBg         = Color(hex: "f59e0b").opacity(0.1)

    // -- Status: Error --
    /// Red. JSX: #ef4444
    static let lcRed             = Color(hex: "ef4444")
    /// Red background wash. JSX: rgba(239,68,68,0.1)
    static let lcRedBg           = Color(hex: "ef4444").opacity(0.1)
    /// Red border for delete button. JSX: rgba(239,68,68,0.2)
    static let lcRedBorder       = Color(hex: "ef4444").opacity(0.2)

    // -- Borders & Separators --
    /// Standard border. JSX: rgba(255,255,255,0.06)
    static let lcBorder          = Color.white.opacity(0.06)
    /// Input border. JSX: rgba(255,255,255,0.1)
    static let lcBorderInput     = Color.white.opacity(0.1)
    /// Divider (thinner). JSX: rgba(255,255,255,0.04)
    static let lcDivider         = Color.white.opacity(0.04)
    /// Header divider / toolbar separator. JSX: rgba(255,255,255,0.08)
    static let lcSeparator       = Color.white.opacity(0.08)
    /// Scrollbar thumb. JSX: rgba(255,255,255,0.08)
    static let lcScrollbar       = Color.white.opacity(0.08)
    /// Scrollbar thumb hover. JSX: rgba(255,255,255,0.15)
    static let lcScrollbarHover  = Color.white.opacity(0.15)

    // -- Selected Row --
    /// Selected row left border. JSX: #818cf8 (2px solid)
    static let lcSelectedBorder  = Color(hex: "818cf8")

    // -- Overlay --
    /// Modal backdrop. JSX: rgba(0,0,0,0.7)
    static let lcOverlay         = Color.black.opacity(0.7)

    // -- Light Mode (N8, future) --
    static let lcLightBackground = Color(hex: "f8f9fc")
    static let lcLightSurface    = Color.white
    static let lcLightText       = Color(hex: "1a1d23")
    static let lcLightMuted      = Color(hex: "718096")
}

// MARK: - Health Color

extension Color {
    /// Returns the appropriate health color for a success rate percentage.
    /// JSX: >= 95 -> green, >= 80 -> amber, < 80 -> red
    static func lcHealthColor(for successRate: Int) -> Color {
        if successRate >= 95 { return .lcGreen }
        if successRate >= 80 { return .lcAmber }
        return .lcRed
    }
}
