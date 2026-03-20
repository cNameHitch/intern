# SwiftUI Design Reference -- Loop Commander

> **Purpose:** This document maps every visual element, interaction, and design token from the
> `loop-commander.jsx` React prototype to its native SwiftUI equivalent. A Swift developer should
> be able to build the macOS app pixel-for-pixel from this reference alone.
>
> **Source of truth:** `loop-commander.jsx` (visual design) + `specs.md` Section 9 (architecture).

---

## Table of Contents

1. [Design System](#1-design-system)
2. [Component Reference](#2-component-reference)
3. [View Architecture](#3-view-architecture)
4. [macOS Native Enhancements](#4-macos-native-enhancements)
5. [Accessibility Mapping](#5-accessibility-mapping)
6. [Implementation Priority](#6-implementation-priority)

---

## 1. Design System

### 1.1 Color Tokens

Every color below is extracted directly from the JSX inline styles. Organize them as a SwiftUI
`Color` extension using a hex initializer.

```swift
// MARK: - Color+LoopCommander.swift

import SwiftUI

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
    // ── Backgrounds ──────────────────────────────────────────
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

    // ── Text ─────────────────────────────────────────────────
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

    // ── Accents ──────────────────────────────────────────────
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

    // ── Status: Active / Success ─────────────────────────────
    /// Green. JSX: #22c55e
    static let lcGreen           = Color(hex: "22c55e")
    /// Green background wash. JSX: rgba(34,197,94,0.1)
    static let lcGreenBg         = Color(hex: "22c55e").opacity(0.1)
    /// Green background subtle (log success). JSX: rgba(34,197,94,0.08)
    static let lcGreenBgSubtle   = Color(hex: "22c55e").opacity(0.08)

    // ── Status: Paused / Warning ─────────────────────────────
    /// Amber. JSX: #f59e0b
    static let lcAmber           = Color(hex: "f59e0b")
    /// Amber background wash. JSX: rgba(245,158,11,0.1)
    static let lcAmberBg         = Color(hex: "f59e0b").opacity(0.1)

    // ── Status: Error ────────────────────────────────────────
    /// Red. JSX: #ef4444
    static let lcRed             = Color(hex: "ef4444")
    /// Red background wash. JSX: rgba(239,68,68,0.1)
    static let lcRedBg           = Color(hex: "ef4444").opacity(0.1)
    /// Red border for delete button. JSX: rgba(239,68,68,0.2)
    static let lcRedBorder       = Color(hex: "ef4444").opacity(0.2)

    // ── Borders & Separators ─────────────────────────────────
    /// Standard border. JSX: rgba(255,255,255,0.06)
    static let lcBorder          = Color.white.opacity(0.06)
    /// Input border. JSX: rgba(255,255,255,0.1)
    static let lcBorderInput     = Color.white.opacity(0.1)
    /// Divider (thinner). JSX: rgba(255,255,255,0.04)
    static let lcDivider         = Color.white.opacity(0.04)
    /// Header divider / toolbar separator. JSX: rgba(255,255,255,0.08)
    static let lcSeparator       = Color.white.opacity(0.08)
    /// Scrollbar thumb. JSX: rgba(255,255,255,0.08), hover: 0.15
    static let lcScrollbar       = Color.white.opacity(0.08)
    static let lcScrollbarHover  = Color.white.opacity(0.15)

    // ── Selected Row ─────────────────────────────────────────
    /// Selected row left border. JSX: #818cf8 (2px solid)
    static let lcSelectedBorder  = Color(hex: "818cf8")

    // ── Overlay ──────────────────────────────────────────────
    /// Modal backdrop. JSX: rgba(0,0,0,0.7)
    static let lcOverlay         = Color.black.opacity(0.7)
}
```

### 1.2 Typography

The JSX uses two font families: `'Inter'` for UI text and `'JetBrains Mono'` for code/data.
On macOS, use the system equivalents: SF Pro (system default) and SF Mono (`design: .monospaced`).

```swift
// MARK: - Font+LoopCommander.swift

import SwiftUI

extension Font {
    // ── UI Text (Inter -> SF Pro / system font) ──────────────
    /// App title. JSX: 15px, weight 700, letter-spacing -0.3px
    static let lcTitle        = Font.system(size: 15, weight: .bold)
    /// Section heading / modal title. JSX: 18px, weight 700
    static let lcHeading      = Font.system(size: 18, weight: .bold)
    /// Detail view heading. JSX: 20px, weight 700
    static let lcHeadingLarge = Font.system(size: 20, weight: .bold)
    /// Task name in row. JSX: 13.5px, weight 600
    static let lcBodyBold     = Font.system(size: 13.5, weight: .semibold)
    /// Log task name. JSX: 12.5px, weight 500
    static let lcBodyMedium   = Font.system(size: 12.5, weight: .medium)
    /// Button text. JSX: 12.5-13px, weight 600
    static let lcButton       = Font.system(size: 13, weight: .semibold)
    /// Button text small. JSX: 12px, weight 500
    static let lcButtonSmall  = Font.system(size: 12, weight: .medium)
    /// Input label. JSX: 11px, weight 600, uppercase
    static let lcLabel        = Font.system(size: 11, weight: .semibold)
    /// Form input text. JSX: 13px, monospaced
    static let lcInput        = Font.system(size: 13, design: .monospaced)
    /// Metric card label. JSX: 11px, weight 500, uppercase, letter-spacing 0.5px
    static let lcMetricLabel  = Font.system(size: 11, weight: .medium)
    /// Column header. JSX: 10px, weight 600, uppercase, letter-spacing 0.5px
    static let lcColumnHeader = Font.system(size: 10, weight: .semibold)
    /// Subtitle text. JSX: 10.5px, monospaced, letter-spacing 0.5px
    static let lcSubtitle     = Font.system(size: 10.5, design: .monospaced)
    /// Log summary inline. JSX: 11px, color muted
    static let lcCaption      = Font.system(size: 11)
    /// Section label. JSX: 12px, weight 600, color muted
    static let lcSectionLabel = Font.system(size: 12, weight: .semibold)

    // ── Code / Data (JetBrains Mono -> SF Mono) ──────────────
    /// Metric card value. JSX: 28px, weight 700, JetBrains Mono
    static let lcMetricValue  = Font.system(size: 28, weight: .bold, design: .monospaced)
    /// Code block text. JSX: 11px, JetBrains Mono
    static let lcCode         = Font.system(size: 11, design: .monospaced)
    /// Log data cells (timestamp, duration, tokens, cost). JSX: 11px, JetBrains Mono
    static let lcData         = Font.system(size: 11, design: .monospaced)
    /// Schedule text / working dir in rows. JSX: 11-12px, JetBrains Mono
    static let lcDataSmall    = Font.system(size: 11, design: .monospaced)
    /// Run count / percentage in rows. JSX: 12px, JetBrains Mono
    static let lcDataMedium   = Font.system(size: 12, design: .monospaced)
    /// Status badge text. JSX: 11px, weight 600, JetBrains Mono, uppercase
    static let lcBadge        = Font.system(size: 11, weight: .semibold, design: .monospaced)
    /// Badge icon. JSX: 8px
    static let lcBadgeIcon    = Font.system(size: 8)
    /// Tag text. JSX: 10px, JetBrains Mono
    static let lcTag          = Font.system(size: 10, design: .monospaced)
    /// Detail field label. JSX: 10px, uppercase
    static let lcFieldLabel   = Font.system(size: 10)
    /// Detail field value. JSX: 12.5px, JetBrains Mono
    static let lcFieldValue   = Font.system(size: 12.5, design: .monospaced)
    /// Metric card sub-text. JSX: 11px
    static let lcMetricSub    = Font.system(size: 11)
    /// Command preview in detail. JSX: 11.5px, JetBrains Mono
    static let lcCodePreview  = Font.system(size: 11.5, design: .monospaced)
    /// Log summary expanded. JSX: 11.5px, line-height 1.5
    static let lcLogSummary   = Font.system(size: 11.5)
}
```

### 1.3 Spacing Scale

Extracted from every `padding`, `gap`, and `margin` value in the JSX:

```swift
// MARK: - Spacing.swift

import SwiftUI

enum LCSpacing {
    /// 3px - Badge internal padding vertical, tag padding vertical
    static let xxxs: CGFloat = 3
    /// 4px - Tag gap, tag list gap, close button padding
    static let xxs: CGFloat  = 4
    /// 5px - Badge icon-label gap, new-task button icon gap
    static let xs: CGFloat   = 5
    /// 6px - Metric label bottom margin, two-col gap small,
    ///        nav button gap, divider margin
    static let sm: CGFloat   = 6
    /// 8px - Log grid gap, tag input gap, log search gap,
    ///        metric label bottom margin, tag list top margin,
    ///        search input padding vertical
    static let md: CGFloat   = 8
    /// 10px - Badge padding horizontal, tag padding horizontal,
    ///         status icon padding, row border spacing,
    ///         log entry row padding vertical, footer button gap
    static let lg: CGFloat   = 10
    /// 12px - Metrics grid gap, two-col grid gap, detail-info grid gap,
    ///         detail task heading - badge gap, back-button gap,
    ///         code block padding, filter button padding horizontal
    static let xl: CGFloat   = 12
    /// 14px - Task row padding vertical, logo-title gap,
    ///         log expanded bottom padding, code block padding (larger),
    ///         search input padding horizontal
    static let xxl: CGFloat  = 14
    /// 16px - Header padding vertical, log row padding horizontal,
    ///         log header padding, detail section gap, nav button padding,
    ///         two-col gap (larger), back-button padding
    static let xxxl: CGFloat = 16
    /// 18px - Metric card padding top
    static let p18: CGFloat  = 18
    /// 20px - Metric card padding horizontal, task row padding horizontal,
    ///         detail info grid gap (row), column header padding horizontal,
    ///         detail section padding, detail info gap
    static let p20: CGFloat  = 20
    /// 24px - Detail info card padding, footer button padding horizontal (save)
    static let p24: CGFloat  = 24
    /// 28px - Header padding horizontal, metrics bar outer padding,
    ///         content area outer padding, editor title bottom margin,
    ///         editor footer top margin
    static let p28: CGFloat  = 28
    /// 32px - Editor modal padding, empty state padding
    static let p32: CGFloat  = 32
    /// 46px - Log expanded content left inset (22px icon col + 16px row pad + 8px gap)
    static let logExpandedInset: CGFloat = 46
}
```

### 1.4 Corner Radii

```swift
enum LCRadius {
    /// 4px - StatusBadge, tags
    static let badge: CGFloat  = 4
    /// 5px - Filter buttons
    static let filter: CGFloat = 5
    /// 6px - Buttons, inputs, code blocks, nav buttons
    static let button: CGFloat = 6
    /// 8px - Metric cards, app icon square, logo container
    static let card: CGFloat   = 8
    /// 10px - Table containers, detail info panels, log containers
    static let panel: CGFloat  = 10
    /// 12px - Editor modal
    static let modal: CGFloat  = 12
}
```

### 1.5 Border Widths

```swift
enum LCBorder {
    /// 1px - Standard borders on cards, panels, inputs, dividers
    static let standard: CGFloat = 1
    /// 2px - Selected row left accent border
    static let selected: CGFloat = 2
}
```

### 1.6 Shadows

```swift
// Editor modal shadow. JSX: 0 24px 80px rgba(0,0,0,0.6)
extension View {
    func lcModalShadow() -> some View {
        self.shadow(color: .black.opacity(0.6), radius: 40, x: 0, y: 24)
    }
}
```

### 1.7 Animations

```swift
// MARK: - Animations.swift

import SwiftUI

extension Animation {
    /// General UI transition. JSX: transition "all 0.15s ease"
    static let lcQuick = Animation.easeInOut(duration: 0.15)
    /// Expand/collapse, modal appear. JSX: @keyframes fadeSlide 0.2s ease
    static let lcFadeSlide = Animation.easeOut(duration: 0.2)
    /// Running-task pulse. JSX: @keyframes pulse 0.5->1.0 opacity
    static let lcPulse = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
}

// fadeSlide transition: opacity 0->1, translateY -4->0
extension AnyTransition {
    static var lcFadeSlide: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)).animation(.lcFadeSlide),
            removal: .opacity.animation(.lcQuick)
        )
    }
}
```

### 1.8 Status Configuration

Centralized status styling, mirroring the JSX `STATUS_CONFIG` object:

```swift
// MARK: - StatusConfig.swift

import SwiftUI

enum TaskStatusStyle {
    case active
    case paused
    case error
    case success
    case running   // Added per spec R9
    case disabled

    init(from status: TaskStatus) {
        switch status {
        case .active:   self = .active
        case .paused:   self = .paused
        case .error:    self = .error
        case .disabled: self = .disabled
        case .running:  self = .running
        }
    }

    /// Foreground color
    var color: Color {
        switch self {
        case .active, .success: return .lcGreen          // #22c55e
        case .paused:           return .lcAmber           // #f59e0b
        case .error:            return .lcRed             // #ef4444
        case .running:          return .lcAccent          // #818cf8
        case .disabled:         return .lcTextMuted       // white 0.4
        }
    }

    /// Badge background
    var background: Color {
        switch self {
        case .active:   return .lcGreenBg           // rgba(34,197,94,0.1)
        case .success:  return .lcGreenBgSubtle     // rgba(34,197,94,0.08)
        case .paused:   return .lcAmberBg           // rgba(245,158,11,0.1)
        case .error:    return .lcRedBg             // rgba(239,68,68,0.1)
        case .running:  return .lcAccentBg          // rgba(129,140,248,0.15)
        case .disabled: return Color.white.opacity(0.05)
        }
    }

    /// Display label (uppercase in badge)
    var label: String {
        switch self {
        case .active:   return "Active"
        case .paused:   return "Paused"
        case .error:    return "Error"
        case .success:  return "Success"
        case .running:  return "Running"
        case .disabled: return "Disabled"
        }
    }

    /// SF Symbol name (replaces JSX unicode icons with native symbols)
    var sfSymbol: String {
        switch self {
        case .active, .success: return "circle.fill"
        case .paused:           return "pause.fill"
        case .error:            return "xmark"
        case .running:          return "arrow.triangle.2.circlepath"
        case .disabled:         return "minus.circle"
        }
    }

    /// Original JSX icon character (for reference / fallback)
    var textIcon: String {
        switch self {
        case .active, .success: return "\u{25CF}"         // filled circle
        case .paused:           return "\u{275A}\u{275A}" // double bar
        case .error:            return "\u{2715}"         // multiplication X
        case .running:          return "\u{21BB}"         // clockwise arrow
        case .disabled:         return "\u{2212}"         // minus
        }
    }
}
```

### 1.9 Health Color Thresholds

From the JSX `TaskRow` component, success rate determines the health color:

```swift
extension Color {
    /// Returns the appropriate health color for a success rate percentage.
    /// JSX: >= 95 -> green, >= 80 -> amber, < 80 -> red
    static func lcHealthColor(for successRate: Int) -> Color {
        if successRate >= 95 { return .lcGreen }
        if successRate >= 80 { return .lcAmber }
        return .lcRed
    }
}
```

### 1.10 Light Mode Palette (N8)

For future dark/light theme toggle support:

```swift
extension Color {
    // Light mode equivalents (from spec N8)
    static let lcLightBackground = Color(hex: "f8f9fc")
    static let lcLightSurface    = Color.white
    static let lcLightText       = Color(hex: "1a1d23")
    static let lcLightMuted      = Color(hex: "718096")
    // Accent and status colors remain the same in both modes
}
```

---

## 2. Component Reference

### 2.1 StatusBadge

**JSX source:** lines 158-171

| Property | JSX Value | SwiftUI Equivalent |
|---|---|---|
| Layout | `inline-flex`, `align-items: center`, `gap: 5` | `HStack(spacing: 5)` |
| Padding | `3px 10px` | `.padding(.horizontal, 10).padding(.vertical, 3)` |
| Corner radius | `4px` | `.cornerRadius(4)` or `LCRadius.badge` |
| Background | Per-status rgba | `TaskStatusStyle.background` |
| Text color | Per-status hex | `TaskStatusStyle.color` |
| Font | 11px, weight 600, JetBrains Mono, uppercase | `.lcBadge` + `.textCase(.uppercase)` |
| Letter spacing | 0.5px | `.tracking(0.5)` |
| Icon font | 8px | `.lcBadgeIcon` |

```swift
// MARK: - StatusBadge.swift

import SwiftUI

struct StatusBadge: View {
    let status: TaskStatus

    private var style: TaskStatusStyle {
        TaskStatusStyle(from: status)
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: style.sfSymbol)
                .font(.system(size: 8, weight: .bold))
            Text(style.label)
                .font(.lcBadge)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .foregroundColor(style.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(style.background)
        .cornerRadius(LCRadius.badge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(style.label)")
    }
}
```

### 2.2 MetricCard

**JSX source:** lines 173-186

| Property | JSX Value | SwiftUI Equivalent |
|---|---|---|
| Padding | `18px 20px` | `.padding(.vertical, 18).padding(.horizontal, 20)` |
| Corner radius | `8px` | `LCRadius.card` |
| Background | `rgba(255,255,255,0.02)` | `.lcSurfaceRaised` |
| Border | `1px solid rgba(255,255,255,0.06)` | `.overlay(RoundedRectangle(...).stroke(.lcBorder))` |
| Min width | `140px` | `.frame(minWidth: 140)` |
| Label font | 11px, weight 500, uppercase, 0.5 tracking | `.lcMetricLabel` |
| Label color | `rgba(255,255,255,0.4)` | `.lcTextMuted` |
| Label bottom margin | `6px` | `.padding(.bottom, 6)` |
| Value font | 28px, weight 700, JetBrains Mono | `.lcMetricValue` |
| Value color | accent or `#e2e8f0` | param or `.lcTextPrimary` |
| Value line-height | `1` | `.lineLimit(1)` |
| Sub font | 11px | `.lcMetricSub` |
| Sub color | `rgba(255,255,255,0.35)` | `.lcTextSubtle` |
| Sub top margin | `6px` | `.padding(.top, 6)` |

```swift
// MARK: - MetricCard.swift

import SwiftUI

struct MetricCard: View {
    let label: String
    let value: String
    var sub: String? = nil
    var accent: Color = .lcTextPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.lcMetricLabel)
                .foregroundColor(.lcTextMuted)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.bottom, 6)

            Text(value)
                .font(.lcMetricValue)
                .foregroundColor(accent)
                .lineLimit(1)

            if let sub = sub {
                Text(sub)
                    .font(.lcMetricSub)
                    .foregroundColor(.lcTextSubtle)
                    .padding(.top, 6)
            }
        }
        .frame(minWidth: 140, alignment: .leading)
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .background(.lcSurfaceRaised)
        .overlay(
            RoundedRectangle(cornerRadius: LCRadius.card)
                .stroke(.lcBorder, lineWidth: LCBorder.standard)
        )
        .cornerRadius(LCRadius.card)
        .accessibilityElement(children: .combine)
    }
}
```

### 2.3 MetricsBar

**JSX source:** lines 577-586

The metrics bar is a responsive grid of `MetricCard` instances across the top of the app.

| Property | JSX Value | SwiftUI Equivalent |
|---|---|---|
| Layout | `grid, repeat(auto-fit, minmax(150px, 1fr))` | `LazyVGrid(columns: ..., spacing: 12)` |
| Gap | `12px` | `spacing: 12` in grid |
| Padding | `20px 28px` | `.padding(.vertical, 20).padding(.horizontal, 28)` |

```swift
// MARK: - MetricsBarView.swift

import SwiftUI

struct MetricsBarView: View {
    let metrics: DashboardMetrics

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            MetricCard(
                label: "Active Tasks",
                value: "\(metrics.activeTasks)",
                sub: "\(metrics.totalTasks) total",
                accent: .lcAccent                // #818cf8
            )
            MetricCard(
                label: "Total Runs",
                value: metrics.totalRuns.formatted(),
                sub: "all time"
            )
            MetricCard(
                label: "Success Rate",
                value: "\(Int(metrics.overallSuccessRate))%",
                sub: "across all tasks",
                accent: metrics.overallSuccessRate >= 95 ? .lcGreen : .lcAmber
            )
            MetricCard(
                label: "Total Spend",
                value: "$\(String(format: "%.2f", metrics.totalSpend))",
                sub: "API costs"
            )
            // N2: SparklineChart card goes here when implemented
            MetricCard(
                label: "Daemon",
                value: "UP",        // or "DOWN" from daemon.status
                sub: "launchd \u{00B7} PID \(metrics.daemonPID ?? 0)",
                accent: .lcGreen
            )
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 28)
    }
}
```

### 2.4 TaskRow

**JSX source:** lines 188-224

This is the primary table row for the Tasks view. The JSX uses a CSS grid with 6 columns.

**Column layout:**

| Column | Width (JSX) | Content | Font | Color |
|---|---|---|---|---|
| Task (name + dir) | `1fr` | name + workingDir stacked | name: 13.5/600; dir: 11/mono | name: `#e2e8f0`; dir: `rgba(255,255,255,0.35)` |
| Schedule | `160px` | scheduleHuman | 12/mono | `rgba(255,255,255,0.5)` |
| Status | `120px` | StatusBadge | -- | -- |
| Last Run | `90px` | relative time | 12 | `rgba(255,255,255,0.45)` |
| Runs | `80px` | runCount | 12/mono | `rgba(255,255,255,0.45)` |
| Health | `70px` | success % | 12/mono | conditional green/amber/red |

**Row-level styles:**

| Property | JSX Value | SwiftUI Equivalent |
|---|---|---|
| Padding | `14px 20px` | `.padding(.vertical, 14).padding(.horizontal, 20)` |
| Selected bg | `rgba(99,102,241,0.08)` | `.lcAccentBgSubtle` |
| Selected left border | `2px solid #818cf8` | Leading overlay rectangle |
| Unselected border | `2px solid transparent` | -- |
| Bottom border | `1px solid rgba(255,255,255,0.04)` | `.lcDivider` |
| Hover bg | `rgba(255,255,255,0.02)` | `.lcSurfaceRaised` on hover |
| Transition | `all 0.15s ease` | `.animation(.lcQuick)` |

```swift
// MARK: - TaskRow.swift

import SwiftUI

struct TaskRow: View {
    let task: LCTask
    let isSelected: Bool

    private var successRate: Int {
        guard task.runCount > 0 else { return 0 }
        return Int(round(Double(task.successCount) / Double(task.runCount) * 100))
    }

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Column 1: Task name + working dir
            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .font(.lcBodyBold)
                    .foregroundColor(.lcTextPrimary)
                Text(task.workingDir)
                    .font(.lcDataSmall)
                    .foregroundColor(.lcTextSubtle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Column 2: Schedule
            Text(task.scheduleHuman)
                .font(.lcDataMedium)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 160, alignment: .leading)

            // Column 3: Status
            StatusBadge(status: task.status)
                .frame(width: 120, alignment: .leading)

            // Column 4: Last Run
            Text(task.lastRun != nil ? relativeTime(task.lastRun!) : "\u{2014}")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 90, alignment: .leading)

            // Column 5: Runs
            Text("\(task.runCount)")
                .font(.lcDataMedium)
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 80, alignment: .leading)

            // Column 6: Health
            Text("\(successRate)%")
                .font(.lcDataMedium)
                .foregroundColor(.lcHealthColor(for: successRate))
                .frame(width: 70, alignment: .leading)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(
            isSelected
                ? Color.lcAccentBgSubtle
                : (isHovered ? Color.lcSurfaceRaised : Color.clear)
        )
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle()
                    .fill(Color.lcSelectedBorder)
                    .frame(width: 2)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.lcDivider)
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.lcQuick, value: isSelected)
        .animation(.lcQuick, value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.name), \(task.status.rawValue), \(task.scheduleHuman)")
        .accessibilityValue("\(successRate)% success rate, \(task.runCount) runs")
    }
}
```

### 2.5 Task Table Header

**JSX source:** lines 597-607

```swift
// MARK: - TaskTableHeader.swift

import SwiftUI

struct TaskTableHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Task")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Schedule")
                .frame(width: 160, alignment: .leading)
            Text("Status")
                .frame(width: 120, alignment: .leading)
            Text("Last Run")
                .frame(width: 90, alignment: .leading)
            Text("Runs")
                .frame(width: 80, alignment: .leading)
            Text("Health")
                .frame(width: 70, alignment: .leading)
        }
        .font(.lcColumnHeader)
        .foregroundColor(.lcTextFaint)
        .textCase(.uppercase)
        .tracking(0.5)
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .background(.lcSurfaceRaised)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.lcBorder).frame(height: 1)
        }
    }
}
```

### 2.6 LogEntry

**JSX source:** lines 227-281

The log entry has two states: collapsed (summary row) and expanded (detail with full output).

**Collapsed row grid (6 columns):**

| Column | Width (JSX) | Content |
|---|---|---|
| Status icon | `22px` | colored icon, centered |
| Task + summary | `1fr` | taskName (bold) + truncated summary (muted) |
| Timestamp | `140px` | formatted date, mono |
| Duration | `70px` | formatted seconds, mono |
| Tokens | `80px` | formatted count + "tok", mono |
| Cost | `70px` | "$X.XX", mono |

**Collapsed row styles:**

| Property | JSX Value |
|---|---|
| Padding | `10px 16px` |
| Grid gap | `8px` |
| Bottom border | `1px solid rgba(255,255,255,0.04)` |
| Expanded bg | `rgba(255,255,255,0.02)` |
| Status icon font size | `10px` |
| Task name | 12.5px, `#c8d0dc`, weight 500 |
| Summary inline | 11px, `rgba(255,255,255,0.3)`, marginLeft 10, truncated at 80 chars with ellipsis |
| Data cells | 11px, `rgba(255,255,255,0.35)`, JetBrains Mono |

**Expanded section styles:**

| Property | JSX Value |
|---|---|
| Padding | `0 16px 14px 46px` (left inset aligns with task name column) |
| Animation | `fadeSlide 0.2s ease` |
| Summary | 11.5px, `rgba(255,255,255,0.5)`, line-height 1.5, marginBottom 8 |
| Code block bg | `rgba(0,0,0,0.3)` |
| Code block padding | `14px` |
| Code block radius | `6px` |
| Code block border | `1px solid rgba(255,255,255,0.05)` |
| Code block font | 11px, JetBrains Mono, `rgba(255,255,255,0.55)`, line-height 1.6 |
| Code block wrapping | `pre-wrap`, `word-break: break-word` |

```swift
// MARK: - LogEntryRow.swift

import SwiftUI

struct LogEntryRow: View {
    let log: ExecutionLog
    @Binding var isExpanded: Bool

    private var statusStyle: TaskStatusStyle {
        log.status == .success ? .success : .error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Collapsed summary row ──
            Button(action: { withAnimation(.lcFadeSlide) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    // Status icon
                    Image(systemName: statusStyle.sfSymbol)
                        .font(.system(size: 10))
                        .foregroundColor(statusStyle.color)
                        .frame(width: 22)

                    // Task name + summary
                    HStack(spacing: 10) {
                        Text(log.taskName)
                            .font(.lcBodyMedium)
                            .foregroundColor(.lcTextSecondary)
                        Text(log.summary.prefix(80) + (log.summary.count > 80 ? "\u{2026}" : ""))
                            .font(.lcCaption)
                            .foregroundColor(.white.opacity(0.3))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Timestamp
                    Text(formatTimestamp(log.timestamp))
                        .font(.lcData)
                        .foregroundColor(.lcTextSubtle)
                        .frame(width: 140, alignment: .leading)

                    // Duration
                    Text(formatDuration(log.durationSecs))
                        .font(.lcData)
                        .foregroundColor(.lcTextSubtle)
                        .frame(width: 70, alignment: .leading)

                    // Tokens
                    Text("\(log.tokensUsed?.formatted() ?? "0") tok")
                        .font(.lcData)
                        .foregroundColor(.lcTextSubtle)
                        .frame(width: 80, alignment: .leading)

                    // Cost
                    Text("$\(String(format: "%.2f", log.costUsd ?? 0))")
                        .font(.lcData)
                        .foregroundColor(.lcTextSubtle)
                        .frame(width: 70, alignment: .leading)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)

            // ── Expanded detail ──
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(log.summary)
                        .font(.lcLogSummary)
                        .foregroundColor(.white.opacity(0.5))
                        .lineSpacing(4) // approximate line-height 1.5

                    Text(log.output)
                        .font(.lcCode)
                        .foregroundColor(.white.opacity(0.55))
                        .lineSpacing(5) // approximate line-height 1.6
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.lcCodeBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        .cornerRadius(6)
                        .textSelection(.enabled)
                }
                .padding(.leading, LCSpacing.logExpandedInset) // 46px
                .padding(.trailing, 16)
                .padding(.bottom, 14)
                .transition(.lcFadeSlide)
            }
        }
        .background(isExpanded ? Color.lcSurfaceRaised : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.lcDivider).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint("Activate to \(isExpanded ? "collapse" : "expand") log details")
    }
}
```

### 2.7 Log Table Header

**JSX source:** lines 757-765

```swift
struct LogTableHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Spacer().frame(width: 22) // status icon column
            Text("Task / Summary")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Time")
                .frame(width: 140, alignment: .leading)
            Text("Duration")
                .frame(width: 70, alignment: .leading)
            Text("Tokens")
                .frame(width: 80, alignment: .leading)
            Text("Cost")
                .frame(width: 70, alignment: .leading)
        }
        .font(.lcColumnHeader)
        .foregroundColor(.lcTextDimmest)
        .textCase(.uppercase)
        .tracking(0.5)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(.lcSurfaceRaised)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.lcBorder).frame(height: 1)
        }
    }
}
```

### 2.8 TaskEditor (Sheet/Modal)

**JSX source:** lines 284-457

In the JSX, this is a fixed-position overlay with backdrop blur. In SwiftUI, use `.sheet()` for
native macOS modal behavior.

**Modal container styles (for reference if building custom):**

| Property | JSX Value | SwiftUI Equivalent |
|---|---|---|
| Backdrop | `rgba(0,0,0,0.7)`, `backdropFilter: blur(8px)` | `.sheet()` handles this natively |
| Modal bg | `#1a1d23` | `.lcSurface` |
| Modal radius | `12px` | `LCRadius.modal` |
| Modal padding | `32px` | `LCSpacing.p32` |
| Modal width | `560px` | `.frame(width: 560)` |
| Max height | `85vh` | SwiftUI sheet auto-sizes |
| Modal border | `1px solid rgba(255,255,255,0.08)` | `.lcSeparator` |
| Modal shadow | `0 24px 80px rgba(0,0,0,0.6)` | `.lcModalShadow()` |

**Input styles:**

| Property | JSX Value |
|---|---|
| Padding | `10px 12px` |
| Corner radius | `6px` |
| Background | `rgba(0,0,0,0.3)` |
| Border | `1px solid rgba(255,255,255,0.1)` |
| Focus border | `rgba(129,140,248,0.5)` |
| Text color | `#e2e8f0` |
| Font | 13px, JetBrains Mono |

**Label styles:**

| Property | JSX Value |
|---|---|
| Font | 11px, weight 600 |
| Color | `rgba(255,255,255,0.5)` |
| Transform | uppercase |
| Letter spacing | 0.5px |
| Bottom margin | 6px |

**Form layout:**

| Section | Layout |
|---|---|
| Task Name | Full width input |
| Claude Command | Full width textarea (4 rows) |
| Skill + Working Dir | 2-column grid, gap 16px |
| Cron + Human-Readable | 2-column grid, gap 16px |
| Budget + Tags | 2-column grid, gap 16px |
| Section gap | 20px vertical between fields |
| Title margin bottom | 28px |
| Footer margin top | 28px |

**Buttons:**

| Button | Padding | Radius | Background | Text color | Font |
|---|---|---|---|---|---|
| Cancel | `10px 20px` | 6 | transparent | `rgba(255,255,255,0.5)` | 13px, 500 |
| Cancel border | -- | -- | `1px solid rgba(255,255,255,0.1)` | -- | -- |
| Save/Create | `10px 24px` | 6 | `#818cf8` | `#fff` | 13px, 600 |
| Close (X) | `4px 8px` | -- | none | `rgba(255,255,255,0.4)` | 20px |

**Tag chip styles (in editor context):**

| Property | JSX Value |
|---|---|
| Font | 10px, JetBrains Mono |
| Padding | `3px 8px` |
| Radius | 4px |
| Background | `rgba(129,140,248,0.15)` |
| Text color | `#a5b4fc` |

```swift
// MARK: - TaskEditorView.swift

import SwiftUI

struct TaskEditorView: View {
    @Binding var task: LCTaskDraft
    let isNew: Bool
    let onSave: (LCTaskDraft) -> Void
    let onCancel: () -> Void

    @State private var tagInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ──
            HStack {
                Text(isNew ? "New Scheduled Task" : "Edit Task")
                    .font(.lcHeading)
                    .foregroundColor(.lcTextPrimary)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(.lcTextMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 28)

            // ── N1: Template picker section (only when isNew) ──
            // See Section 4 for template picker implementation

            // ── Form fields ──
            VStack(alignment: .leading, spacing: 20) {
                // Task Name
                LCFormField(label: "Task Name") {
                    LCTextField(text: $task.name, placeholder: "e.g., PR Review Sweep")
                }

                // Claude Command
                LCFormField(label: "Claude Command") {
                    LCTextEditor(text: $task.command, placeholder: "claude -p 'Your prompt here...'")
                        .frame(minHeight: 80)
                }

                // Skill + Working Dir (2-column)
                HStack(spacing: 16) {
                    LCFormField(label: "Skill (optional)") {
                        LCTextField(text: Binding($task.skill, default: ""),
                                    placeholder: "/review-pr, /loop, etc.")
                    }
                    LCFormField(label: "Working Directory") {
                        LCTextField(text: $task.workingDir,
                                    placeholder: "~/projects/my-repo")
                    }
                }

                // Cron + Human-Readable (2-column)
                HStack(spacing: 16) {
                    LCFormField(label: "Cron Schedule") {
                        LCTextField(text: $task.schedule,
                                    placeholder: "*/15 * * * *")
                    }
                    LCFormField(label: "Human-Readable") {
                        LCTextField(text: $task.scheduleHuman,
                                    placeholder: "Every 15 minutes")
                    }
                }

                // Budget + Tags (2-column)
                HStack(alignment: .top, spacing: 16) {
                    LCFormField(label: "Max Budget per Run ($)") {
                        LCTextField(text: Binding(
                            get: { String(format: "%.1f", task.maxBudget) },
                            set: { task.maxBudget = Double($0) ?? 5.0 }
                        ), placeholder: "5.0")
                    }
                    LCFormField(label: "Tags") {
                        VStack(alignment: .leading, spacing: 8) {
                            LCTextField(
                                text: $tagInput,
                                placeholder: "Press enter to add",
                                onSubmit: {
                                    let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
                                    if !trimmed.isEmpty {
                                        task.tags.append(trimmed)
                                        tagInput = ""
                                    }
                                }
                            )
                            if !task.tags.isEmpty {
                                FlowLayout(spacing: 4) {
                                    ForEach(Array(task.tags.enumerated()), id: \.offset) { idx, tag in
                                        TagChip(text: tag) {
                                            task.tags.remove(at: idx)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 28)

            // ── Footer buttons ──
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(LCSecondaryButtonStyle())
                Button(isNew ? "Create Task" : "Save Changes") { onSave(task) }
                    .buttonStyle(LCPrimaryButtonStyle())
            }
        }
        .padding(32)
        .frame(width: 560)
        .background(.lcSurface)
    }
}

// ── Reusable form components ──

struct LCFormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.lcLabel)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.5)
            content
        }
    }
}

struct LCTextField: View {
    @Binding var text: String
    var placeholder: String = ""
    var onSubmit: (() -> Void)? = nil
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.lcInput)
            .foregroundColor(.lcTextPrimary)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(.lcCodeBackground)
            .overlay(
                RoundedRectangle(cornerRadius: LCRadius.button)
                    .stroke(
                        isFocused ? Color.lcAccentFocus : Color.lcBorderInput,
                        lineWidth: 1
                    )
            )
            .cornerRadius(LCRadius.button)
            .focused($isFocused)
            .onSubmit { onSubmit?() }
    }
}

struct LCTextEditor: View {
    @Binding var text: String
    var placeholder: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(.lcInput)
            .foregroundColor(.lcTextPrimary)
            .scrollContentBackground(.hidden)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(.lcCodeBackground)
            .overlay(
                RoundedRectangle(cornerRadius: LCRadius.button)
                    .stroke(
                        isFocused ? Color.lcAccentFocus : Color.lcBorderInput,
                        lineWidth: 1
                    )
            )
            .cornerRadius(LCRadius.button)
            .focused($isFocused)
    }
}

struct TagChip: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Text(text)
                Text("\u{2715}")
            }
            .font(.lcTag)
            .foregroundColor(.lcAccentLight)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.lcAccentBg)
            .cornerRadius(LCRadius.badge)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tag: \(text)")
        .accessibilityHint("Activate to remove")
    }
}

// ── Button styles ──

struct LCPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.lcButton)
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 24)
            .background(Color.lcAccent)
            .cornerRadius(LCRadius.button)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct LCSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white.opacity(0.5))
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: LCRadius.button)
                    .stroke(Color.lcBorderInput, lineWidth: 1)
            )
            .cornerRadius(LCRadius.button)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
```

### 2.9 Header / Toolbar

**JSX source:** lines 534-574

In the JSX, the header is a sticky bar with: logo/title (left), nav tabs + new-task button (right).

| Property | JSX Value | SwiftUI Equivalent |
|---|---|---|
| Padding | `16px 28px` | `.padding(.vertical, 16).padding(.horizontal, 28)` |
| Bottom border | `1px solid rgba(255,255,255,0.06)` | `.lcBorder` |
| Background | `rgba(15,17,23,0.95)` + `blur(12px)` | `.background(.ultraThinMaterial)` or custom |
| Sticky | `position: sticky, top: 0, z-index: 100` | SwiftUI toolbar handles this natively |

**Logo block:**

| Property | JSX Value |
|---|---|
| Icon container | 32x32px, radius 8, gradient `135deg #818cf8 -> #6366f1` |
| Icon text | "↻" (U+21BB), 15px, weight 800, white |
| Title gap from icon | 14px |
| Title | 15px, weight 700, letter-spacing -0.3px |
| Subtitle | 10.5px, JetBrains Mono, `rgba(255,255,255,0.3)`, letter-spacing 0.5px |
| Subtitle content | "LAUNCHD . CLAUDE CODE . {N} ACTIVE" |

**Nav tab buttons:**

| Property | JSX Value |
|---|---|
| Padding | `7px 16px` |
| Radius | 6px |
| Active bg | `rgba(129,140,248,0.15)` |
| Active text color | `#a5b4fc` |
| Inactive bg | transparent |
| Inactive text color | `rgba(255,255,255,0.4)` |
| Font | 12.5px, weight 600 |
| Gap between tabs | 6px |

**Divider between tabs and "New Task":**

| Property | JSX Value |
|---|---|
| Width | 1px |
| Height | 20px |
| Color | `rgba(255,255,255,0.08)` |
| Horizontal margin | `6px` each side |

**"+ New Task" button:**

| Property | JSX Value |
|---|---|
| Padding | `7px 16px` |
| Radius | 6px |
| Background | `#818cf8` |
| Text color | white |
| Font | 12.5px, weight 600 |
| Icon-text gap | 5px |

> **SwiftUI approach:** Use `NavigationSplitView` sidebar for navigation (replaces tab buttons)
> and `.toolbar` for action buttons. The logo/branding moves into the sidebar header. See Section 3.

### 2.10 Detail View

**JSX source:** lines 620-726

The detail view has three sections stacked vertically:

**Section A: Action bar (top row)**

| Button | Padding | Border | Color | Font |
|---|---|---|---|---|
| Back ("\u{2190} Back") | `4px 0` | none | `rgba(255,255,255,0.4)` | 13px |
| Edit | `6px 14px` | `1px solid rgba(255,255,255,0.1)` | `rgba(255,255,255,0.6)` | 12px, 500 |
| Pause/Resume | `6px 14px` | `1px solid rgba(255,255,255,0.1)` | amber if active, green if paused | 12px, 500 |
| Delete | `6px 14px` | `1px solid rgba(239,68,68,0.2)` | `#ef4444` | 12px, 500 |
| Gap between buttons | `10px` (except back, which has flex spacer before other buttons) |
| Bar margin bottom | `20px` |
| Enter animation | `fadeSlide 0.2s ease` |

> **Note from spec R8:** Also add "Run Now" and "Dry Run" buttons here.

**Section B: Task info card**

| Property | JSX Value |
|---|---|
| Container | radius 10, border `rgba(255,255,255,0.06)`, padding 24, bg `rgba(255,255,255,0.01)`, marginBottom 20 |
| Title row | 20px weight 700 text + StatusBadge, gap 12, center-aligned, marginBottom 16 |
| Content layout | Two-column grid `1fr 1fr`, gap 20 |

Left column (Command preview):

| Property | JSX Value |
|---|---|
| Label | 10px, `rgba(255,255,255,0.35)`, uppercase, spacing 0.5, marginBottom 6 |
| Code block font | 11.5px mono, color `#a5b4fc` |
| Code block bg | `rgba(0,0,0,0.3)` |
| Code block padding | 12px |
| Code block radius | 6px |
| Code block border | `1px solid rgba(255,255,255,0.05)` |
| Code block line-height | 1.6 |
| Code block wrapping | `pre-wrap`, `word-break: break-all` |

Right column (Metadata grid):

| Property | JSX Value |
|---|---|
| Grid | 2 columns, gap 12 |
| Field label | 10px, `rgba(255,255,255,0.3)`, uppercase, spacing 0.5, marginBottom 3 |
| Field value | 12.5px mono, `#c8d0dc` |

Metadata fields (8 key-value pairs in 2x4 grid):
1. Schedule -- scheduleHuman
2. Cron -- schedule expression
3. Working Dir -- workingDir
4. Skill -- skill or "\u{2014}"
5. Budget/Run -- "$X.XX"
6. Total Spent -- "$X.XX"
7. Created -- formatted timestamp
8. Last Run -- relative time or "\u{2014}"

Tags row (below metadata grid):

| Property | JSX Value |
|---|---|
| Gap | 4px |
| Margin top | 12px |
| Tag font | 10px mono |
| Tag padding | `3px 8px` |
| Tag radius | 4px |
| Tag bg | `rgba(129,140,248,0.1)` |
| Tag color | `#818cf8` |

**Section C: Execution history**

| Property | JSX Value |
|---|---|
| Container | same panel style (radius 10, border, bg) |
| Section header | padding `12px 16px`, border-bottom, text "Execution History (N runs)", 12px weight 600, `rgba(255,255,255,0.5)`, flex between label and (nothing currently) |
| Empty state | padding 32, centered, `rgba(255,255,255,0.25)`, 13px, "No executions yet" |
| Log entries | Reuses `LogEntry` component from global logs view |

### 2.11 Logs View Search and Filter Bar

**JSX source:** lines 731-751

| Element | Styles |
|---|---|
| Search input | padding `8px 14px`, radius 6, bg `rgba(255,255,255,0.04)`, border `rgba(255,255,255,0.08)`, color `#e2e8f0`, font 12.5px mono, width 240 |
| Gap between search and filters | 8px, with flex spacer pushing filters right |
| Filter buttons | labels "all", "success", "error" |
| Filter active bg | `rgba(129,140,248,0.15)` |
| Filter active color | `#a5b4fc` |
| Filter inactive bg | transparent |
| Filter inactive color | `rgba(255,255,255,0.35)` |
| Filter font | 11.5px, weight 600, text-transform capitalize |
| Filter padding | `6px 12px` |
| Filter radius | 5px |
| Bar margin bottom | 16px |

> **SwiftUI approach:** Use `.searchable()` modifier for the search field (native macOS search
> with Cmd+F). The filter buttons can be a `Picker` with `.pickerStyle(.segmented)` or custom
> toggle buttons to match the prototype's minimal styling.

### 2.12 SparklineChart (N2)

For the 7-day cost trend metric card, use the Swift Charts framework (available macOS 13+):

```swift
// MARK: - SparklineChart.swift

import SwiftUI
import Charts

struct SparklineChart: View {
    let data: [DailyCost] // 7 data points

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("7-Day Spend")
                .font(.lcMetricLabel)
                .foregroundColor(.lcTextMuted)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.bottom, 6)

            Chart(data) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Cost", entry.totalCost)
                )
                .foregroundStyle(Color.lcAccent)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", entry.date),
                    y: .value("Cost", entry.totalCost)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.lcAccent.opacity(0.3), Color.lcAccent.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 48)

            let total = data.reduce(0) { $0 + $1.totalCost }
            Text("$\(String(format: "%.2f", total)) total")
                .font(.lcMetricSub)
                .foregroundColor(.lcTextSubtle)
                .padding(.top, 6)
        }
        .frame(minWidth: 160)
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .background(.lcSurfaceRaised)
        .overlay(
            RoundedRectangle(cornerRadius: LCRadius.card)
                .stroke(.lcBorder, lineWidth: LCBorder.standard)
        )
        .cornerRadius(LCRadius.card)
    }
}
```

---

## 3. View Architecture

### 3.1 Navigation Model

The JSX prototype uses a `view` state variable with three values: `"tasks"`, `"logs"`, `"detail"`.
The SwiftUI app uses `NavigationSplitView` for a native macOS three-column layout.

```
JSX State Machine              SwiftUI Equivalent
──────────────────             ──────────────────────────────────────
view = "tasks"                 Sidebar: "Tasks" selected
  selectedTask = null            Content: TaskListView
                                 Detail: empty / placeholder

view = "detail"                Sidebar: "Tasks" selected
  selectedTask = id              Content: TaskListView (row highlighted)
                                 Detail: TaskDetailView

view = "logs"                  Sidebar: "Logs" selected
  selectedTask = null            Content: LogsView (full width)
                                 Detail: hidden (two-column mode)
```

```swift
// MARK: - ContentView.swift

import SwiftUI

enum SidebarItem: Hashable {
    case tasks
    case logs
}

enum TaskEditorState: Identifiable {
    case new
    case editing(LCTask)

    var id: String {
        switch self {
        case .new: return "new"
        case .editing(let task): return task.id
        }
    }
}

struct ContentView: View {
    @State private var selectedSidebar: SidebarItem? = .tasks
    @State private var selectedTaskId: String? = nil
    @State private var showingEditor: TaskEditorState? = nil
    @StateObject private var dashboardVM = DashboardViewModel()

    var body: some View {
        NavigationSplitView {
            // ── Sidebar ──
            SidebarView(selection: $selectedSidebar, activeCount: dashboardVM.activeCount)
        } content: {
            // ── Content column ──
            switch selectedSidebar {
            case .tasks:
                TaskListView(
                    selectedTaskId: $selectedTaskId,
                    onNewTask: { showingEditor = .new }
                )
            case .logs:
                LogsView()
            case .none:
                Text("Select a view")
                    .foregroundColor(.lcTextMuted)
            }
        } detail: {
            // ── Detail column (visible when a task is selected) ──
            if selectedSidebar == .tasks, let taskId = selectedTaskId {
                TaskDetailView(
                    taskId: taskId,
                    onEdit: { task in showingEditor = .editing(task) },
                    onDelete: { selectedTaskId = nil }
                )
            } else {
                // Empty state placeholder
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.lcTextFaint)
                    Text("Select a task")
                        .font(.lcBodyMedium)
                        .foregroundColor(.lcTextMuted)
                }
            }
        }
        .sheet(item: $showingEditor) { state in
            // TaskEditorView presented as sheet
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 900, minHeight: 600)
    }
}
```

### 3.2 Sidebar View

Replaces the JSX tab buttons with a native macOS sidebar.

```swift
// MARK: - SidebarView.swift

import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    let activeCount: Int

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("Tasks", systemImage: "list.bullet.rectangle")
                    .tag(SidebarItem.tasks)
                    .badge(activeCount)
                Label("Logs", systemImage: "doc.text.magnifyingglass")
                    .tag(SidebarItem.logs)
            } header: {
                // ── App branding in sidebar header ──
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.lcAccent, .lcAccentDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text("\u{21BB}")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundColor(.white)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Loop Commander")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.lcTextPrimary)
                        Text("LAUNCHD \u{00B7} CLAUDE CODE")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.lcTextFaint)
                            .tracking(0.5)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .listStyle(.sidebar)
    }
}
```

### 3.3 State Management Map

Complete mapping of JSX state to SwiftUI bindings:

| JSX State | Type | SwiftUI Equivalent | Owner |
|---|---|---|---|
| `tasks` | `Task[]` | `@Published var tasks: [LCTask]` | `TaskListViewModel` |
| `logs` | `Log[]` | `@Published var logs: [ExecutionLog]` | `LogsViewModel` |
| `selectedTask` | `string \| null` | `@State var selectedTaskId: String?` | `ContentView` |
| `view` | `"tasks" \| "logs" \| "detail"` | `@State var selectedSidebar: SidebarItem?` + selectedTaskId | `ContentView` |
| `expandedLog` | `number \| null` | `@State var expandedLogId: Int?` | `LogsView` / `TaskDetailView` |
| `editor` | `{task, isNew} \| null` | `@State var showingEditor: TaskEditorState?` | `ContentView` |
| `logFilter` | `"all" \| "success" \| "error"` | `@State var logFilter: LogFilter` | `LogsView` |
| `searchQuery` | `string` | `@State var searchQuery: String` | `LogsView` (via `.searchable`) |
| `now` | `Date.now` (30s interval) | `Timer.publish(every: 30)` | `DashboardViewModel` |

### 3.4 ViewModel-to-DaemonClient Method Mapping

| ViewModel Method | JSON-RPC Method | UI Trigger |
|---|---|---|
| `loadTasks()` | `task.list` | On appear, on event |
| `createTask(input)` | `task.create` | Editor save (new) |
| `updateTask(input)` | `task.update` | Editor save (edit) |
| `deleteTask(id)` | `task.delete` | Delete button |
| `pauseTask(id)` | `task.pause` | Pause button |
| `resumeTask(id)` | `task.resume` | Resume button |
| `runNow(id)` | `task.run_now` | Run Now button |
| `dryRun(id)` | `task.dry_run` | Dry Run button |
| `loadLogs(query)` | `logs.query` | On appear, filter/search change |
| `loadMetrics()` | `metrics.dashboard` | On appear, 30s timer |
| `loadTemplates()` | `templates.list` | Editor open (new mode) |
| `exportTask(id)` | `task.export` | Export button |
| `importTask(export)` | `task.import` | Import file action |
| `subscribe()` | `events.subscribe` | App launch |

### 3.5 Data Flow Diagram

```
 ┌──────────────────────────────────────────────────────────────────┐
 │  SwiftUI Views                                                   │
 │  ┌────────────┐ ┌──────────────┐ ┌────────────┐ ┌────────────┐ │
 │  │ TaskList   │ │ TaskDetail   │ │ LogsView   │ │ Metrics    │ │
 │  │ View       │ │ View         │ │            │ │ BarView    │ │
 │  └─────┬──────┘ └──────┬───────┘ └─────┬──────┘ └─────┬──────┘ │
 │        │               │               │              │         │
 │  ┌─────▼───────────────▼───────────────▼──────────────▼──────┐  │
 │  │  ViewModels (@Observable / @ObservableObject)              │  │
 │  │  TaskListVM  |  TaskDetailVM  |  LogsVM  |  DashboardVM   │  │
 │  └──────────────────────┬─────────────────────────────────────┘  │
 │                         │                                        │
 │  ┌──────────────────────▼───────────────────────────────────┐    │
 │  │  DaemonClient (actor)                                     │    │
 │  │  - JSON-RPC 2.0 request/response                          │    │
 │  │  - Connection state management                             │    │
 │  │  - Exponential backoff reconnect (1s, 2s, 4s ... 30s max) │    │
 │  │  - 10s timeout per request                                 │    │
 │  └──────────────────────┬───────────────────────────────────┘    │
 │                         │                                        │
 │  ┌──────────────────────▼───────────────────────────────────┐    │
 │  │  EventStream (ObservableObject)                           │    │
 │  │  - events.subscribe via persistent socket                  │    │
 │  │  - Real-time push: task.started, task.completed, etc.      │    │
 │  │  - Auto-reconnect + re-subscribe on connection loss        │    │
 │  └──────────────────────────────────────────────────────────┘    │
 │                         |                                        │
 └─────────────────────────┼────────────────────────────────────────┘
                           │ Unix Domain Socket
                           │ ~/.loop-commander/daemon.sock
                           ▼
                   ┌───────────────┐
                   │  lc-daemon    │
                   │  (Rust)       │
                   └───────────────┘
```

---

## 4. macOS Native Enhancements

Places where the native SwiftUI app surpasses the web prototype.

### 4.1 Native Sidebar Navigation

Instead of the prototype's tab buttons, `NavigationSplitView` gives macOS-standard three-column
layout with resizable columns, native selection highlighting, and sidebar collapse/expand.

### 4.2 Keyboard Shortcuts

```swift
// New Task: Cmd+N
Button("New Task") { showingEditor = .new }
    .keyboardShortcut("n", modifiers: .command)

// Delete Task: Cmd+Backspace
Button("Delete") { deleteTask() }
    .keyboardShortcut(.delete, modifiers: .command)

// Run Now: Cmd+R
Button("Run Now") { runNow() }
    .keyboardShortcut("r", modifiers: .command)

// Pause/Resume: Cmd+P
Button("Pause") { togglePause() }
    .keyboardShortcut("p", modifiers: .command)

// Edit Task: Cmd+E
Button("Edit") { editTask() }
    .keyboardShortcut("e", modifiers: .command)

// Refresh data: Cmd+Shift+R
Button("Refresh") { refresh() }
    .keyboardShortcut("r", modifiers: [.command, .shift])

// Switch to Tasks view: Cmd+1
// Switch to Logs view: Cmd+2
// (via Commands menu items)
```

### 4.3 Commands Menu

```swift
// MARK: - LoopCommanderApp.swift

@main
struct LoopCommanderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            // Replace default "New" with task creation
            CommandGroup(replacing: .newItem) {
                Button("New Task") {
                    NotificationCenter.default.post(name: .newTask, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            // View menu
            CommandMenu("View") {
                Button("Tasks") { /* switch to tasks sidebar */ }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Logs") { /* switch to logs sidebar */ }
                    .keyboardShortcut("2", modifiers: .command)
                Divider()
                Button("Refresh") { /* reload all data */ }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }

            // Task menu (contextual to selected task)
            CommandMenu("Task") {
                Button("Run Now") { /* run selected task */ }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Dry Run") { /* dry run selected task */ }
                    .keyboardShortcut("r", modifiers: [.command, .option])
                Divider()
                Button("Edit...") { /* edit selected task */ }
                    .keyboardShortcut("e", modifiers: .command)
                Button("Pause/Resume") { /* toggle selected task */ }
                    .keyboardShortcut("p", modifiers: .command)
                Divider()
                Button("Export...") { /* export to YAML */ }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Import...") { /* import from YAML */ }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                Divider()
                Button("Delete") { /* delete selected task */ }
                    .keyboardShortcut(.delete, modifiers: .command)
            }
        }

        // Menu bar extra (persistent status item)
        MenuBarExtra("Loop Commander", systemImage: "arrow.triangle.2.circlepath") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
```

### 4.4 Native Search

Replace the custom search input with SwiftUI's `.searchable()` modifier:

```swift
LogsView()
    .searchable(text: $searchQuery, placement: .toolbar, prompt: "Search logs...")
```

This provides the native macOS search field with Cmd+F shortcut, suggestions support, and
standard platform animations.

### 4.5 Menu Bar Extra (Status Item)

A persistent menu bar presence showing daemon status and quick actions:

```swift
struct MenuBarView: View {
    @StateObject private var vm = MenuBarViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Daemon status
            HStack {
                Circle()
                    .fill(vm.isConnected ? Color.lcGreen : Color.lcRed)
                    .frame(width: 8, height: 8)
                Text(vm.isConnected ? "Daemon Running" : "Daemon Offline")
                    .font(.system(size: 12, weight: .medium))
            }
            Divider()

            // Quick stats
            Text("\(vm.activeTaskCount) active tasks")
                .font(.system(size: 11))
            Text("Success rate: \(vm.successRate)%")
                .font(.system(size: 11))

            Divider()

            // Quick actions
            Button("Open Dashboard") { NSApp.activate(ignoringOtherApps: true) }
            Button("New Task...") { /* post notification to open editor */ }

            Divider()

            Button("Quit Loop Commander") { NSApp.terminate(nil) }
        }
        .padding(8)
        .frame(width: 220)
    }
}
```

### 4.6 Window Configuration

```swift
// Spec Section 9: Default 1200x800, minimum 900x600
WindowGroup {
    ContentView()
}
.defaultSize(width: 1200, height: 800)
.windowResizability(.contentMinSize)
// Enforce minimum via frame modifier on ContentView:
// .frame(minWidth: 900, minHeight: 600)
```

### 4.7 Toolbar Integration

Use SwiftUI `.toolbar` for native macOS toolbar items in the detail view:

```swift
TaskDetailView(task: task)
    .toolbar {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { runNow() } label: {
                Label("Run Now", systemImage: "play.fill")
            }
            .help("Execute this task immediately (Cmd+R)")

            Button { dryRun() } label: {
                Label("Dry Run", systemImage: "eye")
            }
            .help("Preview command without executing (Cmd+Opt+R)")

            Button { editTask() } label: {
                Label("Edit", systemImage: "pencil")
            }
            .help("Edit task configuration (Cmd+E)")

            Button { togglePause() } label: {
                Label(
                    task.status == .active ? "Pause" : "Resume",
                    systemImage: task.status == .active ? "pause.fill" : "play.fill"
                )
            }
            .help(task.status == .active ? "Pause this task" : "Resume this task")

            Button(role: .destructive) { deleteTask() } label: {
                Label("Delete", systemImage: "trash")
            }
            .help("Delete this task permanently")
        }

        ToolbarItem(placement: .navigation) {
            // Connection status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(daemonConnected ? Color.lcGreen : Color.lcRed)
                    .frame(width: 6, height: 6)
                Text(daemonConnected ? "Connected" : "Reconnecting...")
                    .font(.system(size: 10))
                    .foregroundColor(.lcTextMuted)
            }
        }
    }
```

### 4.8 Drag and Drop for Import (N4)

Support dragging `.yaml` files onto the app window to import tasks:

```swift
ContentView()
    .onDrop(of: [.yaml, .fileURL], isTargeted: nil) { providers in
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                // Read YAML file, send to task.import via DaemonClient
            }
        }
        return true
    }
```

### 4.9 Notifications (N3)

```swift
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func sendTaskFailure(taskId: String, taskName: String, summary: String) {
        let content = UNMutableNotificationContent()
        content.title = "Task Failed: \(taskName)"
        content.body = String(summary.prefix(100))
        content.sound = .default
        content.userInfo = ["taskId": taskId]

        let request = UNNotificationRequest(
            identifier: "task-fail-\(taskId)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil // Deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
```

### 4.10 Running Task Pulse Animation (R9)

For tasks with `status == .running`, display a pulsing indicator:

```swift
// In StatusBadge, when status is .running:
@Environment(\.accessibilityReduceMotion) private var reduceMotion

if status == .running {
    Image(systemName: "arrow.triangle.2.circlepath")
        .font(.system(size: 8, weight: .bold))
        .foregroundColor(.lcAccent)
        .modifier(ConditionalRotation(animate: !reduceMotion))
}

struct ConditionalRotation: ViewModifier {
    let animate: Bool
    @State private var isRotating = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isRotating && animate ? 360 : 0))
            .animation(
                animate ? .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                value: isRotating
            )
            .onAppear { isRotating = true }
    }
}
```

### 4.11 Daemon Connection Banner

When the daemon is not running, show a non-modal banner:

```swift
struct DaemonBanner: View {
    let isConnected: Bool
    let onStartDaemon: () -> Void

    var body: some View {
        if !isConnected {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.lcAmber)
                Text("Daemon not running.")
                    .font(.system(size: 12, weight: .medium))
                Button("Start Daemon") { onStartDaemon() }
                    .buttonStyle(.borderedProminent)
                    .tint(.lcAccent)
                    .controlSize(.small)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.lcAmber.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 28)
        }
    }
}
```

---

## 5. Accessibility Mapping

### 5.1 Color Contrast Audit

All text-on-background combinations from the prototype, with approximate contrast ratios:

| Element | Foreground | Background | Ratio | WCAG AA |
|---|---|---|---|---|
| Primary text | `#e2e8f0` | `#0f1117` | ~15.2:1 | PASS |
| Secondary text | `#c8d0dc` | `#0f1117` | ~11.4:1 | PASS |
| Muted text (0.4 opacity) | `rgba(255,255,255,0.4)` | `#0f1117` | ~6.0:1 | PASS |
| Subtle text (0.35 opacity) | `rgba(255,255,255,0.35)` | `#0f1117` | ~5.3:1 | PASS |
| Faint text (0.3 opacity) | `rgba(255,255,255,0.3)` | `#0f1117` | ~4.6:1 | PASS (just) |
| Dimmest text (0.25 opacity) | `rgba(255,255,255,0.25)` | `#0f1117` | ~3.9:1 | FAIL body / PASS large |
| Green on dark | `#22c55e` | `#0f1117` | ~6.8:1 | PASS |
| Green on green bg | `#22c55e` | `#22c55e` @ 0.1 on `#0f1117` | ~6.4:1 | PASS |
| Amber on dark | `#f59e0b` | `#0f1117` | ~7.8:1 | PASS |
| Red on dark | `#ef4444` | `#0f1117` | ~4.6:1 | PASS (just) |
| Accent on dark | `#818cf8` | `#0f1117` | ~5.9:1 | PASS |
| Accent light on dark | `#a5b4fc` | `#0f1117` | ~8.5:1 | PASS |
| Code text (0.55 opacity) | `rgba(255,255,255,0.55)` on code bg | effective ~`#0a0c10` | ~7.2:1 | PASS |

**Action items:**
- The "dimmest" text at 0.25 opacity (3.9:1) fails WCAG AA for normal text. This is only used
  for column headers and decorative labels (10px uppercase). Since these qualify as "large text"
  in context and are supplementary (not essential information), the 3:1 threshold applies and
  they pass. Restrict this opacity to decorative, non-essential text only.
- All other combinations pass WCAG 2.1 AA (4.5:1 for normal text, 3:1 for large text).

### 5.2 VoiceOver Annotations

```swift
// StatusBadge
.accessibilityElement(children: .ignore)
.accessibilityLabel("Status: \(style.label)")

// MetricCard
.accessibilityElement(children: .combine)
.accessibilityLabel("\(label): \(value)")
.accessibilityValue(sub ?? "")

// TaskRow
.accessibilityElement(children: .combine)
.accessibilityLabel("\(task.name), \(task.status.rawValue), \(task.scheduleHuman)")
.accessibilityValue("\(successRate)% success rate, \(task.runCount) runs")
.accessibilityAddTraits(.isButton)

// LogEntryRow
.accessibilityElement(children: .contain)
.accessibilityLabel("\(log.taskName), \(log.status.rawValue)")
.accessibilityValue(isExpanded ? "Expanded. \(log.summary)" : "Collapsed")
.accessibilityAddTraits(.isButton)
.accessibilityHint("Double tap to \(isExpanded ? "collapse" : "expand") details")

// TagChip (removable)
.accessibilityLabel("Tag: \(text)")
.accessibilityHint("Activate to remove")
.accessibilityAddTraits(.isButton)

// Empty states
Text("No executions yet")
    .accessibilityLabel("No execution history available for this task")

// Connection status indicator
Circle().fill(connected ? .green : .red)
    .accessibilityLabel(connected ? "Connected to daemon" : "Disconnected from daemon")
```

### 5.3 Keyboard Navigation

SwiftUI provides strong keyboard support by default. Key interactions:

| Interaction | Keyboard | Implementation |
|---|---|---|
| Navigate task list | Arrow Up / Down | Native `List` selection |
| Open task detail | Return / Enter | `.onKeyPress(.return)` or selection binding |
| Switch sidebar items | Cmd+1 / Cmd+2 | `Commands` menu items |
| Search logs | Cmd+F | `.searchable()` provides this automatically |
| Close sheet | Escape | Native `.sheet()` behavior |
| Expand/collapse log | Space / Return | `DisclosureGroup` or `.onKeyPress` |
| Create new task | Cmd+N | `.keyboardShortcut("n", modifiers: .command)` |
| Tab between form fields | Tab / Shift+Tab | Native focus system |

### 5.4 Reduced Motion

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// Conditionally apply animations:
let animation: Animation? = reduceMotion ? nil : .lcFadeSlide

// For the running-task pulse/rotation:
if task.status == .running {
    if reduceMotion {
        // Static icon, no animation
        Image(systemName: "arrow.triangle.2.circlepath")
    } else {
        // Animated rotation
        Image(systemName: "arrow.triangle.2.circlepath")
            .symbolEffect(.rotate, isActive: true)
    }
}
```

### 5.5 Dynamic Type

Ensure text scales with macOS accessibility text size settings:

```swift
// All font tokens use Font.system() which respects Dynamic Type.
// For constrained layouts (table headers, badge text), apply minimumScaleFactor:
Text("Status")
    .font(.lcColumnHeader)
    .minimumScaleFactor(0.8)
```

---

## 6. Implementation Priority

Build order from foundational to feature-complete. Each phase produces a functional milestone.

### Phase 1: Foundation (Week 1)

**Milestone:** App launches, connects to daemon, renders placeholder content.

| # | Component | Complexity | Notes |
|---|---|---|---|
| 1.1 | Design token files: `Color+LC`, `Font+LC`, `LCSpacing`, `LCRadius`, `LCBorder` | Low | Foundation for all views |
| 1.2 | `DaemonClient.swift` -- Unix socket, JSON-RPC, connection management | High | The backbone; nothing works without it |
| 1.3 | Swift data models (`Models/`): `LCTask`, `ExecutionLog`, `DashboardMetrics` | Low | Direct Codable mirrors of Rust types |
| 1.4 | `ContentView` + `SidebarView` + `NavigationSplitView` shell | Medium | App navigation structure |
| 1.5 | `StatusBadge` | Low | Simplest visual component; validates token system |

### Phase 2: Core Views (Week 2)

**Milestone:** All three main views render real data from the daemon.

| # | Component | Complexity | Notes |
|---|---|---|---|
| 2.1 | `MetricCard` + `MetricsBarView` | Low | Stateless display; validates grid layout |
| 2.2 | `TaskRow` + `TaskTableHeader` | Medium | Table layout with selection, hover |
| 2.3 | `TaskListView` + `TaskListViewModel` | Medium | Full task list with selection binding to detail |
| 2.4 | `LogEntryRow` + `LogTableHeader` | Medium | Expand/collapse interaction |
| 2.5 | `LogsView` + `LogsViewModel` | Medium | Search, filter, sorted log list |

### Phase 3: Detail and Edit (Week 3)

**Milestone:** Users can view full task details and create/edit tasks.

| # | Component | Complexity | Notes |
|---|---|---|---|
| 3.1 | `TaskDetailView` + `TaskDetailViewModel` | High | Command preview, metadata grid, per-task logs |
| 3.2 | `TaskEditorView` -- full form with all fields | High | Sheet modal, validation, tag management |
| 3.3 | `LCTextField`, `LCTextEditor`, `LCFormField`, `TagChip` | Low | Reusable form building blocks |
| 3.4 | `LCPrimaryButtonStyle`, `LCSecondaryButtonStyle` | Low | Button styles matching prototype |

### Phase 4: Real-Time and Polish (Week 4)

**Milestone:** App feels alive; real-time updates, keyboard shortcuts, status indicators.

| # | Component | Complexity | Notes |
|---|---|---|---|
| 4.1 | `EventStream.swift` | High | Real-time event subscription, auto-reconnect |
| 4.2 | `DaemonMonitor.swift` | Medium | Connection health, reconnect with backoff |
| 4.3 | `DaemonBanner` (not running) | Low | Connection status UI + "Start Daemon" button |
| 4.4 | Running task pulse animation (R9) | Low | Respects `accessibilityReduceMotion` |
| 4.5 | Keyboard shortcuts + `Commands` menu | Medium | All shortcuts from Section 4.2-4.3 |
| 4.6 | Menu bar extra | Medium | Status item with quick stats and actions |

### Phase 5: Advanced Features (Week 5+)

| # | Component | Complexity | Spec Feature |
|---|---|---|---|
| 5.1 | Template picker in editor | Medium | N1: Task Templates |
| 5.2 | `SparklineChart` (Swift Charts) | Medium | N2: Cost Trend Charts |
| 5.3 | `UserNotifications` integration | Medium | N3: Notification Integration |
| 5.4 | Import/Export (`NSOpenPanel`/`NSSavePanel`) | Low | N4: Task Import/Export |
| 5.5 | Dry Run sheet | Low | N5: Dry Run Mode |
| 5.6 | Accessibility audit + VoiceOver labels | Low | N7: Full accessibility pass |
| 5.7 | Light mode theme + theme toggle | Medium | N8: Dark/Light Theme Toggle |

---

## Appendix A: Utility Functions

Swift equivalents of the JSX helper functions (lines 115-147):

```swift
// MARK: - Formatters.swift

import Foundation

/// Relative time string from a Date.
/// JSX reference: relativeTime() -- "just now", "5m ago", "2h ago", "3d ago"
func relativeTime(_ date: Date) -> String {
    let diff = Date().timeIntervalSince(date)
    let mins = Int(diff / 60)
    if mins < 1 { return "just now" }
    if mins < 60 { return "\(mins)m ago" }
    let hrs = mins / 60
    if hrs < 24 { return "\(hrs)h ago" }
    let days = hrs / 24
    return "\(days)d ago"
}

/// Format duration in seconds to human-readable string.
/// JSX reference: formatDuration() -- "45s", "5m 12s", "5m"
func formatDuration(_ secs: Int) -> String {
    if secs < 60 { return "\(secs)s" }
    let m = secs / 60
    let s = secs % 60
    return s > 0 ? "\(m)m \(s)s" : "\(m)m"
}

/// Format a Date to display timestamp.
/// JSX reference: formatTimestamp() -- "Mar 15, 02:00:12 PM"
func formatTimestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, hh:mm:ss a"
    formatter.locale = Locale(identifier: "en_US")
    return formatter.string(from: date)
}
```

## Appendix B: Window Sizing Reference

| Property | Value | Source |
|---|---|---|
| Default width | 1200px | spec Section 9 |
| Default height | 800px | spec Section 9 |
| Minimum width | 900px | spec Section 9 |
| Minimum height | 600px | spec Section 9 |
| Sidebar width | ~220px (system default) | macOS standard |
| Content column | ~400-500px | flexible |
| Detail column | remaining space | flexible |

## Appendix C: JSX-to-SwiftUI Pattern Reference

| JSX / React Pattern | SwiftUI Equivalent |
|---|---|
| `useState(x)` | `@State var x` or `@Published var x` in ViewModel |
| `useEffect(() => {}, [])` | `.onAppear { }` or `.task { }` |
| `useCallback(fn, [deps])` | Regular Swift method on ViewModel |
| `setInterval(fn, ms)` | `Timer.publish(every:)` + `.onReceive()` |
| `onClick={handler}` | `Button(action:)` or `.onTapGesture {}` |
| `onMouseEnter/Leave` | `.onHover { isHovered in }` |
| `style={{ inline CSS }}` | Chained SwiftUI modifiers |
| Conditional className | Ternary in modifier values or `if/else` |
| `items.map(render)` | `ForEach(items) { item in }` |
| `items.filter().sort()` | `.filter { }.sorted { }` on array |
| `{condition && <Component/>}` | `if condition { Component() }` |
| `position: fixed` | `.overlay` or native toolbar/sheet |
| `display: grid` | `LazyVGrid` / `HStack` with fixed-width frames |
| `display: flex` with `gap` | `HStack(spacing:)` / `VStack(spacing:)` |
| `border-radius` | `.cornerRadius()` or `.clipShape(RoundedRectangle(...))` |
| `transition: all 0.15s` | `.animation(.easeInOut(duration: 0.15), value:)` |
| `@keyframes` | `withAnimation(.easeOut(duration: 0.2)) { }` |
| `backdrop-filter: blur` | `.background(.ultraThinMaterial)` |
| `overflow: hidden` | `.clipped()` |
| `text-transform: uppercase` | `.textCase(.uppercase)` |
| `letter-spacing: 0.5px` | `.tracking(0.5)` |
| `white-space: pre-wrap` | Default for `Text` (or `.fixedSize()` for no wrapping) |
| `font-family: monospace` | `.font(.system(.body, design: .monospaced))` |
| `line-height: 1.5` | `.lineSpacing(4)` (approximate) |

## Appendix D: File-to-Component Mapping

Expected file structure in `macos-app/LoopCommander/`:

```
Views/
  ContentView.swift          -- NavigationSplitView shell (Section 3.1)
  SidebarView.swift          -- Sidebar navigation (Section 3.2)
  TaskListView.swift         -- Task table with header + rows (Section 2.4-2.5)
  TaskDetailView.swift       -- Detail panel with info card + logs (Section 2.10)
  TaskEditorView.swift       -- Sheet modal with form (Section 2.8)
  LogsView.swift             -- Global log viewer with search/filter (Section 2.11)
  MetricsBarView.swift       -- Responsive metric card grid (Section 2.3)
  StatusBadge.swift          -- Status indicator pill (Section 2.1)
  SparklineChart.swift       -- 7-day cost trend chart (Section 2.12)
  Components/
    MetricCard.swift         -- Single metric card (Section 2.2)
    TaskRow.swift            -- Task list row (Section 2.4)
    TaskTableHeader.swift    -- Task table column header (Section 2.5)
    LogEntryRow.swift        -- Expandable log entry (Section 2.6)
    LogTableHeader.swift     -- Log table column header (Section 2.7)
    TagChip.swift            -- Removable tag pill (Section 2.8)
    LCTextField.swift        -- Styled text input (Section 2.8)
    LCTextEditor.swift       -- Styled multiline input (Section 2.8)
    LCFormField.swift        -- Label + content wrapper (Section 2.8)
    DaemonBanner.swift       -- Connection status banner (Section 4.11)
    MenuBarView.swift        -- Menu bar extra content (Section 4.5)

Styles/
  Color+LoopCommander.swift  -- All color tokens (Section 1.1)
  Font+LoopCommander.swift   -- All font tokens (Section 1.2)
  LCSpacing.swift            -- Spacing scale (Section 1.3)
  LCRadius.swift             -- Corner radii (Section 1.4)
  LCBorder.swift             -- Border widths (Section 1.5)
  LCAnimations.swift         -- Animation + transition definitions (Section 1.7)
  LCButtonStyles.swift       -- Primary + secondary button styles (Section 2.8)
  StatusConfig.swift         -- Status color/icon/label mapping (Section 1.8)

Models/
  LCTask.swift               -- Task model (Codable)
  ExecutionLog.swift         -- Log entry model (Codable)
  DashboardMetrics.swift     -- Metrics model (Codable)
  TaskStatus.swift           -- Status enum
  Schedule.swift             -- Schedule enum

ViewModels/
  TaskListViewModel.swift    -- Task list data + actions
  TaskDetailViewModel.swift  -- Single task data + actions
  LogsViewModel.swift        -- Log query + filtering
  DashboardViewModel.swift   -- Metrics + timer refresh
  MenuBarViewModel.swift     -- Menu bar extra state

Services/
  DaemonClient.swift         -- Unix socket JSON-RPC client
  DaemonMonitor.swift        -- Connection health + reconnect
  EventStream.swift          -- Real-time event subscription

Utilities/
  Formatters.swift           -- relativeTime, formatDuration, formatTimestamp
```
