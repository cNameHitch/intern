import SwiftUI

enum TaskStatusStyle {
    case active
    case paused
    case error
    case success
    case running
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

    /// Initialize from execution log status string
    init(fromExecStatus status: String) {
        switch status.lowercased() {
        case "success":  self = .success
        case "failed":   self = .error
        case "timeout":  self = .error
        case "killed":   self = .error
        case "skipped":  self = .paused
        default:         self = .disabled
        }
    }

    /// Foreground color
    var color: Color {
        switch self {
        case .active, .success: return .lcGreen
        case .paused:           return .lcAmber
        case .error:            return .lcRed
        case .running:          return .lcAccent
        case .disabled:         return .lcTextMuted
        }
    }

    /// Badge background
    var background: Color {
        switch self {
        case .active:   return .lcGreenBg
        case .success:  return .lcGreenBgSubtle
        case .paused:   return .lcAmberBg
        case .error:    return .lcRedBg
        case .running:  return .lcAccentBg
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

    /// SF Symbol name
    var sfSymbol: String {
        switch self {
        case .active, .success: return "circle.fill"
        case .paused:           return "pause.fill"
        case .error:            return "xmark"
        case .running:          return "arrow.triangle.2.circlepath"
        case .disabled:         return "minus.circle"
        }
    }
}
