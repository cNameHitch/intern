import SwiftUI

extension Font {
    // -- UI Text (Inter -> SF Pro / system font) --
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

    // -- Code / Data (JetBrains Mono -> SF Mono) --
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
