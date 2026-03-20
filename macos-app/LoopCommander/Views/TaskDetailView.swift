import SwiftUI

struct TaskDetailView: View {
    let taskId: String
    let onEdit: (LCTask) -> Void
    let onDelete: () -> Void

    @StateObject private var vm = TaskDetailViewModel()
    @EnvironmentObject var daemonMonitor: DaemonMonitor
    @State private var expandedLogIds: Set<Int> = []
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if vm.isLoading && vm.task == nil {
                    VStack {
                        ProgressView()
                        Text("Loading task...")
                            .font(.lcBodyMedium)
                            .foregroundColor(.lcTextMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(LCSpacing.p32)
                } else if let task = vm.task {
                    // Action bar
                    actionBar(task: task)

                    // Task info card
                    taskInfoCard(task: task)

                    // Execution history
                    executionHistory
                } else if let error = vm.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.lcRed)
                        Text("Error loading task")
                            .font(.lcBodyBold)
                            .foregroundColor(.lcTextPrimary)
                        Text(error)
                            .font(.lcCaption)
                            .foregroundColor(.lcTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(LCSpacing.p32)
                }
            }
            .padding(LCSpacing.p20)
        }
        .background(Color.lcBackground)
        .onAppear {
            vm.setClient(daemonMonitor.client)
            Task { await vm.loadTask(taskId) }
        }
        .onChange(of: taskId) { newId in
            Task { await vm.loadTask(newId) }
        }
        .overlay {
            if vm.showDryRun, let result = vm.dryRunResult {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { vm.showDryRun = false }
                    .transition(.opacity)

                dryRunSheet(result: result)
                    .shadow(color: .black.opacity(0.4), radius: 24, y: 8)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.showDryRun)
        .alert("Delete Task?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    if await vm.deleteTask() {
                        onDelete()
                    }
                }
            }
        } message: {
            Text("This will permanently remove the task and its launchd schedule. Execution logs will be preserved.")
        }
    }

    // MARK: - Action Bar

    @ViewBuilder
    private func actionBar(task: LCTask) -> some View {
        HStack(spacing: 10) {
            // Run Now / Stop
            if task.status == .running {
                Button {
                    Task { await vm.stopTask() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                        Text("Stop")
                    }
                }
                .buttonStyle(LCToolbarButtonStyle(foreground: .lcRed))
                .keyboardShortcut("r", modifiers: .command)
                .help("Stop the running task (Cmd+R)")
            } else {
                Button {
                    Task { await vm.runNow() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Run Now")
                    }
                }
                .buttonStyle(LCToolbarButtonStyle(foreground: .lcGreen))
                .keyboardShortcut("r", modifiers: .command)
                .help("Execute this task immediately (Cmd+R)")
            }

            // Edit
            Button {
                onEdit(task)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                    Text("Edit")
                }
            }
            .buttonStyle(LCToolbarButtonStyle())
            .keyboardShortcut("e", modifiers: .command)
            .help("Edit task configuration (Cmd+E)")

            Spacer()

            // Pause/Resume
            Button {
                Task {
                    if task.status == .active {
                        await vm.pauseTask()
                    } else {
                        await vm.resumeTask()
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: task.status == .active ? "pause.fill" : "play.fill")
                        .font(.system(size: 10))
                    Text(task.status == .active ? "Pause" : "Resume")
                }
            }
            .buttonStyle(LCToolbarButtonStyle(
                foreground: task.status == .active ? .lcAmber : .lcGreen
            ))
            .keyboardShortcut("p", modifiers: .command)
            .help(task.status == .active ? "Pause this task" : "Resume this task")

            // Delete
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                    Text("Delete")
                }
            }
            .buttonStyle(LCDangerButtonStyle())
            .keyboardShortcut(.delete, modifiers: .command)
            .help("Delete this task permanently")
        }
        .padding(.bottom, 20)
        .transition(.lcFadeSlide)
    }

    // MARK: - Task Info Card

    @ViewBuilder
    private func taskInfoCard(task: LCTask) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title row
            HStack(spacing: 12) {
                Text(task.name)
                    .font(.lcHeadingLarge)
                    .foregroundColor(.lcTextPrimary)
                StatusBadge(status: task.status)
            }
            .padding(.bottom, 16)

            // Two-column content
            HStack(alignment: .top, spacing: 20) {
                // Left: Command preview
                VStack(alignment: .leading, spacing: 6) {
                    Text("COMMAND")
                        .font(.lcFieldLabel)
                        .foregroundColor(.lcTextSubtle)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(truncateToLines(task.command, maxLines: 25))
                        .font(.lcCodePreview)
                        .foregroundColor(.lcAccentLight)
                        .lineSpacing(5)
                        .lineLimit(25)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.lcCodeBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        .cornerRadius(6)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity)

                // Right: Metadata grid
                VStack(spacing: 12) {
                    metadataRow(label: "Schedule", value: task.scheduleHuman)
                    metadataRow(label: "Cron", value: task.schedule.cronExpression ?? "\u{2014}")
                    metadataRow(label: "Working Dir", value: task.workingDir)
                    metadataRow(label: "Skill", value: task.skill ?? "\u{2014}")
                    metadataRow(label: "Budget/Run", value: formatCost(task.maxBudgetPerRun))
                    metadataRow(label: "Total Spent", value: formatCost(task.totalCost))
                    metadataRow(label: "Created", value: relativeTime(task.createdAt))
                    metadataRow(label: "Last Run", value: task.lastRun.map { relativeTime($0) } ?? "\u{2014}")
                }
                .frame(maxWidth: .infinity)
            }

            // Tags
            if !task.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(task.tags, id: \.self) { tag in
                        TagChip(text: tag)
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(24)
        .background(Color.lcSurfaceContainer)
        .overlay(
            RoundedRectangle(cornerRadius: LCRadius.panel)
                .stroke(Color.lcBorder, lineWidth: LCBorder.standard)
        )
        .cornerRadius(LCRadius.panel)
        .padding(.bottom, 20)
    }

    private func truncateToLines(_ text: String, maxLines: Int) -> String {
        let lines = text.components(separatedBy: .newlines)
        if lines.count <= maxLines { return text }
        return lines.prefix(maxLines).joined(separator: "\n") + "\n..."
    }

    private func metadataRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.lcFieldLabel)
                .foregroundColor(.lcTextFaint)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(value)
                .font(.lcFieldValue)
                .foregroundColor(.lcTextSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Execution History

    @ViewBuilder
    private var executionHistory: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Execution History (\(vm.logs.count) runs)")
                    .font(.lcSectionLabel)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.lcBorder).frame(height: 1)
            }

            if vm.logs.isEmpty {
                Text("No executions yet")
                    .font(.system(size: 13))
                    .foregroundColor(.lcTextDimmest)
                    .padding(LCSpacing.p32)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("No execution history available for this task")
            } else {
                LogTableHeader()

                LazyVStack(spacing: 0) {
                    ForEach(vm.logs) { log in
                        LogEntryRow(
                            log: log,
                            isExpanded: expandedLogIds.contains(log.id),
                            onToggle: {
                                if expandedLogIds.contains(log.id) {
                                    expandedLogIds.remove(log.id)
                                } else {
                                    expandedLogIds.insert(log.id)
                                }
                            }
                        )
                    }
                }
            }
        }
        .background(Color.lcSurfaceContainer)
        .overlay(
            RoundedRectangle(cornerRadius: LCRadius.panel)
                .stroke(Color.lcBorder, lineWidth: LCBorder.standard)
        )
        .cornerRadius(LCRadius.panel)
    }

    // MARK: - Dry Run Sheet

    @ViewBuilder
    private func dryRunSheet(result: DryRunResult) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Dry Run Result")
                    .font(.lcHeading)
                    .foregroundColor(.lcTextPrimary)
                Spacer()
                Button("Close") { vm.showDryRun = false }
                    .buttonStyle(LCSecondaryButtonStyle())
            }

            if result.wouldBeSkipped {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.lcAmber)
                    Text("Task would be skipped: \(result.skipReason ?? "Unknown reason")")
                        .font(.lcBodyMedium)
                        .foregroundColor(.lcAmber)
                }
                .padding(12)
                .background(Color.lcAmberBg)
                .cornerRadius(LCRadius.button)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("RESOLVED COMMAND")
                    .font(.lcFieldLabel)
                    .foregroundColor(.lcTextSubtle)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(result.resolvedCommand.joined(separator: " "))
                    .font(.lcCode)
                    .foregroundColor(.lcAccentLight)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.lcCodeBackground)
                    .cornerRadius(6)
                    .textSelection(.enabled)
            }

            HStack(spacing: 20) {
                metadataRow(label: "Working Dir", value: result.workingDir)
                metadataRow(label: "Timeout", value: formatDuration(result.timeoutSecs))
            }

            HStack(spacing: 20) {
                metadataRow(label: "Budget/Run", value: formatCost(result.maxBudgetPerRun))
                metadataRow(label: "Daily Spend", value: formatCost(result.dailySpendSoFar))
            }

            if !result.envVars.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ENVIRONMENT VARIABLES")
                        .font(.lcFieldLabel)
                        .foregroundColor(.lcTextSubtle)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    ForEach(Array(result.envVars.keys.sorted()), id: \.self) { key in
                        Text("\(key)=\(result.envVars[key] ?? "")")
                            .font(.lcCode)
                            .foregroundColor(.lcTextSecondary)
                    }
                }
            }
        }
        .padding(32)
        .frame(width: 560)
        .background(Color.lcSurface)
        .overlay(
            RoundedRectangle(cornerRadius: LCRadius.modal)
                .stroke(Color.lcSeparator, lineWidth: LCBorder.standard)
        )
        .cornerRadius(LCRadius.modal)
    }
}
