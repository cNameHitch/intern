# Editor Tab -- Swift Implementation Specification

This document describes the exact Swift changes required to implement the Editor tab feature. It covers new files, modified files, type signatures, property lists, and migration steps. It does NOT include full method bodies -- only signatures, stored/computed properties, and structural outlines sufficient for implementation.

---

## 1. New and Modified Files

| File | Action | Description |
|---|---|---|
| `Models/SchedulePreset.swift` | **New** | `SchedulePreset` enum with cron generation and human descriptions |
| `Views/EditorView.swift` | **New** | Full-width two-pane editor tab (replaces modal for create/edit) |
| `Views/ScheduleBuilderView.swift` | **New** | Preset picker, conditional sub-pickers, cron readout |
| `ViewModels/EditorViewModel.swift` | **New** | Draft management, dirty tracking, save/discard, preset sync |
| `Views/SidebarView.swift` | **Modified** | Add `.editor` case to `SidebarItem`, dirty dot indicator |
| `Views/ContentView.swift` | **Modified** | Add `EditorView` to ZStack, remove modal overlay, wire notifications |
| `Models/LCTask.swift` | **Modified** | Add `Equatable` conformance to `LCTaskDraft` for dirty comparison |

---

## 2. SidebarView Changes

### SidebarItem Enum

```swift
enum SidebarItem: Hashable {
    case tasks
    case editor    // NEW -- inserted between tasks and logs
    case logs
}
```

### SidebarView Signature Changes

```swift
struct SidebarView: View {
    @Binding var selection: SidebarItem?
    let activeCount: Int
    let editorIsDirty: Bool    // NEW -- drives amber dot on Editor nav item
}
```

### Navigation Buttons

The `VStack(spacing: 2)` of nav buttons becomes three items:

```swift
VStack(spacing: 2) {
    sidebarButton(
        title: "Tasks",
        icon: "list.bullet.rectangle",
        item: .tasks,
        badge: activeCount > 0 ? "\(activeCount)" : nil,
        dirtyDot: false
    )
    sidebarButton(
        title: "Editor",
        icon: "pencil.and.outline",
        item: .editor,
        badge: nil,
        dirtyDot: editorIsDirty    // NEW parameter
    )
    sidebarButton(
        title: "Logs",
        icon: "doc.text.magnifyingglass",
        item: .logs,
        badge: nil,
        dirtyDot: false
    )
}
```

### Dirty Dot Indicator

Add to the `sidebarButton` method signature:

```swift
private func sidebarButton(
    title: String,
    icon: String,
    item: SidebarItem,
    badge: String?,
    dirtyDot: Bool           // NEW parameter
) -> some View
```

Inside the button's `HStack`, after the `Spacer()` and before the badge:

```swift
if dirtyDot {
    Circle()
        .fill(Color.lcAmber)
        .frame(width: 6, height: 6)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.15), value: dirtyDot)
}
```

Accessibility: When `dirtyDot` is true, the button's `accessibilityLabel` reads `"Editor, unsaved changes"` instead of `"Editor"`.

---

## 3. ContentView Changes

### What Is Removed

- The `TaskEditorState` enum (lines 3-16 of current file).
- The `@State private var showingEditor: TaskEditorState? = nil` property.
- The entire `.overlay { ... }` block that renders the modal backdrop, `CommandImportView`, and `editorView(for:)`.
- The `editorView(for:)` method.
- The `.animation` modifiers on `showingEditor?.id`.
- The `.onReceive(NotificationCenter.default.publisher(for: .newTask))` handler that sets `showingEditor = .new`.

### What Stays

- `CommandImportView` modal overlay stays for the import-from-Tasks flow. It is presented via the existing `showingImport` state, but upon import completion, it now posts a notification to the Editor tab instead of setting `showingEditor`.
- All notification publishers for `.refreshData`, `.switchToTasks`, `.switchToLogs`.
- The `setupEventHandlers()` method.
- The `tasksLayout` computed property (unchanged).

### New State Properties

```swift
@State private var selectedSidebar: SidebarItem? = .tasks
@State private var selectedTaskId: String? = nil
@State private var showingImport = false
@State private var showingDirtyAlert = false          // NEW -- navigation guard alert
@State private var pendingNavigation: SidebarItem? = nil  // NEW -- deferred nav target

@StateObject private var editorVM = EditorViewModel()  // NEW -- shared editor VM
```

### New Notification Names

```swift
extension Notification.Name {
    static let editorNewTask = Notification.Name("com.loopcommander.editorNewTask")
    static let editorOpenTask = Notification.Name("com.loopcommander.editorOpenTask")
    // userInfo key "task" -> LCTask (for editorOpenTask)
}
```

### ZStack Addition

```swift
ZStack {
    tasksLayout
        .opacity(selectedSidebar == .tasks ? 1 : 0)
        .allowsHitTesting(selectedSidebar == .tasks)

    EditorView(vm: editorVM)                          // NEW
        .opacity(selectedSidebar == .editor ? 1 : 0)  // NEW
        .allowsHitTesting(selectedSidebar == .editor)  // NEW

    LogsView()
        .opacity(selectedSidebar == .logs ? 1 : 0)
        .allowsHitTesting(selectedSidebar == .logs)
}
```

### SidebarView Instantiation

```swift
SidebarView(
    selection: $selectedSidebar,
    activeCount: dashboardVM.activeCount,
    editorIsDirty: editorVM.isDirty           // NEW
)
```

### Navigation Guard

The sidebar selection binding is intercepted. Instead of binding `$selectedSidebar` directly, use an intermediate binding that checks dirty state:

```swift
private var guardedSelection: Binding<SidebarItem?> {
    Binding(
        get: { selectedSidebar },
        set: { newValue in
            if selectedSidebar == .editor && editorVM.isDirty && newValue != .editor {
                pendingNavigation = newValue
                showingDirtyAlert = true
            } else {
                selectedSidebar = newValue
            }
        }
    )
}
```

### Dirty Alert

```swift
.alert("You have unsaved changes", isPresented: $showingDirtyAlert) {
    Button("Save", role: nil) { /* save then navigate */ }
    Button("Discard Changes", role: .destructive) { /* discard then navigate */ }
    Button("Cancel", role: .cancel) { pendingNavigation = nil }
} message: {
    Text("Do you want to save before leaving the Editor?")
}
```

### Notification Wiring

```swift
.onReceive(NotificationCenter.default.publisher(for: .editorNewTask)) { _ in
    editorVM.startNewTask()
    selectedSidebar = .editor
}
.onReceive(NotificationCenter.default.publisher(for: .editorOpenTask)) { notification in
    if let task = notification.userInfo?["task"] as? LCTask {
        editorVM.loadTask(task)
        selectedSidebar = .editor
    }
}
```

### TaskListView Callback Changes

```swift
TaskListView(
    selectedTaskId: $selectedTaskId,
    onNewTask: {
        NotificationCenter.default.post(name: .editorNewTask, object: nil)
    },
    onImportCommand: { showingImport = true }
)
```

### TaskDetailView Edit Callback

```swift
TaskDetailView(
    taskId: taskId,
    onEdit: { task in
        NotificationCenter.default.post(
            name: .editorOpenTask,
            object: nil,
            userInfo: ["task": task]
        )
    },
    onDelete: { ... }
)
```

---

## 4. EditorView Layout

### File: `Views/EditorView.swift`

```swift
struct EditorView: View {
    @ObservedObject var vm: EditorViewModel
    @EnvironmentObject var daemonMonitor: DaemonMonitor

    var body: some View { ... }
}
```

### State Rendering

The view renders one of three states based on `vm.editorState`:

```swift
enum EditorState {
    case empty                    // no task loaded
    case creating                 // new task, blank form
    case editing(taskId: String)  // existing task loaded
}
```

#### Empty State

Centered `VStack(spacing: 12)` with:
- `Image(systemName: "pencil.and.outline")`, 48pt, `lcTextFaint`
- `Text("No task loaded")`, `.lcBodyMedium`, `lcTextMuted`
- `Text("Create a new task or open one from the Tasks tab.")`, `.lcCaption`, `lcTextSubtle`
- `Button("+ New Task") { vm.startNewTask() }`, `LCPrimaryButtonStyle`

#### Creating / Editing States

```
VStack(spacing: 0) {
    editorTopBar              // fixed header
    unsavedChangesBanner      // conditional
    editorPanes               // two-pane split, fills remaining space
}
```

### Top Bar

```swift
@ViewBuilder
private var editorTopBar: some View {
    HStack(spacing: 8) {
        // Inline task name TextField
        TextField("Untitled Task", text: $vm.draft.name)
            .font(.lcHeadingLarge)     // 20px bold
            .textFieldStyle(.plain)
            .foregroundColor(.lcTextPrimary)
        Spacer()
        // Dry Run button (editing state only)
        if case .editing = vm.editorState {
            Button("Dry Run") { ... }
                .buttonStyle(LCToolbarButtonStyle())
                .keyboardShortcut("r", modifiers: [.command, .option])
        }
        // Discard button (visible when dirty)
        if vm.isDirty {
            Button("Discard") { vm.confirmDiscard() }
                .buttonStyle(LCSecondaryButtonStyle())
                .transition(.opacity)
        }
        // Save button
        Button(vm.isCreating ? "Create Task" : "Save Changes") {
            Task { await vm.save() }
        }
        .buttonStyle(LCPrimaryButtonStyle())
        .disabled(vm.isSaving)
        .keyboardShortcut("s", modifiers: .command)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
    .background(Color.lcSurface)
    .overlay(alignment: .bottom) {
        Rectangle().fill(Color.lcSeparator).frame(height: 1)
    }
}
```

### Unsaved Changes Banner

```swift
@ViewBuilder
private var unsavedChangesBanner: some View {
    if vm.isDirty {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(.lcAmber)
            Text("Unsaved changes -- you have edits in progress.")
                .font(.lcBodyMedium)
                .foregroundColor(.lcAmber)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.lcAmberBg)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.lcAmber.opacity(0.2)).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.lcSeparator).frame(height: 1)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStatusElement)
    }
}
```

### Two-Pane Split

```swift
@ViewBuilder
private var editorPanes: some View {
    GeometryReader { geo in
        HStack(spacing: 0) {
            promptEditorPane
                .frame(width: geo.size.width * 0.6)

            Rectangle()
                .fill(Color.lcSeparator)
                .frame(width: 1)

            settingsPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
```

### Prompt Editor Pane

```swift
@ViewBuilder
private var promptEditorPane: some View {
    VStack(spacing: 0) {
        // Pane header
        HStack {
            Text("PROMPT / COMMAND")
                .font(.lcLabel)
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.5)
            Spacer()
            Text("\(vm.draft.command.count) chars")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.lcTextMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)

        // Text editor (fills remaining height)
        LCTextEditor(text: $vm.draft.command, placeholder: "claude -p 'Your prompt here...'")
            .frame(maxHeight: .infinity)

        // Footer separator
        Rectangle().fill(Color.lcBorder).frame(height: 1)
        HStack {
            Text("\(vm.draft.command.count) characters")
                .font(.lcCaption)
                .foregroundColor(.lcTextMuted)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
    .background(Color.lcBackground)
}
```

### Settings Pane

```swift
@ViewBuilder
private var settingsPane: some View {
    ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: 4) {
            settingsSection("Task") { taskSection }
            settingsSection("Schedule") { scheduleSection }
            settingsSection("Execution") { executionSection }
            settingsSection("Tags") { tagsSection }
            settingsSection("Environment Variables") { envVarsSection }
        }
        .padding(16)
    }
    .background(Color.lcBackground)
}
```

Each `settingsSection` wraps content in a card with `lcSurfaceContainer` background, `lcBorder` border, `LCRadius.panel` corners, and 16px padding.

---

## 5. EditorViewModel

### File: `ViewModels/EditorViewModel.swift`

```swift
@MainActor
class EditorViewModel: ObservableObject {
    // MARK: - Published State

    @Published var draft: LCTaskDraft = LCTaskDraft()
    @Published var editorState: EditorState = .empty
    @Published var isSaving: Bool = false
    @Published var error: String?
    @Published var validationErrors: [String] = []
    @Published var schedulePreset: SchedulePreset = .every15Min
    @Published var selectedHour: Int = 9
    @Published var selectedMinute: Int = 0
    @Published var selectedWeekdays: Set<Int> = [1]   // 0=Sun, 1=Mon, ...
    @Published var selectedDayOfMonth: Int = 1
    @Published var showDiscardAlert: Bool = false
    @Published var showSavedConfirmation: Bool = false

    // MARK: - Internal State

    private var originalSnapshot: LCTaskDraft?
    private var taskId: String?
    private var client: DaemonClient?

    // MARK: - Computed Properties

    var isDirty: Bool { ... }
    // For .creating state: true if any field differs from default LCTaskDraft()
    // For .editing state: true if draft != originalSnapshot
    // For .empty state: always false

    var isCreating: Bool { ... }
    // Returns true if editorState == .creating

    // MARK: - Lifecycle Methods

    func setClient(_ client: DaemonClient) { ... }

    func startNewTask() { ... }
    // Sets editorState = .creating, draft = LCTaskDraft(), originalSnapshot = nil, taskId = nil
    // Resets schedulePreset to .every15Min

    func loadTask(_ task: LCTask) { ... }
    // Sets editorState = .editing(taskId: task.id), draft = LCTaskDraft(from: task),
    // originalSnapshot = LCTaskDraft(from: task), taskId = task.id
    // Infers schedulePreset from task.schedule cron expression

    func loadFromImportedCommand(_ command: ClaudeCommand) { ... }
    // Sets editorState = .creating, draft = LCTaskDraft(from: command),
    // originalSnapshot = nil, taskId = nil
    // Infers schedulePreset from the default import schedule

    // MARK: - Save / Discard

    func validate() -> Bool { ... }
    // Same validation logic as existing TaskEditorViewModel.validate()

    func save() async -> Bool { ... }
    // Validates, then calls client.createTask or client.updateTask
    // On success: updates originalSnapshot to current draft, clears error
    // Returns true on success

    func discard() { ... }
    // If editing: resets draft to originalSnapshot
    // If creating: resets to .empty state

    func confirmDiscard() { ... }
    // Sets showDiscardAlert = true

    // MARK: - Schedule Preset Sync

    func syncCronFromPreset() { ... }
    // Called whenever schedulePreset, selectedHour, selectedMinute,
    // selectedWeekdays, or selectedDayOfMonth changes
    // Updates draft.schedule (cron string) and draft.scheduleHuman

    func inferPresetFromCron(_ cron: String) { ... }
    // Parses a cron expression and sets schedulePreset + sub-picker values
    // Falls back to .custom if no preset matches
}
```

### Dirty State Comparison

`LCTaskDraft` must conform to `Equatable` for snapshot comparison. Add to `LCTask.swift`:

```swift
extension LCTaskDraft: Equatable {
    static func == (lhs: LCTaskDraft, rhs: LCTaskDraft) -> Bool {
        lhs.name == rhs.name &&
        lhs.command == rhs.command &&
        lhs.skill == rhs.skill &&
        lhs.workingDir == rhs.workingDir &&
        lhs.schedule == rhs.schedule &&
        lhs.scheduleHuman == rhs.scheduleHuman &&
        lhs.maxBudget == rhs.maxBudget &&
        lhs.maxTurns == rhs.maxTurns &&
        lhs.timeoutSecs == rhs.timeoutSecs &&
        lhs.tags == rhs.tags &&
        lhs.envVars == rhs.envVars
    }
}
```

### isDirty Implementation Outline

```swift
var isDirty: Bool {
    switch editorState {
    case .empty:
        return false
    case .creating:
        return draft != LCTaskDraft()
    case .editing:
        guard let snapshot = originalSnapshot else { return false }
        return draft != snapshot
    }
}
```

---

## 6. SchedulePreset Enum

### File: `Models/SchedulePreset.swift`

```swift
enum SchedulePreset: String, CaseIterable, Identifiable {
    case every5Min     = "every_5_min"
    case every10Min    = "every_10_min"
    case every15Min    = "every_15_min"
    case every30Min    = "every_30_min"
    case everyHour     = "every_hour"
    case every2Hours   = "every_2_hours"
    case every4Hours   = "every_4_hours"
    case dailyAt       = "daily_at"
    case weekdaysAt    = "weekdays_at"
    case weeklyOn      = "weekly_on"
    case monthlyOn     = "monthly_on"
    case custom        = "custom"

    var id: String { rawValue }

    var displayName: String { ... }
    // Returns user-facing label: "Every 15 minutes", "Daily at...", etc.

    var requiresTimePicker: Bool { ... }
    // true for: dailyAt, weekdaysAt, weeklyOn, monthlyOn

    var requiresDayOfWeekPicker: Bool { ... }
    // true for: weeklyOn

    var requiresDayOfMonthPicker: Bool { ... }
    // true for: monthlyOn

    var requiresIntervalPicker: Bool { ... }
    // true for: every5Min, every10Min, every15Min, every30Min, everyHour,
    //           every2Hours, every4Hours (these are simple presets, no sub-picker)
    // Actually returns false -- these are fixed presets with no picker needed.

    var isCustom: Bool { ... }
    // true only for .custom

    func cronExpression(hour: Int, minute: Int, weekdays: Set<Int>, dayOfMonth: Int) -> String { ... }
    // Generates the cron string from the preset and the sub-picker values.

    func humanDescription(hour: Int, minute: Int, weekdays: Set<Int>, dayOfMonth: Int) -> String { ... }
    // Generates a human-readable description.
}
```

### Preset-to-Cron Conversion Table

| Preset | Cron Expression | Human Description |
|---|---|---|
| `every5Min` | `*/5 * * * *` | Every 5 minutes |
| `every10Min` | `*/10 * * * *` | Every 10 minutes |
| `every15Min` | `*/15 * * * *` | Every 15 minutes |
| `every30Min` | `*/30 * * * *` | Every 30 minutes |
| `everyHour` | `0 * * * *` | Every hour |
| `every2Hours` | `0 */2 * * *` | Every 2 hours |
| `every4Hours` | `0 */4 * * *` | Every 4 hours |
| `dailyAt` | `{M} {H} * * *` | Every day at HH:MM |
| `weekdaysAt` | `{M} {H} * * 1-5` | Weekdays at HH:MM |
| `weeklyOn` | `{M} {H} * * {D,...}` | Weekly on {Day(s)} at HH:MM |
| `monthlyOn` | `{M} {H} {D} * *` | Monthly on the {D}th at HH:MM |
| `custom` | (user-entered) | (parsed from cron or user-entered) |

Where `{H}` = selectedHour, `{M}` = selectedMinute, `{D}` = selectedDayOfMonth or weekday set.

### Reverse Parsing (inferPresetFromCron)

Given a cron string, the `EditorViewModel.inferPresetFromCron` method matches against known patterns:

| Cron Pattern | Inferred Preset |
|---|---|
| `*/5 * * * *` | `every5Min` |
| `*/10 * * * *` | `every10Min` |
| `*/15 * * * *` | `every15Min` |
| `*/30 * * * *` | `every30Min` |
| `0 * * * *` | `everyHour` |
| `0 */2 * * *` | `every2Hours` |
| `0 */4 * * *` | `every4Hours` |
| `{M} {H} * * *` | `dailyAt`, extract H and M |
| `{M} {H} * * 1-5` | `weekdaysAt`, extract H and M |
| `{M} {H} * * {D,...}` | `weeklyOn`, extract H, M, and weekday set |
| `{M} {H} {D} * *` | `monthlyOn`, extract H, M, and day-of-month |
| (anything else) | `custom` |

---

## 7. ScheduleBuilderView

### File: `Views/ScheduleBuilderView.swift`

```swift
struct ScheduleBuilderView: View {
    @ObservedObject var vm: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            presetPicker
            subPicker               // conditional on preset
            cronReadout             // always visible
        }
    }
}
```

### Preset Picker

```swift
@ViewBuilder
private var presetPicker: some View {
    LCFormField(label: "Preset") {
        Picker("Schedule", selection: $vm.schedulePreset) {
            ForEach(SchedulePreset.allCases) { preset in
                Text(preset.displayName).tag(preset)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: vm.schedulePreset) { _ in
            vm.syncCronFromPreset()
        }
    }
}
```

### Conditional Sub-Pickers

```swift
@ViewBuilder
private var subPicker: some View {
    if vm.schedulePreset.requiresTimePicker {
        timeSubPicker
    }
    if vm.schedulePreset.requiresDayOfWeekPicker {
        dayOfWeekSubPicker
    }
    if vm.schedulePreset.requiresDayOfMonthPicker {
        dayOfMonthSubPicker
    }
    if vm.schedulePreset.isCustom {
        customCronField
    }
}
```

### Time Sub-Picker

```swift
@ViewBuilder
private var timeSubPicker: some View {
    LCFormField(label: "Time") {
        HStack(spacing: 4) {
            Picker("Hour", selection: $vm.selectedHour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(String(format: "%02d", h)).tag(h)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 70)

            Text(":")
                .font(.lcBodyMedium)
                .foregroundColor(.lcTextMuted)

            Picker("Minute", selection: $vm.selectedMinute) {
                ForEach(stride(from: 0, to: 60, by: 5).map { $0 }, id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 70)
        }
        .onChange(of: vm.selectedHour) { _ in vm.syncCronFromPreset() }
        .onChange(of: vm.selectedMinute) { _ in vm.syncCronFromPreset() }
    }
}
```

### Day-of-Week Sub-Picker

```swift
@ViewBuilder
private var dayOfWeekSubPicker: some View {
    LCFormField(label: "Day of Week") {
        HStack(spacing: 4) {
            ForEach(Array(["Sun","Mon","Tue","Wed","Thu","Fri","Sat"].enumerated()),
                    id: \.offset) { index, name in
                DayChip(
                    label: name,
                    isSelected: vm.selectedWeekdays.contains(index),
                    onTap: { vm.toggleWeekday(index) }
                )
            }
        }
        .onChange(of: vm.selectedWeekdays) { _ in vm.syncCronFromPreset() }
    }
}
```

`DayChip` is a small view with selected/unselected styling per the UI design spec (selected: `lcAccentBgSubtle` background, `lcAccent` border; unselected: `lcSurfaceContainer` background, `lcBorderInput` border).

### Day-of-Month Sub-Picker

```swift
@ViewBuilder
private var dayOfMonthSubPicker: some View {
    LCFormField(label: "Day of Month") {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Day", selection: $vm.selectedDayOfMonth) {
                ForEach(1...28, id: \.self) { d in
                    Text("\(d)").tag(d)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: vm.selectedDayOfMonth) { _ in vm.syncCronFromPreset() }

            Text("Days 29-31 omitted for reliability across all months.")
                .font(.lcCaption)
                .foregroundColor(.lcTextSubtle)
        }
    }
}
```

### Custom Cron Field

```swift
@ViewBuilder
private var customCronField: some View {
    LCFormField(label: "Cron Expression") {
        LCTextField(text: $vm.draft.schedule, placeholder: "*/15 * * * *")
            .font(.system(size: 13, design: .monospaced))
    }
}
```

### Cron Readout

```swift
@ViewBuilder
private var cronReadout: some View {
    VStack(alignment: .leading, spacing: 3) {
        Text(vm.draft.schedule)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.lcAccentLight)
        Text(vm.draft.scheduleHuman)
            .font(.lcCaption)
            .foregroundColor(.lcTextSecondary)
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.lcCodeBackground)
    .overlay(
        RoundedRectangle(cornerRadius: LCRadius.button)
            .stroke(Color.lcBorder, lineWidth: 1)
    )
    .cornerRadius(LCRadius.button)
    .textSelection(.enabled)
    .accessibilityLabel("Cron expression: \(vm.draft.schedule). Meaning: \(vm.draft.scheduleHuman)")
}
```

---

## 8. Migration from Modal

### Step-by-Step Removal

1. **Delete `TaskEditorState` enum** from `ContentView.swift` (lines 3-16).

2. **Remove `showingEditor` state** from `ContentView`:
   ```swift
   // DELETE:
   @State private var showingEditor: TaskEditorState? = nil
   ```

3. **Remove the modal overlay block** from `ContentView.body` -- the entire `.overlay { ... }` that conditionally renders `Color.lcOverlay`, `CommandImportView`, and the `editorView(for:)` call. The `CommandImportView` import flow is preserved separately (see below).

4. **Remove `editorView(for:)` method** from `ContentView`.

5. **Remove `.animation` on `showingEditor?.id`**.

6. **Preserve `CommandImportView`** for the import-from-Tasks-tab flow. It continues to present as a modal overlay triggered by `showingImport`. On import completion, instead of setting `showingEditor = .importing(command)`, it posts:
   ```swift
   NotificationCenter.default.post(
       name: .editorOpenImport,
       object: nil,
       userInfo: ["command": command]
   )
   ```
   Add notification name:
   ```swift
   static let editorOpenImport = Notification.Name("com.loopcommander.editorOpenImport")
   ```

7. **Redirect `onNewTask` callbacks**. In `TaskListView` and any toolbar "+" button, replace `showingEditor = .new` with:
   ```swift
   NotificationCenter.default.post(name: .editorNewTask, object: nil)
   ```

8. **Redirect `onEdit` callbacks**. In `TaskDetailView` and context menus, replace `showingEditor = .editing(task)` with:
   ```swift
   NotificationCenter.default.post(
       name: .editorOpenTask,
       object: nil,
       userInfo: ["task": task]
   )
   ```

9. **Remove the `.onReceive(.newTask)` handler** that set `showingEditor = .new`. Replace with `.onReceive(.editorNewTask)` that sets `selectedSidebar = .editor` and calls `editorVM.startNewTask()`.

### What the Modal Shared That the Editor Tab Reuses

| Component | Reuse Strategy |
|---|---|
| `LCFormField` | Used directly in `ScheduleBuilderView` and settings pane sections |
| `LCTextField` | Used directly throughout settings pane |
| `LCTextEditor` | Used directly in prompt editor pane |
| `FlowLayout` | Used directly in tags section |
| `TagChip` | Used directly in tags section |
| `LCTaskDraft` | Used by `EditorViewModel.draft` (same type) |
| `TaskEditorViewModel.validate()` | Logic migrated to `EditorViewModel.validate()` |
| `TaskEditorViewModel.save()` | Logic migrated to `EditorViewModel.save()` |

The existing `TaskEditorView.swift` file can be kept for the reusable sub-components (`LCFormField`, `LCTextField`, `LCTextEditor`, `FlowLayout`, `TagChip`) or those components can be extracted to a shared file. The `TaskEditorView` struct itself and `TaskEditorViewModel` class are no longer instantiated.

---

## 9. Dirty State Management

### isDirty Computed Property

Located in `EditorViewModel`:

```swift
var isDirty: Bool {
    switch editorState {
    case .empty:
        return false
    case .creating:
        return draft != LCTaskDraft()
    case .editing:
        guard let snapshot = originalSnapshot else { return false }
        return draft != snapshot
    }
}
```

This property is checked by:
- `SidebarView` (amber dot visibility via `editorIsDirty` parameter)
- `EditorView` top bar (Discard button visibility, unsaved banner visibility)
- `ContentView` navigation guard (dirty alert trigger)

### Navigation Guard Alert

Triggered when the user taps a non-Editor sidebar item while `isDirty` is true. Presented via `.alert` on `ContentView`. Three actions:

| Button | Role | Behavior |
|---|---|---|
| Save | Default | Calls `editorVM.save()`, on success sets `selectedSidebar = pendingNavigation` |
| Discard Changes | Destructive | Calls `editorVM.discard()`, sets `selectedSidebar = pendingNavigation` |
| Cancel | Cancel | Sets `pendingNavigation = nil`, stays on Editor tab |

### Discard Confirmation Alert

Triggered by the Discard button in the top bar. Presented via `.alert` on `EditorView`:

```swift
.alert(
    vm.isCreating ? "Discard new task?" : "Discard changes?",
    isPresented: $vm.showDiscardAlert
) {
    Button("Discard", role: .destructive) { vm.discard() }
    Button("Cancel", role: .cancel) { }
} message: {
    Text(vm.isCreating
        ? "All unsaved content will be lost."
        : "Your edits will be lost."
    )
}
```

### Save Success Feedback

After a successful save, `showSavedConfirmation` is set to true for 1.2 seconds. During this window, the Save button label is replaced with a checkmark icon in `lcGreen`. A `DispatchQueue.main.asyncAfter` resets the flag.

---

## 10. Non-Breaking Guarantees

The following components and systems are explicitly unchanged by this feature:

| Layer | What Does NOT Change |
|---|---|
| **Rust crates** | All 7 crates (`lc-core`, `lc-config`, `lc-scheduler`, `lc-runner`, `lc-logger`, `lc-daemon`, `lc-cli`) are untouched. No Rust code is modified. |
| **CLI (`lc`)** | All CLI commands work identically. No new commands added. |
| **JSON-RPC API** | No new methods, no changed method signatures. Uses existing `create_task`, `update_task`, `get_task`, `dry_run`, `list_templates`. |
| **Data models (Rust)** | `Task`, `Schedule`, `TaskTemplate`, `DryRunResult` structs unchanged. |
| **Data models (Swift)** | `LCTask`, `Schedule`, `TaskTemplate`, `DryRunResult`, `DaemonStatus` unchanged. `LCTaskDraft` gains only `Equatable` conformance (additive). |
| **Persistence** | YAML task files, SQLite logs database, plist generation, daemon socket -- all unchanged. |
| **DaemonClient** | No new RPC calls. All existing methods reused as-is. |
| **DaemonMonitor** | Unchanged. Still injected as `@EnvironmentObject`. |
| **TaskListViewModel** | Unchanged. |
| **DashboardViewModel** | Unchanged. |
| **EventStream** | Unchanged. |
| **LogsView** | Unchanged. |
| **TaskListView** | Only callback wiring changes (notifications instead of closure setting `showingEditor`). View layout and rendering untouched. |
| **TaskDetailView** | Only `onEdit` callback wiring changes. View layout and rendering untouched. |
| **CommandImportView** | Unchanged. Still presented as a modal overlay on the Tasks tab. Only the completion callback changes (posts notification instead of setting `showingEditor`). |
| **Design tokens** | All `Color.lc*`, `Font.lc*`, `LCRadius.*`, `LCSpacing.*`, `LCBorder.*` tokens unchanged. New tokens (`lcAmber`, `lcAmberBg`) are additive only. |
| **Window constraints** | Minimum 900x600 unchanged. |
| **Color scheme** | `.preferredColorScheme(.dark)` unchanged. |

---

## Appendix: File Dependency Graph

```
ContentView.swift
  imports: SidebarView, EditorView, TaskListView, TaskDetailView, LogsView
  owns: EditorViewModel (as @StateObject)

EditorView.swift
  imports: EditorViewModel, ScheduleBuilderView, LCFormField, LCTextField,
           LCTextEditor, FlowLayout, TagChip
  reads: DaemonMonitor (via @EnvironmentObject)

EditorViewModel.swift
  imports: LCTaskDraft, LCTask, SchedulePreset, DaemonClient, ClaudeCommand

ScheduleBuilderView.swift
  imports: EditorViewModel, SchedulePreset, LCFormField, LCTextField

SchedulePreset.swift
  standalone enum, no imports beyond Foundation

SidebarView.swift
  imports: SidebarItem (modified enum)

LCTask.swift
  modified: LCTaskDraft + Equatable conformance (additive)
```
