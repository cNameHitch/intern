# Loop Commander: Editor Tab — Implementation Prompt

This document is a self-contained implementation blueprint for the Editor Tab feature. It is organized as a multi-agent execution plan across five phases. Each agent section specifies which files to read before starting, exactly what to create or modify, the contracts that downstream agents depend on, constraints to honor, and how to verify correctness.

A developer executing any single agent's section should be able to do so without reading the underlying spec documents; all necessary details are reproduced here.

---

## Project Overview

Loop Commander is a macOS-only launchd scheduler for Claude Code tasks. The Swift app communicates with a Rust daemon via JSON-RPC 2.0 over a Unix domain socket at `~/.loop-commander/daemon.sock`. The app uses a dark-themed SwiftUI design system with design tokens defined in the `Styles/` directory.

All Swift source lives under:
```
/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/
```

The build command is:
```bash
cd /Users/hitch/Desktop/git/loop-commander/macos-app && swift build
```

---

## Feature Summary

The Editor Tab replaces the modal `TaskEditorView` overlay with a persistent, full-width two-pane editor that lives as the second item in the sidebar (between Tasks and Logs). The modal workflow is retired for create/edit flows. All existing data models, JSON-RPC methods, daemon behavior, and CLI are unchanged.

### New Files to Create

| File | Purpose |
|------|---------|
| `Models/SchedulePreset.swift` | Enum with cron generation and reverse parsing |
| `ViewModels/EditorViewModel.swift` | Draft management, dirty tracking, save/discard |
| `Views/ScheduleBuilderView.swift` | Preset picker, conditional sub-pickers, cron readout |
| `Views/EditorView.swift` | Full-width two-pane editor tab |

### Files to Modify

| File | Change Summary |
|------|---------------|
| `Models/LCTask.swift` | Add `Equatable` conformance extension to `LCTaskDraft` |
| `Views/SidebarView.swift` | Add `.editor` case to `SidebarItem`; add `editorIsDirty` parameter and dirty dot indicator |
| `Views/ContentView.swift` | Remove modal system; add `EditorView` to ZStack; wire new notifications; add navigation guard |
| `LoopCommanderApp.swift` | Add Editor menu command; update `.newTask` notification to `.editorNewTask`; add `switchToEditor` notification |

### Files That Must NOT Change

- `Models/Schedule.swift` — the `Schedule` enum is used as-is
- `Models/LCTask.swift` existing properties and methods (only add the `Equatable` extension)
- `Views/TaskEditorView.swift` — kept as-is for reference; it is retired but not deleted (leave the file)
- `ViewModels/TaskEditorViewModel.swift` — kept as-is; no modifications
- `Views/TaskListView.swift` — callbacks change in `ContentView`, not in this file
- `Views/TaskDetailView.swift` — callbacks change in `ContentView`, not in this file
- All `Styles/` files
- All `Services/` files
- All `ViewModels/` files except the new `EditorViewModel.swift`
- `Views/Components/` — all existing components used without modification

---

## Design Token Reference

All tokens below are defined in `Styles/Color+LoopCommander.swift`, `Styles/Font+LoopCommander.swift`, `Styles/LCSpacing.swift`, `Styles/LCRadius.swift`, `Styles/LCAnimations.swift`, and `Styles/LCButtonStyles.swift`. Do not redefine them.

### Colors (used in this feature)

| Token | Usage |
|-------|-------|
| `Color.lcBackground` | Main panel background, settings pane background, prompt pane background |
| `Color.lcSurface` | Top bar background |
| `Color.lcSurfaceContainer` | Settings section card background |
| `Color.lcCodeBackground` | Prompt text editor background, cron readout background |
| `Color.lcSeparator` | Top bar bottom border, vertical pane divider |
| `Color.lcBorder` | Section card border, cron readout border, prompt footer separator |
| `Color.lcBorderInput` | Text input border (unfocused), folder button border |
| `Color.lcAccentFocus` | Text input border (focused) |
| `Color.lcAccent` | Save button background, selected day chip border, tag chip text |
| `Color.lcAccentLight` | Prompt text editor foreground, cron expression text |
| `Color.lcAccentBgSubtle` | Selected day chip background |
| `Color.lcAccentDeep` | Sidebar branding gradient |
| `Color.lcTagBg` | Tag chip background |
| `Color.lcAmber` | Dirty dot, unsaved banner icon and text |
| `Color.lcAmberBg` | Unsaved banner background |
| `Color.lcRed` | Validation error text |
| `Color.lcRedBg` | Invalid cron readout background |
| `Color.lcRedBorder` | Invalid cron readout border |
| `Color.lcTextPrimary` | Task name field text, input text |
| `Color.lcTextSecondary` | Sidebar button text (selected), cron human description |
| `Color.lcTextMuted` | Character count, muted labels, remove button icons |
| `Color.lcTextSubtle` | Settings field labels (via `LCFormField`), day-of-month note |
| `Color.lcTextFaint` | Empty state icon, input placeholders |

### Fonts (used in this feature)

| Token | Usage |
|-------|-------|
| `.lcHeadingLarge` | Task name inline field (20px bold) |
| `.lcLabel` | Pane section headers, form field labels (via `LCFormField`) |
| `.lcInput` | Text field inputs (13px monospaced) |
| `.lcBodyMedium` | Unsaved banner text |
| `.lcCaption` | Character count, day-of-month note, cron human description |
| `.lcButton` | Primary button label |
| `.lcButtonSmall` | Toolbar and secondary button labels |

### Animations

| Token | Usage |
|-------|-------|
| `.lcQuick` | `Animation.easeInOut(duration: 0.15)` — dirty dot, discard button opacity |
| `.lcFadeSlide` | `AnyTransition` — unsaved banner entrance; schedule sub-picker entrance |

### Spacing and Radii

| Token | Value | Usage |
|-------|-------|-------|
| `LCRadius.button` | 6px | Text inputs, section cards, cron readout |
| `LCRadius.panel` | 10px | Settings section card corners |
| `LCRadius.badge` | 4px | Day-of-week chips, tag chips |
| `LCBorder.standard` | 1px | All card and input borders |

### Button Styles

| Style | Usage |
|-------|-------|
| `LCPrimaryButtonStyle()` | Save / Create Task button |
| `LCSecondaryButtonStyle()` | Discard button |
| `LCToolbarButtonStyle()` | Dry Run button, Add Variable button |

---

## Existing Components Available for Reuse

These are defined in `Views/TaskEditorView.swift` (bottom of file) and `Views/Components/`:

- `LCFormField(label:) { ... }` — wraps content with an uppercase label and 6px gap
- `LCTextField(text:placeholder:onSubmit:)` — styled text field with focus border
- `LCTextEditor(text:placeholder:)` — styled multi-line text editor
- `FlowLayout(spacing:)` — wraps tag chips into rows
- `TagChip(text:onRemove:)` — tag chip with remove button

These components must be used as-is. Do not copy or redeclare them.

---

## Phase 1 — Parallel Foundation Work

Phase 1 has two agents that work independently and must complete before Phase 2 begins.

---

### Agent 1 (swift-expert): SchedulePreset.swift + LCTaskDraft Equatable

#### Context: Files to Read Before Starting

- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Models/LCTask.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Models/Schedule.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Styles/LCAnimations.swift` (for `LCBorder`)

#### Task A: Create `Models/SchedulePreset.swift`

Create the file at:
```
/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Models/SchedulePreset.swift
```

The file must contain exactly this enum with all computed properties and methods implemented:

```swift
import Foundation

enum SchedulePreset: String, CaseIterable, Identifiable {
    case every5Min    = "every_5_min"
    case every10Min   = "every_10_min"
    case every15Min   = "every_15_min"
    case every30Min   = "every_30_min"
    case everyHour    = "every_hour"
    case every2Hours  = "every_2_hours"
    case every4Hours  = "every_4_hours"
    case dailyAt      = "daily_at"
    case weekdaysAt   = "weekdays_at"
    case weeklyOn     = "weekly_on"
    case monthlyOn    = "monthly_on"
    case custom       = "custom"

    var id: String { rawValue }
}
```

Implement all computed properties and methods below. Full bodies are required — not stubs.

**`var displayName: String`**

Returns the user-facing label shown in the picker menu:

| Case | Return Value |
|------|-------------|
| `every5Min` | `"Every 5 minutes"` |
| `every10Min` | `"Every 10 minutes"` |
| `every15Min` | `"Every 15 minutes"` |
| `every30Min` | `"Every 30 minutes"` |
| `everyHour` | `"Every hour"` |
| `every2Hours` | `"Every 2 hours"` |
| `every4Hours` | `"Every 4 hours"` |
| `dailyAt` | `"Daily at..."` |
| `weekdaysAt` | `"Weekdays at..."` |
| `weeklyOn` | `"Weekly on..."` |
| `monthlyOn` | `"Monthly on..."` |
| `custom` | `"Custom (Advanced)"` |

**`var requiresTimePicker: Bool`**

Returns `true` for: `dailyAt`, `weekdaysAt`, `weeklyOn`, `monthlyOn`. Returns `false` for all others.

**`var requiresDayOfWeekPicker: Bool`**

Returns `true` only for `weeklyOn`. Returns `false` for all others.

**`var requiresDayOfMonthPicker: Bool`**

Returns `true` only for `monthlyOn`. Returns `false` for all others.

**`var isCustom: Bool`**

Returns `true` only for `custom`. Returns `false` for all others.

**`func cronExpression(hour: Int, minute: Int, weekdays: Set<Int>, dayOfMonth: Int) -> String`**

Generates the cron string using this exact conversion table:

| Case | Cron Expression | Notes |
|------|----------------|-------|
| `every5Min` | `"*/5 * * * *"` | Fixed, ignores all parameters |
| `every10Min` | `"*/10 * * * *"` | Fixed |
| `every15Min` | `"*/15 * * * *"` | Fixed |
| `every30Min` | `"*/30 * * * *"` | Fixed |
| `everyHour` | `"0 * * * *"` | Fixed |
| `every2Hours` | `"0 */2 * * *"` | Fixed |
| `every4Hours` | `"0 */4 * * *"` | Fixed |
| `dailyAt` | `"\(minute) \(hour) * * *"` | Uses `hour` and `minute` |
| `weekdaysAt` | `"\(minute) \(hour) * * 1-5"` | Uses `hour` and `minute` |
| `weeklyOn` | `"\(minute) \(hour) * * \(weekdayList)"` | Uses `hour`, `minute`, and `weekdays` sorted ascending, comma-separated |
| `monthlyOn` | `"\(minute) \(hour) \(dayOfMonth) * *"` | Uses `hour`, `minute`, `dayOfMonth` |
| `custom` | `""` | Returns empty string; caller supplies raw cron |

For `weeklyOn`, if `weekdays` is empty, fall back to `"1"` (Monday). Sort the weekday integers ascending before joining with commas.

**`func humanDescription(hour: Int, minute: Int, weekdays: Set<Int>, dayOfMonth: Int) -> String`**

Generates a human-readable description:

| Case | Return Value |
|------|-------------|
| `every5Min` | `"Every 5 minutes"` |
| `every10Min` | `"Every 10 minutes"` |
| `every15Min` | `"Every 15 minutes"` |
| `every30Min` | `"Every 30 minutes"` |
| `everyHour` | `"Every hour"` |
| `every2Hours` | `"Every 2 hours"` |
| `every4Hours` | `"Every 4 hours"` |
| `dailyAt` | `"Every day at \(timeString)"` where `timeString` = `String(format: "%02d:%02d", hour, minute)` |
| `weekdaysAt` | `"Every weekday at \(timeString)"` |
| `weeklyOn` | `"Weekly on \(dayNameList) at \(timeString)"` |
| `monthlyOn` | `"Monthly on the \(dayOfMonth)\(ordinal(dayOfMonth)) at \(timeString)"` |
| `custom` | `"Custom schedule"` |

For `weeklyOn`, convert each weekday integer to its abbreviated name using `["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]` (index 0 = Sunday), sort ascending by integer value, and join with `", "`.

For `monthlyOn`, the ordinal suffix function returns `"st"` for 1, 21; `"nd"` for 2, 22; `"rd"` for 3, 23; `"th"` for everything else.

#### Task B: Modify `Models/LCTask.swift`

Add the following extension at the bottom of the file, after the last existing `// MARK:` section. Do not modify any existing code:

```swift
// MARK: - LCTaskDraft Equatable

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

#### Contracts (what downstream agents depend on)

- `SchedulePreset` is a `CaseIterable`, `Identifiable` enum with `String` raw values.
- `SchedulePreset.cronExpression(hour:minute:weekdays:dayOfMonth:)` is the single source of truth for cron string generation.
- `SchedulePreset.humanDescription(hour:minute:weekdays:dayOfMonth:)` is the single source of truth for human-readable descriptions.
- `LCTaskDraft` conforms to `Equatable` via the extension in `LCTask.swift`.
- Agent 2 depends on both of these contracts to build `EditorViewModel`.

#### Constraints

- Do not modify any existing property or method in `LCTask.swift`.
- Do not import SwiftUI in `SchedulePreset.swift` — it is a pure model type that only needs `Foundation`.
- The `custom` case `cronExpression` returns `""` intentionally; `EditorViewModel` handles this by using `draft.schedule` directly when preset is `.custom`.

#### Verification

```bash
cd /Users/hitch/Desktop/git/loop-commander/macos-app && swift build 2>&1 | grep -E "error:|Build complete"
```

The build must produce `Build complete!` with no errors before handing off to Phase 2.

---

### Agent 6 (rust-engineer): Add `schedule.validate` to Rust daemon (Optional)

This agent's work is independent and additive. The Swift app functions without it by falling back to client-side validation. If this method is not implemented, the Swift layer gracefully handles JSON-RPC error -32601 (method not found).

#### Context: Files to Read Before Starting

```
/Users/hitch/Desktop/git/loop-commander/lc-scheduler/Cargo.toml
/Users/hitch/Desktop/git/loop-commander/lc-scheduler/src/lib.rs
/Users/hitch/Desktop/git/loop-commander/lc-daemon/src/server.rs
/Users/hitch/Desktop/git/loop-commander/lc-core/src/ipc.rs
```

#### Task: Add `schedule.validate` RPC method

**Step 1: `lc-scheduler/Cargo.toml`**

Add to `[dependencies]`:
```toml
cron = "0.12"
```

**Step 2: `lc-scheduler/src/lib.rs`** (or a new `src/validate.rs` module)

Add a public function:
```rust
pub fn validate_cron(expr: &str) -> Result<(), String> {
    expr.parse::<cron::Schedule>()
        .map(|_| ())
        .map_err(|e| e.to_string())
}
```

**Step 3: `lc-daemon/src/server.rs`**

Register a handler for `"schedule.validate"`. The handler must:
1. Deserialize `params` as `{ "expression": String }`.
2. Call `lc_scheduler::validate_cron(&expression)`.
3. On success: return `{ "valid": true }`.
4. On error: return `{ "valid": false, "error": "<message>" }`.

The response is always a successful JSON-RPC result (never an error response) unless params are missing/malformed.

**JSON-RPC contract:**

Request:
```json
{ "jsonrpc": "2.0", "id": 1, "method": "schedule.validate", "params": { "expression": "0 9 * * 1-5" } }
```

Success response:
```json
{ "jsonrpc": "2.0", "id": 1, "result": { "valid": true } }
```

Failure response:
```json
{ "jsonrpc": "2.0", "id": 1, "result": { "valid": false, "error": "invalid day-of-week value: 8" } }
```

#### Constraints

- Zero changes to any existing method, schema, data format, or crate interface.
- This is a purely additive change. Existing clients that do not call this method are unaffected.
- Do not change `lc-core`, `lc-config`, `lc-runner`, `lc-logger`, or `lc-cli`.

#### Verification

```bash
cd /Users/hitch/Desktop/git/loop-commander && cargo test --workspace 2>&1 | tail -5
```

All existing tests must continue to pass.

---

## Phase 2 — EditorViewModel (Sequential)

Phase 2 begins after Phase 1 is complete. Agent 2 must complete before Agent 3 begins.

---

### Agent 2 (swift-expert): Create `EditorViewModel.swift`

#### Context: Files to Read Before Starting

- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Models/LCTask.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Models/SchedulePreset.swift` (created by Agent 1)
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/ViewModels/TaskEditorViewModel.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Services/DaemonClient.swift`

#### Task: Create `ViewModels/EditorViewModel.swift`

Create the file at:
```
/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/ViewModels/EditorViewModel.swift
```

**EditorState enum** (define inside the file, not nested):

```swift
enum EditorState: Equatable {
    case empty
    case creating
    case editing(taskId: String)
}
```

**EditorViewModel class:**

```swift
import Foundation
import SwiftUI

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
    @Published var selectedWeekdays: Set<Int> = [1]   // 0=Sun, 1=Mon, ..., 6=Sat
    @Published var selectedDayOfMonth: Int = 1
    @Published var showDiscardAlert: Bool = false
    @Published var showSavedConfirmation: Bool = false

    // MARK: - Internal State

    private var originalSnapshot: LCTaskDraft?
    private var taskId: String?
    private var client: DaemonClient?
```

**Computed properties** (implement fully):

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

    var isCreating: Bool {
        if case .creating = editorState { return true }
        return false
    }
```

**`setClient`:**

```swift
    func setClient(_ client: DaemonClient) {
        self.client = client
    }
```

**`startNewTask`:**

Sets `editorState = .creating`, resets `draft = LCTaskDraft()`, sets `originalSnapshot = nil`, sets `taskId = nil`. Resets `schedulePreset = .every15Min`, `selectedHour = 9`, `selectedMinute = 0`, `selectedWeekdays = [1]`, `selectedDayOfMonth = 1`. Clears `error` and `validationErrors`.

**`loadTask(_ task: LCTask)`:**

Sets `editorState = .editing(taskId: task.id)`. Creates `let d = LCTaskDraft(from: task)`. Assigns `draft = d` and `originalSnapshot = d`. Sets `taskId = task.id`. Clears `error` and `validationErrors`. Calls `inferPresetFromCron(draft.schedule)`.

**`loadFromImportedCommand(_ command: ClaudeCommand)`:**

Sets `editorState = .creating`. Creates `let d = LCTaskDraft(from: command)`. Assigns `draft = d`. Sets `originalSnapshot = nil`, `taskId = nil`. Clears `error` and `validationErrors`. Calls `inferPresetFromCron(draft.schedule)`.

**`validate() -> Bool`:**

Copy the complete validation logic from `TaskEditorViewModel.validate()`. The rules are:
- Task name not empty (trimmed): `"Task name is required"`
- Task name length <= 200: `"Task name must be 200 characters or fewer"`
- Command not empty (trimmed): `"Command is required"`
- Command length <= 10,000: `"Command must be 10,000 characters or fewer"`
- `maxBudget > 0`: `"Budget must be greater than 0"`
- `maxBudget <= 100`: `"Budget must be $100 or less"`
- `timeoutSecs > 0`: `"Timeout must be greater than 0"`
- `timeoutSecs <= 86400`: `"Timeout must be 86400 seconds or less"`
- `tags.count <= 20`: `"Maximum 20 tags allowed"`

Populates `validationErrors`. Returns `true` if empty.

**`save() async -> Bool`:**

1. Calls `validate()`. Returns `false` if invalid.
2. Returns `false` if `client == nil`.
3. Sets `isSaving = true`, clears `error`.
4. In a `do/catch`:
   - If `isCreating`: calls `try await client.createTask(draft.toCreateInput())`.
   - If editing: calls `try await client.updateTask(draft.toUpdateInput(id: taskId!))`.
   - On success: sets `originalSnapshot = draft` (for editing), sets `isSaving = false`, sets `showSavedConfirmation = true`, posts `Notification.Name.refreshData` notification, returns `true`.
   - On error: sets `self.error = error.localizedDescription`, sets `isSaving = false`, returns `false`.

**`discard()`:**

```swift
    func discard() {
        showDiscardAlert = false
        switch editorState {
        case .empty:
            break
        case .creating:
            editorState = .empty
            draft = LCTaskDraft()
            originalSnapshot = nil
            taskId = nil
        case .editing:
            if let snapshot = originalSnapshot {
                draft = snapshot
            }
        }
        validationErrors = []
        error = nil
        // Re-sync the schedule picker to the (restored) draft
        inferPresetFromCron(draft.schedule)
    }
```

**`confirmDiscard()`:**

```swift
    func confirmDiscard() {
        showDiscardAlert = true
    }
```

**`syncCronFromPreset()`:**

Called whenever `schedulePreset`, `selectedHour`, `selectedMinute`, `selectedWeekdays`, or `selectedDayOfMonth` changes. Updates `draft.schedule` and `draft.scheduleHuman`.

```swift
    func syncCronFromPreset() {
        guard schedulePreset != .custom else { return }
        draft.schedule = schedulePreset.cronExpression(
            hour: selectedHour,
            minute: selectedMinute,
            weekdays: selectedWeekdays,
            dayOfMonth: selectedDayOfMonth
        )
        draft.scheduleHuman = schedulePreset.humanDescription(
            hour: selectedHour,
            minute: selectedMinute,
            weekdays: selectedWeekdays,
            dayOfMonth: selectedDayOfMonth
        )
    }
```

**`toggleWeekday(_ index: Int)`:**

Toggles the presence of `index` in `selectedWeekdays`. If `selectedWeekdays` currently contains only `index` (i.e., removing it would leave the set empty), do nothing (at least one day must remain selected). After toggling, call `syncCronFromPreset()`.

**`inferPresetFromCron(_ cron: String)`:**

Parses a cron string and sets `schedulePreset` plus the sub-picker state values. Uses regex or string-splitting. The matching rules are:

| Cron Pattern | Sets `schedulePreset` to | Also Sets |
|-------------|--------------------------|-----------|
| `*/5 * * * *` | `.every5Min` | — |
| `*/10 * * * *` | `.every10Min` | — |
| `*/15 * * * *` | `.every15Min` | — |
| `*/30 * * * *` | `.every30Min` | — |
| `0 * * * *` | `.everyHour` | — |
| `0 */2 * * *` | `.every2Hours` | — |
| `0 */4 * * *` | `.every4Hours` | — |
| `{M} {H} * * *` where H, M are plain integers | `.dailyAt` | `selectedHour = H`, `selectedMinute = M` |
| `{M} {H} * * 1-5` | `.weekdaysAt` | `selectedHour = H`, `selectedMinute = M` |
| `{M} {H} * * {D,...}` where D-field is a comma-separated list of integers | `.weeklyOn` | `selectedHour = H`, `selectedMinute = M`, `selectedWeekdays = Set(parsedInts)` |
| `{M} {H} {D} * *` where H, M, D are plain integers | `.monthlyOn` | `selectedHour = H`, `selectedMinute = M`, `selectedDayOfMonth = D` |
| (anything else) | `.custom` | — |

For the matching, split the cron string by spaces into exactly 5 fields. Match fields against the patterns above from most-specific to least-specific. If parsing fails for any reason, fall back to `.custom`.

#### Contracts (what downstream agents depend on)

- `EditorViewModel` is `@MainActor`, `ObservableObject`, class.
- `EditorState` is a top-level enum with cases `.empty`, `.creating`, `.editing(taskId: String)`.
- `vm.draft` is type `LCTaskDraft`.
- `vm.isDirty: Bool` is computed correctly from state + snapshot comparison.
- `vm.isCreating: Bool` returns true iff `editorState == .creating`.
- `vm.startNewTask()`, `vm.loadTask(_:)`, `vm.loadFromImportedCommand(_:)` are the three entry points from outside.
- `vm.save() async -> Bool` handles both create and update paths.
- `vm.syncCronFromPreset()` is called by `ScheduleBuilderView` on picker changes.
- `vm.toggleWeekday(_:)` is called by `ScheduleBuilderView` day chips.
- `vm.schedulePreset`, `vm.selectedHour`, `vm.selectedMinute`, `vm.selectedWeekdays`, `vm.selectedDayOfMonth` are all `@Published` and bindable.
- `vm.showDiscardAlert`, `vm.validationErrors`, `vm.error`, `vm.isSaving`, `vm.showSavedConfirmation` are `@Published`.
- Agent 3 (`ScheduleBuilderView`) and Agent 4 (`EditorView`) both depend on all of these.

#### Constraints

- `TaskEditorViewModel.swift` must not be modified.
- Do not use `@StateObject` inside `EditorViewModel` — it is itself the `ObservableObject`.
- The `setClient` method is called from `EditorView.onAppear` via the `DaemonMonitor` environment object.

#### Verification

```bash
cd /Users/hitch/Desktop/git/loop-commander/macos-app && swift build 2>&1 | grep -E "error:|Build complete"
```

Build must succeed before Agent 3 begins.

---

### Agent 3 (swift-expert): Create `ScheduleBuilderView.swift`

Agent 3 runs after Agent 2. It depends on `EditorViewModel` and `SchedulePreset`.

#### Context: Files to Read Before Starting

- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/ViewModels/EditorViewModel.swift` (created by Agent 2)
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Models/SchedulePreset.swift` (created by Agent 1)
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Views/TaskEditorView.swift` (for `LCFormField`, `LCTextField` usage patterns)
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Styles/LCAnimations.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Styles/LCRadius.swift`

#### Task: Create `Views/ScheduleBuilderView.swift`

Create the file at:
```
/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Views/ScheduleBuilderView.swift
```

The top-level struct:

```swift
import SwiftUI

struct ScheduleBuilderView: View {
    @ObservedObject var vm: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            presetPicker
            subPicker
            cronReadout
        }
    }
}
```

**`presetPicker`** (private computed view):

```swift
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

**`subPicker`** (private `@ViewBuilder` computed view):

Uses `.animation(.lcFadeSlide, value: vm.schedulePreset)` on the container so sub-pickers animate in and out when the preset changes.

```swift
@ViewBuilder
private var subPicker: some View {
    if vm.schedulePreset.requiresTimePicker {
        timeSubPicker
            .transition(.lcFadeSlide)
    }
    if vm.schedulePreset.requiresDayOfWeekPicker {
        dayOfWeekSubPicker
            .transition(.lcFadeSlide)
    }
    if vm.schedulePreset.requiresDayOfMonthPicker {
        dayOfMonthSubPicker
            .transition(.lcFadeSlide)
    }
    if vm.schedulePreset.isCustom {
        customCronField
            .transition(.lcFadeSlide)
    }
}
```

**`timeSubPicker`** (private computed view):

```swift
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
            .onChange(of: vm.selectedHour) { _ in vm.syncCronFromPreset() }

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
            .onChange(of: vm.selectedMinute) { _ in vm.syncCronFromPreset() }
        }
    }
}
```

**`dayOfWeekSubPicker`** (private computed view):

Uses `DayChip` (defined below in the same file). Renders chips for `["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]` at indices 0–6. Calls `vm.toggleWeekday(index)` on tap.

```swift
private var dayOfWeekSubPicker: some View {
    LCFormField(label: "Day of Week") {
        HStack(spacing: 4) {
            ForEach(
                Array(["Sun","Mon","Tue","Wed","Thu","Fri","Sat"].enumerated()),
                id: \.offset
            ) { index, name in
                DayChip(
                    label: name,
                    isSelected: vm.selectedWeekdays.contains(index)
                ) {
                    vm.toggleWeekday(index)
                }
            }
        }
    }
}
```

**`dayOfMonthSubPicker`** (private computed view):

```swift
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

**`customCronField`** (private computed view):

```swift
private var customCronField: some View {
    LCFormField(label: "Cron Expression") {
        LCTextField(text: $vm.draft.schedule, placeholder: "*/15 * * * *")
    }
}
```

When in custom mode, the user edits `vm.draft.schedule` directly. `vm.draft.scheduleHuman` is not auto-updated (it shows stale or "Custom schedule" as returned by `SchedulePreset.custom.humanDescription`). This is acceptable; the cron readout below always shows the live expression.

**`cronReadout`** (private computed view):

Always visible. Displays `vm.draft.schedule` and `vm.draft.scheduleHuman`. When `schedulePreset == .custom` and the cron expression is empty or invalid (simple check: split by spaces, count != 5), show the error state.

```swift
private var cronReadout: some View {
    let isInvalid = vm.schedulePreset.isCustom &&
                    vm.draft.schedule.split(separator: " ").count != 5
    return VStack(alignment: .leading, spacing: 3) {
        if isInvalid {
            Text("Invalid cron expression")
                .font(.lcCaption)
                .foregroundColor(.lcRed)
        } else {
            Text(vm.draft.schedule.isEmpty ? "—" : vm.draft.schedule)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.lcAccentLight)
            Text(vm.draft.scheduleHuman.isEmpty ? "—" : vm.draft.scheduleHuman)
                .font(.lcCaption)
                .foregroundColor(.lcTextSecondary)
        }
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(isInvalid ? Color.lcRedBg : Color.lcCodeBackground)
    .overlay(
        RoundedRectangle(cornerRadius: LCRadius.button)
            .stroke(
                isInvalid ? Color.lcRedBorder : Color.lcBorder,
                lineWidth: 1
            )
    )
    .cornerRadius(LCRadius.button)
    .textSelection(.enabled)
    .accessibilityLabel("Cron expression: \(vm.draft.schedule). Meaning: \(vm.draft.scheduleHuman)")
}
```

**`DayChip`** (private struct, defined at the bottom of the file):

A small toggle chip for day-of-week selection. Selected state: `lcAccentBgSubtle` background, `lcAccent` border, `lcAccentLight` foreground. Unselected state: `lcSurfaceContainer` background, `lcBorderInput` border, `lcTextMuted` foreground. Corner radius: `LCRadius.badge` (4px). Font: `.system(size: 11, weight: .semibold, design: .monospaced)`.

```swift
private struct DayChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(isSelected ? .lcAccentLight : .lcTextMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isSelected ? Color.lcAccentBgSubtle : Color.lcSurfaceContainer)
                .overlay(
                    RoundedRectangle(cornerRadius: LCRadius.badge)
                        .stroke(
                            isSelected ? Color.lcAccent : Color.lcBorderInput,
                            lineWidth: 1
                        )
                )
                .cornerRadius(LCRadius.badge)
        }
        .buttonStyle(.plain)
    }
}
```

#### Contracts (what downstream agents depend on)

- `ScheduleBuilderView` is a `View` that takes `@ObservedObject var vm: EditorViewModel`.
- It is a self-contained component with no external state dependencies beyond `vm`.
- Agent 4 (`EditorView`) embeds `ScheduleBuilderView(vm: vm)` inside the Schedule settings section.

#### Constraints

- Do not embed `@StateObject` — use `@ObservedObject`.
- `LCFormField`, `LCTextField` are used from `TaskEditorView.swift` — do not redeclare them.
- `lcSurfaceContainer` color must be used for unselected day chips (verify the token exists in `Color+LoopCommander.swift`; if not, use `Color.lcCodeBackground` as fallback).
- The `customCronField` writes to `$vm.draft.schedule` directly. This is correct.

#### Verification

```bash
cd /Users/hitch/Desktop/git/loop-commander/macos-app && swift build 2>&1 | grep -E "error:|Build complete"
```

---

## Phase 3 — EditorView

Phase 3 begins after Phase 2 is complete.

---

### Agent 4 (swift-expert): Create `EditorView.swift`

#### Context: Files to Read Before Starting

- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/ViewModels/EditorViewModel.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Views/ScheduleBuilderView.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Views/TaskEditorView.swift` (for `LCFormField`, `LCTextField`, `LCTextEditor`, `FlowLayout`, `TagChip`)
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Views/TaskDetailView.swift` (for dry-run presentation pattern)
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Services/DaemonMonitor.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Styles/LCButtonStyles.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Styles/LCAnimations.swift`

#### Task: Create `Views/EditorView.swift`

Create the file at:
```
/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Views/EditorView.swift
```

**Top-level struct:**

```swift
import SwiftUI

struct EditorView: View {
    @ObservedObject var vm: EditorViewModel
    @EnvironmentObject var daemonMonitor: DaemonMonitor
    @State private var tagInput: String = ""

    var body: some View {
        switch vm.editorState {
        case .empty:
            emptyState
        case .creating, .editing:
            editorContent
        }
    }
}
```

**`emptyState`** (private computed view):

Centered `VStack(spacing: 12)` with `frame(maxWidth: .infinity, maxHeight: .infinity)` and `Color.lcBackground` background.

```swift
private var emptyState: some View {
    VStack(spacing: 12) {
        Image(systemName: "pencil.and.outline")
            .font(.system(size: 48))
            .foregroundColor(.lcTextFaint)
        Text("No task loaded")
            .font(.lcBodyMedium)
            .foregroundColor(.lcTextMuted)
        Text("Create a new task or open one from the Tasks tab.")
            .font(.lcCaption)
            .foregroundColor(.lcTextSubtle)
        Button("+ New Task") {
            vm.startNewTask()
        }
        .buttonStyle(LCPrimaryButtonStyle())
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.lcBackground)
}
```

**`editorContent`** (private computed view):

A `VStack(spacing: 0)` containing `editorTopBar`, `unsavedChangesBanner`, and `editorPanes`. Apply `.animation(.lcQuick, value: vm.isDirty)` to the VStack so the banner animates in and out.

```swift
private var editorContent: some View {
    VStack(spacing: 0) {
        editorTopBar
        unsavedChangesBanner
        editorPanes
    }
    .animation(.lcQuick, value: vm.isDirty)
    .onAppear {
        vm.setClient(daemonMonitor.client)
    }
    .alert("Discard changes?", isPresented: $vm.showDiscardAlert) {
        Button("Discard", role: .destructive) { vm.discard() }
        Button("Cancel", role: .cancel) {}
    } message: {
        Text("Your unsaved edits will be lost.")
    }
}
```

**`editorTopBar`** (private `@ViewBuilder` computed view):

Fixed header. Background `lcSurface`. Bottom border: 1px `lcSeparator`. Horizontal padding 20px, vertical padding 14px.

```swift
@ViewBuilder
private var editorTopBar: some View {
    HStack(spacing: 8) {
        TextField("Untitled Task", text: $vm.draft.name)
            .font(.lcHeadingLarge)
            .textFieldStyle(.plain)
            .foregroundColor(.lcTextPrimary)
            .accessibilityLabel("Task name")

        Spacer()

        if case .editing = vm.editorState {
            Button("Dry Run") {
                // Post a notification to trigger dry run in TaskDetailView,
                // or present a DryRunSheet if the pattern is available.
                // For now, this is a placeholder that can be wired later.
            }
            .buttonStyle(LCToolbarButtonStyle())
            .keyboardShortcut("r", modifiers: [.command, .option])
        }

        if vm.isDirty {
            Button("Discard") {
                vm.confirmDiscard()
            }
            .buttonStyle(LCSecondaryButtonStyle())
            .transition(.opacity)
            .animation(.lcQuick, value: vm.isDirty)
        }

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
        Rectangle()
            .fill(Color.lcSeparator)
            .frame(height: 1)
    }
}
```

**`unsavedChangesBanner`** (private `@ViewBuilder` computed view):

Shown only when `vm.isDirty`. Uses `.transition(.lcFadeSlide)`.

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
            Rectangle()
                .fill(Color.lcAmber.opacity(0.2))
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.lcSeparator)
                .frame(height: 1)
        }
        .transition(.lcFadeSlide)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}
```

**`editorPanes`** (private computed view):

Fixed 60/40 split using `GeometryReader`. The pane ratio is not user-adjustable.

```swift
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

**`promptEditorPane`** (private computed view):

```swift
private var promptEditorPane: some View {
    VStack(spacing: 0) {
        // Pane header
        HStack {
            Text("PROMPT / COMMAND")
                .font(.lcLabel)
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.5)
                .textCase(.uppercase)
            Spacer()
            Text("\(vm.draft.command.count) chars")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.lcTextMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)

        // Main text editor fills remaining height
        LCTextEditor(
            text: $vm.draft.command,
            placeholder: "claude -p 'Your prompt here...'"
        )
        .frame(maxHeight: .infinity)

        // Footer
        Rectangle()
            .fill(Color.lcBorder)
            .frame(height: 1)
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

**`settingsPane`** (private computed view):

```swift
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

**`settingsSection`** (private helper method):

Wraps content in a section card with `lcSurfaceContainer` background, `lcBorder` border, `LCRadius.panel` corners, and 16px internal padding. The section header label uses `lcLabel` uppercase tracking treatment (same as `LCFormField`).

```swift
@ViewBuilder
private func settingsSection<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title.uppercased())
            .font(.lcLabel)
            .foregroundColor(.white.opacity(0.5))
            .tracking(0.5)
        content()
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.lcSurfaceContainer)
    .overlay(
        RoundedRectangle(cornerRadius: LCRadius.panel)
            .stroke(Color.lcBorder, lineWidth: LCBorder.standard)
    )
    .cornerRadius(LCRadius.panel)
}
```

**`taskSection`** (private `@ViewBuilder` computed view):

Contains the Skill field only:

```swift
@ViewBuilder
private var taskSection: some View {
    LCFormField(label: "Skill (optional)") {
        LCTextField(
            text: $vm.draft.skill,
            placeholder: "/review-pr, /loop, etc."
        )
    }
}
```

**`scheduleSection`** (private `@ViewBuilder` computed view):

Embeds `ScheduleBuilderView`:

```swift
@ViewBuilder
private var scheduleSection: some View {
    ScheduleBuilderView(vm: vm)
}
```

**`executionSection`** (private `@ViewBuilder` computed view):

Three fields stacked vertically: working directory (with folder picker button), budget, timeout.

```swift
@ViewBuilder
private var executionSection: some View {
    LCFormField(label: "Working Directory") {
        HStack(spacing: 8) {
            LCTextField(
                text: $vm.draft.workingDir,
                placeholder: "~/projects/my-repo"
            )
            Button {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.prompt = "Select"
                panel.message = "Choose a working directory for this task"
                if panel.runModal() == .OK, let url = panel.url {
                    vm.draft.workingDir = url.path
                }
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .foregroundColor(.lcTextMuted)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .background(Color.lcCodeBackground)
            .overlay(
                RoundedRectangle(cornerRadius: LCRadius.button)
                    .stroke(Color.lcBorderInput, lineWidth: 1)
            )
            .cornerRadius(LCRadius.button)
            .accessibilityLabel("Browse for working directory")
        }
    }

    LCFormField(label: "Budget per Run ($)") {
        LCTextField(
            text: Binding(
                get: { String(format: "%.1f", vm.draft.maxBudget) },
                set: { vm.draft.maxBudget = Double($0) ?? 5.0 }
            ),
            placeholder: "5.0"
        )
    }

    LCFormField(label: "Timeout (seconds)") {
        LCTextField(
            text: Binding(
                get: { "\(vm.draft.timeoutSecs)" },
                set: { vm.draft.timeoutSecs = Int($0) ?? 600 }
            ),
            placeholder: "600"
        )
    }
}
```

**`tagsSection`** (private `@ViewBuilder` computed view):

Uses `tagInput: @State private var tagInput: String = ""` declared at the top of `EditorView`.

```swift
@ViewBuilder
private var tagsSection: some View {
    LCFormField(label: "Tags") {
        VStack(alignment: .leading, spacing: 8) {
            LCTextField(
                text: $tagInput,
                placeholder: "Add a tag and press Enter",
                onSubmit: {
                    let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && vm.draft.tags.count < 20 {
                        vm.draft.tags.append(trimmed)
                        tagInput = ""
                    }
                }
            )
            if !vm.draft.tags.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(Array(vm.draft.tags.enumerated()), id: \.offset) { idx, tag in
                        TagChip(text: tag) {
                            vm.draft.tags.remove(at: idx)
                        }
                    }
                }
            }
        }
    }
}
```

**`envVarsSection`** (private `@ViewBuilder` computed view):

Renders a column header row, a list of key-value rows, and an "Add Variable" button.

```swift
@ViewBuilder
private var envVarsSection: some View {
    // Column header
    if !vm.draft.envVars.isEmpty {
        HStack {
            Text("KEY")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.lcTextFaint)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("VALUE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.lcTextFaint)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: 28)
        }
    }

    // Env var rows
    ForEach(Array(vm.draft.envVars.keys.sorted().enumerated()), id: \.element) { _, key in
        EnvVarRow(
            key: key,
            value: Binding(
                get: { vm.draft.envVars[key] ?? "" },
                set: { vm.draft.envVars[key] = $0 }
            ),
            onRemove: { vm.draft.envVars.removeValue(forKey: key) }
        )
    }

    // Add Variable button
    Button {
        vm.draft.envVars["NEW_KEY_\(vm.draft.envVars.count)"] = ""
    } label: {
        HStack(spacing: 4) {
            Image(systemName: "plus")
                .font(.system(size: 11))
            Text("Add Variable")
                .font(.lcButtonSmall)
        }
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(LCToolbarButtonStyle())
}
```

**`EnvVarRow`** (private struct, defined in the same file):

Each row has a key field (40% width), a value field (fills remaining space), and a remove button. Values that have keys containing `TOKEN`, `SECRET`, `KEY`, `PASSWORD`, or `PASS` (case-insensitive) default to showing a secure field with a toggle.

```swift
private struct EnvVarRow: View {
    let key: String
    @Binding var value: String
    let onRemove: () -> Void
    @State private var isSecure: Bool = false

    private var looksLikeSecret: Bool {
        let upper = key.uppercased()
        return upper.contains("TOKEN") || upper.contains("SECRET") ||
               upper.contains("KEY") || upper.contains("PASSWORD") ||
               upper.contains("PASS")
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(key)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.lcTextMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if isSecure || looksLikeSecret {
                    SecureField("", text: $value)
                        .textFieldStyle(.plain)
                        .font(.lcInput)
                        .foregroundColor(.lcTextPrimary)
                } else {
                    TextField("", text: $value)
                        .textFieldStyle(.plain)
                        .font(.lcInput)
                        .foregroundColor(.lcTextPrimary)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color.lcCodeBackground)
            .overlay(
                RoundedRectangle(cornerRadius: LCRadius.button)
                    .stroke(Color.lcBorderInput, lineWidth: 1)
            )
            .cornerRadius(LCRadius.button)
            .frame(maxWidth: .infinity)

            Button {
                isSecure.toggle()
            } label: {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .font(.system(size: 11))
                    .foregroundColor(.lcTextMuted)
            }
            .buttonStyle(.plain)
            .frame(width: 20)
            .opacity(looksLikeSecret ? 1 : 0)

            Button(action: onRemove) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.lcTextMuted)
            }
            .buttonStyle(.plain)
            .frame(width: 20)
        }
    }
}
```

**Validation errors display:**

Inside `editorContent`, below `editorPanes` but still inside the `VStack(spacing: 0)`, conditionally render validation errors if `!vm.validationErrors.isEmpty`:

```swift
if !vm.validationErrors.isEmpty {
    VStack(alignment: .leading, spacing: 4) {
        ForEach(vm.validationErrors, id: \.self) { err in
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.lcRed)
                Text(err)
                    .font(.lcCaption)
                    .foregroundColor(.lcRed)
            }
        }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 8)
    .background(Color.lcBackground)
}
```

Also show general `vm.error` if present:

```swift
if let error = vm.error {
    HStack(spacing: 6) {
        Image(systemName: "xmark.circle.fill")
            .foregroundColor(.lcRed)
        Text(error)
            .font(.lcCaption)
            .foregroundColor(.lcRed)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 8)
    .background(Color.lcBackground)
}
```

#### Contracts (what downstream agents depend on)

- `EditorView` is a `View` that takes `@ObservedObject var vm: EditorViewModel` and reads `@EnvironmentObject var daemonMonitor: DaemonMonitor`.
- It calls `vm.setClient(daemonMonitor.client)` in `.onAppear` inside `editorContent`.
- Agent 5 instantiates it as `EditorView(vm: editorVM)` where `editorVM` is a `@StateObject` in `ContentView`.

#### Constraints

- `LCFormField`, `LCTextField`, `LCTextEditor`, `FlowLayout`, `TagChip` are used from `TaskEditorView.swift` — do not redeclare them.
- The folder picker uses `NSOpenPanel` synchronously (`runModal()`); this is the existing pattern in the codebase.
- The `EnvVarRow` uses sorted `envVars.keys` so the order is stable in the UI. This means adding a new key with a placeholder name (`"NEW_KEY_N"`) will sort it alphabetically; this is acceptable for v1.
- Do not add drag-and-drop to env var rows in this implementation.
- The Dry Run button in the top bar is a placeholder. It should exist in the UI but its action can be `{}` for now (full dry-run wiring is future work).

#### Verification

```bash
cd /Users/hitch/Desktop/git/loop-commander/macos-app && swift build 2>&1 | grep -E "error:|Build complete"
```

---

## Phase 4 — Integration Wiring

Phase 4 begins after Phase 3 is complete.

---

### Agent 5 (swift-expert): Modify SidebarView, ContentView, LoopCommanderApp

#### Context: Files to Read Before Starting

- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Views/SidebarView.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Views/ContentView.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/LoopCommanderApp.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Views/EditorView.swift` (created by Agent 4)
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/ViewModels/EditorViewModel.swift` (created by Agent 2)
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Styles/LCAnimations.swift`

#### Task A: Modify `Views/SidebarView.swift`

**Change 1: Extend `SidebarItem`**

The current enum has `.tasks` and `.logs`. Add `.editor` between them:

```swift
enum SidebarItem: Hashable {
    case tasks
    case editor    // NEW
    case logs
}
```

**Change 2: Update `SidebarView` struct signature**

Add `editorIsDirty: Bool` as a new `let` property:

```swift
struct SidebarView: View {
    @Binding var selection: SidebarItem?
    let activeCount: Int
    let editorIsDirty: Bool    // NEW
```

**Change 3: Update `sidebarButton` private method signature**

Add `dirtyDot: Bool` parameter:

```swift
private func sidebarButton(
    title: String,
    icon: String,
    item: SidebarItem,
    badge: String?,
    dirtyDot: Bool       // NEW
) -> some View
```

Inside the button label `HStack`, after `Spacer()` and before the badge `if let` block, add:

```swift
if dirtyDot {
    Circle()
        .fill(Color.lcAmber)
        .frame(width: 6, height: 6)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.15), value: dirtyDot)
}
```

The full accessibility label for the button must be computed: when `dirtyDot` is true and `item == .editor`, use `"Editor, unsaved changes"`; otherwise use `title`. Apply `.accessibilityLabel(dirtyDot && item == .editor ? "Editor, unsaved changes" : title)` to the `Button`.

**Change 4: Update navigation button VStack**

Replace the current two-button VStack with three buttons:

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
        dirtyDot: editorIsDirty
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

#### Task B: Modify `Views/ContentView.swift`

This is the most surgical change. Make each modification carefully.

**Change 1: Remove `TaskEditorState` enum**

Delete lines 3–16 (the entire `enum TaskEditorState` block). Do not remove any other code.

**Change 2: Add new notification names**

In the `extension Notification.Name` block, add three new cases alongside the existing ones:

```swift
extension Notification.Name {
    static let newTask = Notification.Name("com.loopcommander.newTask")         // KEEP
    static let refreshData = Notification.Name("com.loopcommander.refreshData") // KEEP
    static let switchToTasks = Notification.Name("com.loopcommander.switchToTasks") // KEEP
    static let switchToLogs = Notification.Name("com.loopcommander.switchToLogs")   // KEEP
    // NEW:
    static let editorNewTask = Notification.Name("com.loopcommander.editorNewTask")
    static let editorOpenTask = Notification.Name("com.loopcommander.editorOpenTask")
    static let editorOpenImport = Notification.Name("com.loopcommander.editorOpenImport")
    static let switchToEditor = Notification.Name("com.loopcommander.switchToEditor")
}
```

**Change 3: Update `ContentView` state properties**

Remove:
```swift
@State private var showingEditor: TaskEditorState? = nil
```

Add (in its place, within the struct):
```swift
@StateObject private var editorVM = EditorViewModel()
@State private var showingDirtyAlert: Bool = false
@State private var pendingNavigation: SidebarItem? = nil
```

Keep unchanged:
```swift
@State private var selectedSidebar: SidebarItem? = .tasks
@State private var selectedTaskId: String? = nil
@State private var showingImport = false
```

**Change 4: Replace `SidebarView` instantiation**

Current:
```swift
SidebarView(
    selection: $selectedSidebar,
    activeCount: dashboardVM.activeCount
)
```

New (pass `guardedSelection` binding and `editorIsDirty`):
```swift
SidebarView(
    selection: guardedSelection,
    activeCount: dashboardVM.activeCount,
    editorIsDirty: editorVM.isDirty
)
```

**Change 5: Add `guardedSelection` computed binding**

Add this computed property to `ContentView`:

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

**Change 6: Update the ZStack in `body`**

The ZStack currently contains `tasksLayout` and `LogsView()`. Add `EditorView` between them:

```swift
ZStack {
    tasksLayout
        .opacity(selectedSidebar == .tasks ? 1 : 0)
        .allowsHitTesting(selectedSidebar == .tasks)

    EditorView(vm: editorVM)                           // NEW
        .opacity(selectedSidebar == .editor ? 1 : 0)   // NEW
        .allowsHitTesting(selectedSidebar == .editor)   // NEW

    LogsView()
        .opacity(selectedSidebar == .logs ? 1 : 0)
        .allowsHitTesting(selectedSidebar == .logs)
}
```

**Change 7: Remove the modal overlay entirely**

Delete the entire `.overlay { ... }` block from `body`. This block currently renders the `Color.lcOverlay` backdrop, `CommandImportView`, and `editorView(for:)`. Replace it with a new, streamlined overlay that handles only `CommandImportView` for the import flow:

```swift
.overlay {
    if showingImport {
        Color.lcOverlay
            .ignoresSafeArea()
            .onTapGesture { showingImport = false }
            .transition(.opacity)

        CommandImportView(
            onImport: { command in
                showingImport = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    NotificationCenter.default.post(
                        name: .editorOpenImport,
                        object: nil,
                        userInfo: ["command": command]
                    )
                }
            },
            onDismiss: { showingImport = false }
        )
        .lcModalShadow()
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .onExitCommand { showingImport = false }
    }
}
.animation(.easeInOut(duration: 0.2), value: showingImport)
```

**Change 8: Remove `editorView(for:)` method**

Delete the entire `editorView(for:)` method.

**Change 9: Remove `.animation` on `showingEditor?.id`**

Delete the line:
```swift
.animation(.easeInOut(duration: 0.2), value: showingEditor?.id)
```

**Change 10: Add the dirty navigation alert**

Add to `body` (as a `.alert` modifier on the root `HSplitView` or its wrapper):

```swift
.alert("You have unsaved changes", isPresented: $showingDirtyAlert) {
    Button("Save") {
        Task {
            let saved = await editorVM.save()
            if saved, let dest = pendingNavigation {
                selectedSidebar = dest
                pendingNavigation = nil
            }
        }
    }
    Button("Discard Changes", role: .destructive) {
        editorVM.discard()
        if let dest = pendingNavigation {
            selectedSidebar = dest
            pendingNavigation = nil
        }
    }
    Button("Cancel", role: .cancel) {
        pendingNavigation = nil
    }
} message: {
    Text("Do you want to save your changes before leaving the Editor?")
}
```

**Change 11: Update notification handlers**

Remove the existing:
```swift
.onReceive(NotificationCenter.default.publisher(for: .newTask)) { _ in
    showingEditor = .new
}
```

Add the new handlers (keep `.refreshData`, `.switchToTasks`, `.switchToLogs` unchanged):

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
.onReceive(NotificationCenter.default.publisher(for: .editorOpenImport)) { notification in
    if let command = notification.userInfo?["command"] as? ClaudeCommand {
        editorVM.loadFromImportedCommand(command)
        selectedSidebar = .editor
    }
}
.onReceive(NotificationCenter.default.publisher(for: .switchToEditor)) { _ in
    selectedSidebar = .editor
}
```

**Change 12: Update `tasksLayout` callbacks**

In `tasksLayout`, update the `TaskListView` instantiation:

Current:
```swift
TaskListView(
    selectedTaskId: $selectedTaskId,
    onNewTask: { showingEditor = .new },
    onImportCommand: { showingImport = true }
)
```

New:
```swift
TaskListView(
    selectedTaskId: $selectedTaskId,
    onNewTask: {
        NotificationCenter.default.post(name: .editorNewTask, object: nil)
    },
    onImportCommand: { showingImport = true }
)
```

Update the `TaskDetailView` instantiation:

Current:
```swift
TaskDetailView(
    taskId: taskId,
    onEdit: { task in showingEditor = .editing(task) },
    onDelete: { ... }
)
```

New:
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
    onDelete: {
        selectedTaskId = nil
        Task { await taskListVM.loadTasks() }
    }
)
```

#### Task C: Modify `LoopCommanderApp.swift`

**Change 1: Update the "New Task" command**

The existing command posts `.newTask`. Update it to post `.editorNewTask`:

Current:
```swift
Button("New Task") {
    NotificationCenter.default.post(name: .newTask, object: nil)
}
.keyboardShortcut("n", modifiers: .command)
```

New:
```swift
Button("New Task") {
    NotificationCenter.default.post(name: .editorNewTask, object: nil)
}
.keyboardShortcut("n", modifiers: .command)
```

**Change 2: Add "Editor" to the View menu**

Current View menu:
```swift
CommandMenu("View") {
    Button("Tasks") { ... }.keyboardShortcut("1", modifiers: .command)
    Button("Logs") { ... }.keyboardShortcut("2", modifiers: .command)
    Divider()
    Button("Refresh") { ... }.keyboardShortcut("r", modifiers: [.command, .shift])
}
```

New View menu (add Editor between Tasks and Logs; renumber Logs to Cmd+3):
```swift
CommandMenu("View") {
    Button("Tasks") {
        NotificationCenter.default.post(name: .switchToTasks, object: nil)
    }
    .keyboardShortcut("1", modifiers: .command)

    Button("Editor") {
        NotificationCenter.default.post(name: .switchToEditor, object: nil)
    }
    .keyboardShortcut("2", modifiers: .command)

    Button("Logs") {
        NotificationCenter.default.post(name: .switchToLogs, object: nil)
    }
    .keyboardShortcut("3", modifiers: .command)

    Divider()

    Button("Refresh") {
        NotificationCenter.default.post(name: .refreshData, object: nil)
    }
    .keyboardShortcut("r", modifiers: [.command, .shift])
}
```

**Change 3: Update the Menu Bar "New Task..." button**

The MenuBarView's "New Task..." button currently posts `.newTask`. Update it to post `.editorNewTask`:

```swift
Button("New Task...") {
    NSApp.activate(ignoringOtherApps: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        NotificationCenter.default.post(name: .editorNewTask, object: nil)
    }
}
```

Note: `Notification.Name.editorNewTask` is defined in `ContentView.swift`. Since `LoopCommanderApp.swift` is in the same module, it is accessible without import.

#### Contracts

- After this phase, the app builds and runs end-to-end.
- The `.newTask` notification name can remain defined but is no longer posted from anywhere in the app (it is effectively dead code after this change, but removing the definition is not required).
- Agent 7 (verification) depends on this phase being complete.

#### Constraints

- `TaskEditorView.swift` and `TaskEditorViewModel.swift` are kept in the project (not deleted). They are dead code after this migration but removing them is out of scope.
- Do not change `TaskListView.swift` or `TaskDetailView.swift` directly. All wiring changes happen in `ContentView.swift` callbacks.
- The `setupEventHandlers()` method in `ContentView` is unchanged.

#### Verification

```bash
cd /Users/hitch/Desktop/git/loop-commander/macos-app && swift build 2>&1 | grep -E "error:|Build complete"
```

---

## Phase 5 — Build Verification and Integration Testing

Phase 5 runs after all other agents complete.

---

### Agent 7: Build Verification and Integration Testing

#### Context: Files to Read Before Starting

Read all newly created and modified files to verify their contents match the spec:

- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Models/SchedulePreset.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Models/LCTask.swift` (verify Equatable extension)
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/ViewModels/EditorViewModel.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Views/ScheduleBuilderView.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Views/EditorView.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Views/SidebarView.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Views/ContentView.swift`
- `/Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/LoopCommanderApp.swift`

#### Task 1: Full Build

```bash
cd /Users/hitch/Desktop/git/loop-commander/macos-app && swift build 2>&1
```

Expected output: `Build complete!` with zero errors. All warnings are acceptable.

If the build fails, diagnose the errors and apply fixes. Common issues to check:

- `SidebarItem.editor` missing from a switch that previously handled only `.tasks` and `.logs`. Add it everywhere `SidebarItem` is exhaustively switched (if any other file uses it).
- `SidebarView` initializer call sites that do not pass `editorIsDirty`. Find and update them.
- `guardedSelection` type `Binding<SidebarItem?>` being passed where `Binding<SidebarItem?>` is expected — verify the binding type is correct.
- `TaskEditorState` references remaining after deletion. Search for `TaskEditorState` and `showingEditor` in the codebase and remove any remaining references.

```bash
grep -r "TaskEditorState\|showingEditor\|\.newTask[^a-zA-Z]" /Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/ --include="*.swift"
```

This grep should return zero results (only `newTask` in the `Notification.Name` definition is acceptable if kept).

#### Task 2: Rust Build (if Agent 6 ran)

```bash
cd /Users/hitch/Desktop/git/loop-commander && cargo build --release 2>&1 | tail -10
```

All tests must pass:
```bash
cargo test --workspace 2>&1 | tail -10
```

#### Task 3: Behavioral Verification Checklist

Verify each behavior by reading the code — not by running the app (since there is no simulator target). For each item, identify the code path and confirm it implements the behavior correctly.

**Sidebar Navigation:**
- [ ] `SidebarItem` has exactly three cases: `.tasks`, `.editor`, `.logs`.
- [ ] `SidebarView` renders three nav buttons in that order with correct icons: `"list.bullet.rectangle"`, `"pencil.and.outline"`, `"doc.text.magnifyingglass"`.
- [ ] The `editorIsDirty` parameter drives the amber dot on the Editor button.
- [ ] The amber dot uses `Color.lcAmber`, 6pt circle, with `.easeInOut(duration: 0.15)` animation.

**EditorView State Machine:**
- [ ] `EditorView` renders `emptyState` when `vm.editorState == .empty`.
- [ ] `EditorView` renders `editorContent` (with top bar + banner + two panes) for `.creating` and `.editing`.
- [ ] The unsaved changes banner appears/disappears with `.lcFadeSlide` transition when `vm.isDirty` changes.
- [ ] The Discard button appears/disappears with `.opacity` transition when `vm.isDirty` changes.
- [ ] Save button label reads "Create Task" when `vm.isCreating`, "Save Changes" when editing.
- [ ] Dry Run button is visible only in `.editing` state.

**ScheduleBuilderView:**
- [ ] All 12 `SchedulePreset` cases appear in the picker.
- [ ] Selecting `dailyAt`, `weekdaysAt`, `weeklyOn`, or `monthlyOn` shows the time sub-picker.
- [ ] Selecting `weeklyOn` additionally shows day-of-week chips.
- [ ] Selecting `monthlyOn` additionally shows day-of-month picker.
- [ ] Selecting any fixed-interval preset hides all sub-pickers.
- [ ] Selecting `custom` shows a raw cron text field.
- [ ] `cronReadout` is always visible and reflects `vm.draft.schedule` and `vm.draft.scheduleHuman`.
- [ ] Invalid custom cron (not exactly 5 space-separated fields) shows error styling.

**Dirty State:**
- [ ] `LCTaskDraft` has `Equatable` conformance via extension in `LCTask.swift`.
- [ ] `EditorViewModel.isDirty` returns `false` for `.empty`, compares against default `LCTaskDraft()` for `.creating`, compares against `originalSnapshot` for `.editing`.
- [ ] `vm.save()` updates `originalSnapshot = draft` on success for editing state.
- [ ] `vm.discard()` for `.editing` restores `draft = originalSnapshot` and calls `inferPresetFromCron`.
- [ ] `vm.discard()` for `.creating` sets `editorState = .empty`.

**Navigation Guard:**
- [ ] `ContentView.guardedSelection` intercepts sidebar tab changes.
- [ ] When `selectedSidebar == .editor && editorVM.isDirty && newValue != .editor`, the dirty alert fires instead of navigating.
- [ ] "Save" in the alert saves and then navigates.
- [ ] "Discard Changes" in the alert discards and navigates.
- [ ] "Cancel" in the alert sets `pendingNavigation = nil` and stays on Editor.

**Notification Wiring:**
- [ ] `.editorNewTask` notification calls `editorVM.startNewTask()` and sets `selectedSidebar = .editor`.
- [ ] `.editorOpenTask` notification with `userInfo["task"]` calls `editorVM.loadTask(_:)` and navigates to editor.
- [ ] `.editorOpenImport` notification with `userInfo["command"]` calls `editorVM.loadFromImportedCommand(_:)` and navigates to editor.
- [ ] `.switchToEditor` notification sets `selectedSidebar = .editor`.
- [ ] `TaskListView` `onNewTask` callback posts `.editorNewTask` (not `.newTask`).
- [ ] `TaskDetailView` `onEdit` callback posts `.editorOpenTask` with the task in `userInfo`.
- [ ] `CommandImportView` completion posts `.editorOpenImport` with the command in `userInfo`.
- [ ] `LoopCommanderApp` "New Task" menu command posts `.editorNewTask`.
- [ ] `MenuBarView` "New Task..." posts `.editorNewTask`.

**SchedulePreset Cron Correctness:**
- [ ] `every5Min.cronExpression(...)` returns `"*/5 * * * *"`.
- [ ] `every15Min.cronExpression(...)` returns `"*/15 * * * *"`.
- [ ] `everyHour.cronExpression(...)` returns `"0 * * * *"`.
- [ ] `every2Hours.cronExpression(...)` returns `"0 */2 * * *"`.
- [ ] `every4Hours.cronExpression(...)` returns `"0 */4 * * *"`.
- [ ] `dailyAt.cronExpression(hour: 9, minute: 30, ...)` returns `"30 9 * * *"`.
- [ ] `weekdaysAt.cronExpression(hour: 9, minute: 0, ...)` returns `"0 9 * * 1-5"`.
- [ ] `weeklyOn.cronExpression(hour: 9, minute: 0, weekdays: [1,3,5], ...)` returns `"0 9 * * 1,3,5"`.
- [ ] `monthlyOn.cronExpression(hour: 9, minute: 0, ..., dayOfMonth: 15)` returns `"0 9 15 * *"`.

**inferPresetFromCron correctness:**
- [ ] `inferPresetFromCron("*/15 * * * *")` sets `schedulePreset = .every15Min`.
- [ ] `inferPresetFromCron("0 9 * * *")` sets `schedulePreset = .dailyAt`, `selectedHour = 9`, `selectedMinute = 0`.
- [ ] `inferPresetFromCron("30 9 * * 1-5")` sets `schedulePreset = .weekdaysAt`, `selectedHour = 9`, `selectedMinute = 30`.
- [ ] `inferPresetFromCron("0 14 * * 1,3")` sets `schedulePreset = .weeklyOn`, `selectedHour = 14`, `selectedMinute = 0`, `selectedWeekdays = [1, 3]`.
- [ ] `inferPresetFromCron("0 9 15 * *")` sets `schedulePreset = .monthlyOn`, `selectedHour = 9`, `selectedMinute = 0`, `selectedDayOfMonth = 15`.
- [ ] `inferPresetFromCron("@reboot")` sets `schedulePreset = .custom`.

**Non-Breaking Contracts:**
- [ ] `TaskEditorView.swift` still exists and compiles (it is dead code, not deleted).
- [ ] `TaskEditorViewModel.swift` still exists and compiles (dead code, not deleted).
- [ ] No existing `LCTask`, `LCTaskDraft`, `Schedule`, `DaemonClient`, `DaemonMonitor`, or `EventStream` types were modified (only `LCTaskDraft` gained `Equatable` via extension).
- [ ] `LogsView` still renders correctly when `selectedSidebar == .logs`.
- [ ] The Tasks tab (tasksLayout) still renders correctly when `selectedSidebar == .tasks`.

#### Task 4: File Inventory Check

Confirm all new files exist:

```bash
ls /Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Models/SchedulePreset.swift
ls /Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/ViewModels/EditorViewModel.swift
ls /Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Views/ScheduleBuilderView.swift
ls /Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Views/EditorView.swift
```

All four must exist.

Confirm modified files are not accidentally deleted:

```bash
ls /Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/Views/TaskEditorView.swift
ls /Users/hitch/Desktop/git/loop-commander/macos-app/LoopCommander/ViewModels/TaskEditorViewModel.swift
```

Both must still exist.

#### Acceptance Criteria for Phase 5

The phase is complete when:
1. `swift build` produces `Build complete!` with zero errors.
2. All items in Task 3's checklist are confirmed by code inspection.
3. All four new files exist and all pre-existing files are intact.

---

## Appendix A: Complete Cron Conversion Reference

This table is reproduced for any agent needing a single authoritative reference.

| Preset Case | Raw Value | Cron Expression | Human Description |
|------------|-----------|-----------------|-------------------|
| `every5Min` | `every_5_min` | `*/5 * * * *` | Every 5 minutes |
| `every10Min` | `every_10_min` | `*/10 * * * *` | Every 10 minutes |
| `every15Min` | `every_15_min` | `*/15 * * * *` | Every 15 minutes |
| `every30Min` | `every_30_min` | `*/30 * * * *` | Every 30 minutes |
| `everyHour` | `every_hour` | `0 * * * *` | Every hour |
| `every2Hours` | `every_2_hours` | `0 */2 * * *` | Every 2 hours |
| `every4Hours` | `every_4_hours` | `0 */4 * * *` | Every 4 hours |
| `dailyAt` | `daily_at` | `{M} {H} * * *` | Every day at HH:MM |
| `weekdaysAt` | `weekdays_at` | `{M} {H} * * 1-5` | Every weekday at HH:MM |
| `weeklyOn` | `weekly_on` | `{M} {H} * * {D,...}` | Weekly on {Days} at HH:MM |
| `monthlyOn` | `monthly_on` | `{M} {H} {DOM} * *` | Monthly on the {DOM}{suffix} at HH:MM |
| `custom` | `custom` | (user-provided) | Custom schedule |

Where `{H}` = `selectedHour`, `{M}` = `selectedMinute`, `{D,...}` = `selectedWeekdays` sorted and comma-joined, `{DOM}` = `selectedDayOfMonth`.

---

## Appendix B: Reverse Cron Parsing Logic

`EditorViewModel.inferPresetFromCron` splits the input on whitespace into exactly 5 components. Matching is done in this order (most-specific first):

1. Exact match `*/5 * * * *` → `.every5Min`
2. Exact match `*/10 * * * *` → `.every10Min`
3. Exact match `*/15 * * * *` → `.every15Min`
4. Exact match `*/30 * * * *` → `.every30Min`
5. Exact match `0 * * * *` → `.everyHour`
6. Exact match `0 */2 * * *` → `.every2Hours`
7. Exact match `0 */4 * * *` → `.every4Hours`
8. Pattern `{int} {int} * * 1-5` → `.weekdaysAt`; extract minute=fields[0], hour=fields[1]
9. Pattern `{int} {int} * * {comma-separated-ints}` where all tokens in fields[4] are valid weekday integers (0–6) → `.weeklyOn`; extract minute, hour, weekdays
10. Pattern `{int} {int} {int} * *` → `.monthlyOn`; extract minute=fields[0], hour=fields[1], dayOfMonth=fields[2]
11. Pattern `{int} {int} * * *` → `.dailyAt`; extract minute=fields[0], hour=fields[1]
12. Anything else → `.custom`

Steps 8 and 11 must both check that fields[2], fields[3] (and fields[4] for `dailyAt`) are literally `*`. Step 8 must verify fields[4] is exactly `"1-5"`. Step 9 must verify all tokens in fields[4] after splitting by `,` parse as integers in [0,6] and no other special characters are present.

If splitting returns fewer or more than 5 components, fall back to `.custom` immediately.

---

## Appendix C: Key File Paths Quick Reference

```
macos-app/LoopCommander/
  Models/
    LCTask.swift                     -- MODIFIED (Equatable extension added)
    Schedule.swift                   -- UNCHANGED
    SchedulePreset.swift             -- NEW (Agent 1)
  ViewModels/
    EditorViewModel.swift            -- NEW (Agent 2)
    TaskEditorViewModel.swift        -- UNCHANGED (dead code, kept)
  Views/
    EditorView.swift                 -- NEW (Agent 4)
    ScheduleBuilderView.swift        -- NEW (Agent 3)
    SidebarView.swift                -- MODIFIED (Agent 5)
    ContentView.swift                -- MODIFIED (Agent 5)
    TaskEditorView.swift             -- UNCHANGED (dead code, kept)
  LoopCommanderApp.swift             -- MODIFIED (Agent 5)
  Styles/
    Color+LoopCommander.swift        -- UNCHANGED
    Font+LoopCommander.swift         -- UNCHANGED
    LCSpacing.swift                  -- UNCHANGED
    LCRadius.swift                   -- UNCHANGED
    LCAnimations.swift               -- UNCHANGED
    LCButtonStyles.swift             -- UNCHANGED
```
