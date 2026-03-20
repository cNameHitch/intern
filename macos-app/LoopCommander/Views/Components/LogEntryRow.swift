import SwiftUI

struct LogEntryRow: View {
    let log: ExecutionLog
    let isExpanded: Bool
    let onToggle: () -> Void

    private var statusStyle: TaskStatusStyle {
        TaskStatusStyle(fromExecStatus: log.status)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed summary row
            Button(action: { withAnimation(.lcFadeSlide) { onToggle() } }) {
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
                            .lineLimit(1)
                        let summaryText = log.summary.count > 80
                            ? String(log.summary.prefix(80)) + "\u{2026}"
                            : log.summary
                        Text(summaryText)
                            .font(.lcCaption)
                            .foregroundColor(.white.opacity(0.3))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Timestamp
                    Text(formatTimestamp(log.startedAt))
                        .font(.lcData)
                        .foregroundColor(.lcTextSubtle)
                        .frame(width: 140, alignment: .leading)

                    // Duration
                    Text(formatDuration(log.durationSecs))
                        .font(.lcData)
                        .foregroundColor(.lcTextSubtle)
                        .frame(width: 70, alignment: .leading)

                    // Tokens
                    Text("\(formatTokens(log.tokensUsed)) tok")
                        .font(.lcData)
                        .foregroundColor(.lcTextSubtle)
                        .frame(width: 80, alignment: .leading)

                    // Cost
                    Text(formatCost(log.costUsd))
                        .font(.lcData)
                        .foregroundColor(.lcTextSubtle)
                        .frame(width: 70, alignment: .leading)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(log.summary)
                        .font(.lcLogSummary)
                        .foregroundColor(.white.opacity(0.5))
                        .lineSpacing(4)
                        .textSelection(.enabled)

                    if !log.output.isEmpty {
                        Text(log.output)
                            .font(.lcCode)
                            .foregroundColor(.white.opacity(0.55))
                            .lineSpacing(5)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.lcCodeBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                            .cornerRadius(6)
                            .textSelection(.enabled)
                    }
                }
                .padding(.leading, LCSpacing.logExpandedInset)
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

// MARK: - Log Table Header

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
        .background(Color.lcSurfaceRaised)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.lcBorder).frame(height: 1)
        }
    }
}
