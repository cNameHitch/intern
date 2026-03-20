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
                    .lineLimit(1)
                Text(task.workingDir)
                    .font(.lcDataSmall)
                    .foregroundColor(.lcTextSubtle)
                    .lineLimit(1)
            }
            .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)

            // Column 2: Schedule
            Text(task.scheduleHuman)
                .font(.lcDataMedium)
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
                .frame(minWidth: 80, maxWidth: 160, alignment: .leading)

            // Column 3: Status
            StatusBadge(status: task.status)
                .frame(minWidth: 80, maxWidth: 120, alignment: .leading)

            // Column 4: Last Run
            Text(task.lastRun != nil ? relativeTime(task.lastRun!) : "\u{2014}")
                .font(.lcDataMedium)
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 70, alignment: .leading)

            // Column 5: Runs
            Text("\(task.runCount)")
                .font(.lcDataMedium)
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 50, alignment: .leading)

            // Column 6: Health
            Text(task.runCount > 0 ? "\(successRate)%" : "\u{2014}")
                .font(.lcDataMedium)
                .foregroundColor(task.runCount > 0 ? .lcHealthColor(for: successRate) : .white.opacity(0.45))
                .frame(width: 50, alignment: .leading)
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
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Task Table Header

struct TaskTableHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Task")
                .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
            Text("Schedule")
                .frame(minWidth: 80, maxWidth: 160, alignment: .leading)
            Text("Status")
                .frame(minWidth: 80, maxWidth: 120, alignment: .leading)
            Text("Last Run")
                .frame(width: 70, alignment: .leading)
            Text("Runs")
                .frame(width: 50, alignment: .leading)
            Text("Health")
                .frame(width: 50, alignment: .leading)
        }
        .lineLimit(1)
        .font(.lcColumnHeader)
        .foregroundColor(.lcTextFaint)
        .textCase(.uppercase)
        .tracking(0.5)
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .background(Color.lcSurfaceRaised)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.lcBorder).frame(height: 1)
        }
    }
}
