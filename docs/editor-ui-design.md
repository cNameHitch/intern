# Editor Tab — UI Design Specification

## Overview

The Editor tab is a persistent, full-width panel that replaces the modal `TaskEditorView`. It lives permanently in the main window as the second sidebar item (between Tasks and Logs), giving users a dedicated, always-accessible workspace for authoring and modifying tasks. The modal editor is retired for create/edit flows; the Editor tab becomes the sole authoring surface.

---

## 1. Component Hierarchy

```
ContentView
  HSplitView
    SidebarView                        [minWidth: 205, idealWidth: 220, maxWidth: 260]
      AppBrandingHeader
      NavButton: Tasks
      NavButton: Editor               <- new, index 1
        DirtyDotIndicator             <- amber dot, visible when isDirty
      NavButton: Logs
      Spacer
    ZStack (main panel, background: lcBackground)
      TasksLayout         (opacity driven by selection)
      EditorTabView       (opacity driven by selection)   <- new
      LogsView            (opacity driven by selection)
```

```
EditorTabView
  VStack(spacing: 0)
    UnsavedChangesBanner              <- conditional, slides in from top
    EditorTopBar                      <- fixed, not scrollable
    HSplitView (or HStack with fixed ratio)
      PromptEditorPane  [~60% width]
      SettingsPane      [~40% width, scrollable]
```

```
EditorTopBar
  HStack
    TaskNameField                     <- editable inline
    Spacer
    DryRunButton    (LCToolbarButtonStyle)
    DiscardButton   (LCSecondaryButtonStyle)
    SaveButton      (LCPrimaryButtonStyle)
```

```
PromptEditorPane
  VStack(spacing: 0)
    PaneHeader ("PROMPT / COMMAND")
    LCTextEditor (fills remaining height)
    PromptFooter (character count, monospaced hint)
```

```
SettingsPane
  ScrollView
    VStack(spacing: 0)
      SettingsSection: "Task"
        SkillField
      SettingsSection: "Schedule"
        SchedulePresetPicker
        ScheduleSubPicker             <- conditional on preset selection
        CronReadoutRow
      SettingsSection: "Execution"
        WorkingDirField (with folder button)
        BudgetField
        TimeoutField
      SettingsSection: "Tags"
        TagInputField
        TagChipFlow
      SettingsSection: "Environment"
        EnvVarList
        AddEnvVarRow
```

---

## 2. Full-Screen Layout Wireframe

The minimum window size is 900x600 (existing constraint). The sidebar is 220px. The remaining content area (~680px+) is divided 60/40 between the prompt editor and the settings panel.

```
+--------------------------------------------------------------------+
| [Loop Commander logo]  Loop Commander               (window chrome) |
| LAUNCHD · CLAUDE CODE · 3 ACTIVE                                   |
+----------------+---------------------------------------------------+
| [*] Tasks   3  | [Task Name: Daily PR Review Sweep ............] |
|                |  [Dry Run]  [Discard]  [Save Changes]             |
| [.] Editor  *  +---------------------------------------------------+
|    (amber dot) | ! Unsaved changes — you have edits in progress.   |
|                +---------------------------+-----------------------+
| [ ] Logs       |                           |  TASK                 |
|                |  PROMPT / COMMAND         |  Skill (optional)     |
|                |                           |  [/review-pr        v]|
|                |  +---------------------+  |                       |
|                |  |                     |  |  SCHEDULE             |
|                |  |  claude -p '...'    |  |  [Daily at...       v]|
|                |  |                     |  |  -- sub-picker --     |
|                |  |                     |  |  Time  [09:00      v] |
|                |  |                     |  |                       |
|                |  |  (large text area   |  |  Cron   0 9 * * *     |
|                |  |   fills height)     |  |  "Every day at 9am"   |
|                |  |                     |  |                       |
|                |  |                     |  |  EXECUTION            |
|                |  |                     |  |  Working Directory    |
|                |  |                     |  |  [~/projects/repo  ][*|
|                |  |                     |  |  Budget ($)           |
|                |  |                     |  |  [5.0               ] |
|                |  |                     |  |  Timeout (sec)        |
|                |  +---------------------+  |  [600               ] |
|                |  1,247 chars             |  |                       |
|                |                           |  TAGS                 |
|                |                           |  [add tag...        ] |
|                |                           |  [ai] [review]        |
|                |                           |                       |
|                |                           |  ENVIRONMENT          |
|                |                           |  GITHUB_TOKEN  [***]  |
|                |                           |  [+ Add Variable    ] |
+----------------+---------------------------+-----------------------+
```

The vertical separator between the two panes uses `lcSeparator` (1px, `LCBorder.standard`). The pane width ratio is fixed at 60/40 using a `GeometryReader`; the split is not user-adjustable (the Tasks tab already uses a fixed 50/50 split with the same technique, keeping the chrome consistent).

---

## 3. Design Tokens

### Surfaces and Backgrounds

| Area | Token | Rationale |
|---|---|---|
| Full panel background | `lcBackground` (#0f1117) | Matches TasksLayout and LogsView — consistent main content zone |
| Top bar background | `lcSurface` (#1a1d23) | Elevates the action bar one level above the content, matching DetailView action bar treatment |
| Top bar bottom border | `lcSeparator` (white 8%) | Same as sidebar right edge and header separator throughout the app |
| Prompt text editor area | `lcCodeBackground` (black 30%) | Matches the existing `LCTextEditor` component exactly |
| Settings pane background | `lcBackground` | Flush with the main panel — sections use `lcSurfaceContainer` cards |
| Settings section card | `lcSurfaceContainer` (white 1%) | Matches the `taskInfoCard` treatment in `TaskDetailView` |
| Settings section border | `lcBorder` (white 6%) | Same card border used throughout |
| Unsaved changes banner | `lcAmberBg` (amber 10%) | Status-consistent with amber warn treatment in `DryRunSheet` |
| Unsaved changes banner border | `lcAmber` at 20% opacity | Distinguishable from content without overpowering |
| Cron readout row | `lcCodeBackground` | Code/data display, matches command preview blocks |

### Typography

| Element | Token | Notes |
|---|---|---|
| Task name inline field | `lcHeadingLarge` (20px bold) | Matches the task name heading in `TaskDetailView.taskInfoCard` |
| Top bar button labels | `lcButton` (13px semibold) | Standard button text |
| Pane section headers ("PROMPT / COMMAND") | `lcLabel` (11px semibold) + uppercase + tracking 0.5 | Matches `LCFormField` label style exactly |
| Settings field labels | `lcLabel` | Consistent with existing `LCFormField` |
| Settings field inputs | `lcInput` (13px monospaced) | Consistent with `LCTextField` |
| Cron expression value | `lcCode` (11px monospaced) | Data display, matches command preview |
| Cron human description | `lcCaption` (11px) | Secondary detail, lower visual weight |
| Character count footer | `lcCaption` | Muted data annotation |
| Section separator labels | `lcSectionLabel` (12px semibold) | Matches execution history header in `TaskDetailView` |
| Unsaved banner text | `lcBodyMedium` (12.5px medium) | Inline status message, not a heading |
| Tag chips | `lcTag` (10px monospaced) | Matches existing `TagChip` |
| Env var key/value | `lcCode` (11px monospaced) | Consistent with env var display in `DryRunSheet` |

### Colors

| Element | Token |
|---|---|
| Task name text | `lcTextPrimary` |
| Top bar muted elements | `lcTextMuted` |
| Settings label text | `lcTextSubtle` (white 35%) — matches `LCFormField` |
| Input text | `lcTextPrimary` |
| Input placeholder | `lcTextFaint` |
| Input border (default) | `lcBorderInput` (white 10%) |
| Input border (focused) | `lcAccentFocus` (indigo 50%) |
| Prompt editor text | `lcAccentLight` (#a5b4fc) — matches command preview in detail view |
| Cron expression text | `lcAccentLight` — consistent with other code output |
| Cron human description | `lcTextSecondary` |
| Dirty dot indicator | `lcAmber` (#f59e0b) |
| Unsaved banner icon | `lcAmber` |
| Unsaved banner text | `lcAmber` |
| Save button | `LCPrimaryButtonStyle` (background: `lcAccent`) |
| Discard button | `LCSecondaryButtonStyle` (border: `lcBorderInput`, text: white 50%) |
| Dry Run button | `LCToolbarButtonStyle` (border: `lcBorderInput`) |
| Folder browse button | `lcCodeBackground` fill + `lcBorderInput` border — matches existing `TaskEditorView` folder button |
| Add env var button | `LCToolbarButtonStyle` |
| Tag chip background | `lcTagBg` (indigo 10%) |
| Tag chip text | `lcAccent` |
| Tag remove button | `lcTextMuted` |
| Empty state icon | `lcTextFaint` |
| Empty state text | `lcTextMuted` / `lcTextSubtle` |
| Pane vertical separator | `lcSeparator` |

### Spacing

| Area | Value | Token |
|---|---|---|
| Top bar horizontal padding | 20px | `LCSpacing.p20` |
| Top bar vertical padding | 14px | `LCSpacing.xxl` |
| Top bar bottom border | 1px | `LCBorder.standard` |
| Prompt pane header padding | 12px horizontal, 10px vertical | `LCSpacing.xl` / `LCSpacing.lg` |
| Prompt text editor padding | 8px vertical, 10px horizontal | matches `LCTextEditor` internal padding |
| Prompt footer padding | 8px vertical, 12px horizontal | `LCSpacing.md` / `LCSpacing.xl` |
| Settings scroll view inner padding | 16px | `LCSpacing.xxxl` |
| Settings section gap | 4px between sections | `LCSpacing.xxs` |
| Settings section card padding | 16px | `LCSpacing.xxxl` |
| Settings field gap (within section) | 12px | `LCSpacing.xl` |
| Settings field label-to-input gap | 6px | `LCSpacing.sm` |
| Button gap (top bar) | 8px | `LCSpacing.md` |
| Unsaved banner horizontal padding | 20px | `LCSpacing.p20` |
| Unsaved banner vertical padding | 10px | `LCSpacing.lg` |
| Tag chip flow gap | 4px | `LCSpacing.xxs` — matches existing `FlowLayout` |
| Env var row gap | 8px | `LCSpacing.md` |

### Corner Radii and Borders

| Element | Value | Token |
|---|---|---|
| Text inputs | 6px | `LCRadius.button` |
| Section cards | 10px | `LCRadius.panel` |
| Preset dropdown picker | 6px | `LCRadius.button` |
| Tag chips | 4px | `LCRadius.badge` |
| Folder button | 6px | `LCRadius.button` |
| Card borders | 1px | `LCBorder.standard` |
| Input borders | 1px | `LCBorder.standard` |

---

## 4. Sidebar Modifications

### SidebarItem Enum Extension

Add a new case `.editor` between `.tasks` and `.logs`.

### Nav Button: Editor

The Editor nav button follows the identical `sidebarButton` pattern. It adds one new element: a dirty state indicator dot positioned as a trailing overlay on the button, rendered only when `editorVM.isDirty` is true.

```
Nav button (normal):
+-----------------------------+
|  [pencil icon]  Editor      |
+-----------------------------+

Nav button (dirty):
+-----------------------------+
|  [pencil icon]  Editor    • |   <- amber dot (lcAmber, 6pt circle)
+-----------------------------+
```

The dot sits inside the existing `HStack` as a `Circle()` of diameter 6pt filled with `lcAmber`. It is placed after the `Spacer()`, before any badge would appear. It uses `.animation(.lcQuick)` on its opacity transition so it fades in/out without jarring the layout.

Accessibility: The dirty indicator must supply a supplemental accessibility label. The nav button's overall `accessibilityLabel` should read "Editor, unsaved changes" when dirty and "Editor" when clean.

### Badge Conflict

The existing badge pattern (numeric count in an `lcAccentBg` pill) is reserved for Tasks. The Editor nav item never shows a count badge. The dirty dot and a count badge are mutually exclusive slots and the Editor only uses the dot.

---

## 5. Top Bar Specification

The top bar is a fixed-height row that does not scroll with the settings panel.

```
+------------------------------------------------------------------------+
| [Task Name: Daily PR Review Sweep ................................] gap |
|                                    [Dry Run]  [Discard]  [Save Changes]|
+------------------------------------------------------------------------+
```

### Task Name Field

- Rendered as an inline `TextField` with `.plain` style.
- Font: `lcHeadingLarge` (20px bold).
- Foreground: `lcTextPrimary` when populated, `lcTextFaint` when empty (placeholder).
- Placeholder text: "Untitled Task".
- No visible border or background in the default state — the field blends into the bar.
- On focus: a 1px `lcAccentFocus` bottom border appears (not a full rounded rect — just a bottom underline, 2px, to preserve the heading visual weight). This is the one place where the full rounded-rect input treatment is softened to respect the large font size.
- Maximum width: unconstrained (fills available space before the buttons).
- On the left, the field is preceded by 20px padding from the panel edge.
- Accessibility label: "Task name".

### Action Buttons

Ordered right-to-left by visual weight: Save (heaviest) is rightmost.

| Button | Style | Keyboard Shortcut | Condition |
|---|---|---|---|
| Save Changes / Create Task | `LCPrimaryButtonStyle` | Cmd+S | Always visible; label changes based on state |
| Discard | `LCSecondaryButtonStyle` | Cmd+Z (or Escape) | Visible only when `isDirty` is true |
| Dry Run | `LCToolbarButtonStyle` | Cmd+Opt+R | Visible only when a task is loaded (non-empty state) |

The Discard button enters the layout with `.animation(.lcQuick)` on opacity so it appears and disappears without reflowing the Save button. It uses `.transition(.opacity)` — not a slide, since it is in an HStack and a slide would shift the Save button position on every dirty toggle.

When `isSaving` is true, the Save button is `.disabled(true)` and a `ProgressView` (`.scaleEffect(0.7)`) replaces the button label inline, matching the spinner idiom used elsewhere.

---

## 6. Unsaved Changes Banner

The banner appears between the top bar and the two-pane split. It is a full-width strip that slides in from the top using the `.lcFadeSlide` transition on the VStack that contains it.

```
+------------------------------------------------------------------------+
| [!] Unsaved changes — you have edits in progress.                      |
+------------------------------------------------------------------------+
```

- Background: `lcAmberBg`.
- Top border: 1px `lcAmber` at 20% opacity.
- Bottom border: 1px `lcSeparator`.
- Icon: `exclamationmark.triangle.fill` at 11pt, color `lcAmber`.
- Text: `lcBodyMedium`, color `lcAmber`, message "Unsaved changes — you have edits in progress."
- Padding: 10px vertical (`LCSpacing.lg`), 20px horizontal (`LCSpacing.p20`).
- The banner does not have a dismiss button — it disappears automatically when the editor is clean (after save or discard).
- Accessibility role: `.statusBar`. VoiceOver should announce the banner's appearance when it first enters the view.

---

## 7. Two-Pane Editor Split

### Prompt Editor Pane (left, ~60%)

The pane header row uses the same `lcLabel` uppercase treatment as `LCFormField`:

```
PROMPT / COMMAND                               1,247 chars
```

The character count on the right is `lcData` (11px monospaced), color `lcTextMuted`. It updates live as the user types.

The `LCTextEditor` component is used directly from `TaskEditorView`. It is given `maxHeight: .infinity` so it fills the remaining vertical space below the pane header. The prompt text is rendered in `lcInput` (13px monospaced) with `lcTextPrimary` foreground — except that to give the prompt area additional visual identity as a code authoring surface, the text foreground is `lcAccentLight` (#a5b4fc), which is already used for command text in `TaskDetailView.taskInfoCard`. This visually aligns the editing and reading experiences.

The bottom footer of the pane shows the character count line, separated from the editor by a 1px `lcBorder` line, with 8px vertical and 12px horizontal padding.

A line at the right edge of this pane (1px `lcSeparator`) is the only divider between the two panes.

### Settings Pane (right, ~40%)

The pane is a `ScrollView(.vertical)` with `showsIndicators: false`. Content is a `VStack(spacing: 0)` of section cards. Each section is a `VStack(alignment: .leading, spacing: 12)` inside a card container with `lcSurfaceContainer` background, `lcBorder` border, `LCRadius.panel` corners, and `LCSpacing.xxxl` (16px) internal padding.

Between section cards, there is a `LCSpacing.xxs` (4px) gap — a tight but distinct separation that groups fields visually while keeping the pane compact.

---

## 8. Settings Sections Detail

### Section: Task

Contains a single field: Skill (optional).

The Skill field is a `LCTextField` with placeholder "/review-pr, /loop, etc.", matching the existing `TaskEditorView`. The skill value is a dropdown in the new editor — a `Picker` with `.menu` style rendered as a dropdown, populated from known skills discovered in the task list. The picker includes a final option "Enter manually..." that, when selected, replaces the picker with a `LCTextField` so arbitrary values remain possible.

```
TASK
+----------------------------------+
| SKILL (OPTIONAL)                 |
| [/review-pr                   v] |
+----------------------------------+
```

### Section: Schedule

This is the most complex settings section. It is described in full in Section 9 below.

### Section: Execution

Three fields in a compact layout:

```
EXECUTION
+----------------------------------+
| WORKING DIRECTORY                |
| [~/projects/my-repo       ] [dir]|
|                                  |
| BUDGET PER RUN ($)               |
| [5.0                          ]  |
|                                  |
| TIMEOUT (SECONDS)                |
| [600                          ]  |
+----------------------------------+
```

Working Directory: a `LCTextField` paired with a folder icon button. The pattern is identical to `TaskEditorView`'s working directory row — `lcCodeBackground` fill, `lcBorderInput` stroke, `LCRadius.button` corners, folder `systemName` icon.

Budget and Timeout fields use `LCTextField` with `.keyboardType` constraints and validation. They are stacked vertically (not side-by-side as in the modal) because the right column is narrower and side-by-side fields would be too cramped at ~40% width.

### Section: Tags

```
TAGS
+----------------------------------+
| [add a tag and press enter    ]  |
| [ai] [review] [daily] [+]        |
+----------------------------------+
```

Uses the existing `LCTextField` with `onSubmit` callback and the existing `FlowLayout` + `TagChip` components. No changes to those components required.

### Section: Environment Variables

```
ENVIRONMENT VARIABLES
+----------------------------------+
| KEY              VALUE           |
| GITHUB_TOKEN     [••••••••••]    |
| NODE_ENV         [production]    |
|                                  |
| [+ Add Variable               ]  |
+----------------------------------+
```

Each env var row is an `HStack` with:
- Key: `LCTextField`, width 40% of section.
- Value: `LCTextField`, width fills remaining space. Values default to a non-secure text field. A toggle button (eye icon, `lcTextMuted`) switches between secure and plain rendering for values that look like secrets (heuristic: key contains TOKEN, SECRET, KEY, PASSWORD, PASS).
- Remove button: `Image(systemName: "minus.circle")`, color `lcTextMuted`, plain button style, 20px wide.

Column header row ("KEY" / "VALUE") uses `lcColumnHeader` (10px semibold) with `lcTextFaint` color and uppercase tracking, sitting above the list without a card border — matching the log table header approach in `TaskDetailView.LogTableHeader`.

The "Add Variable" button spans full width of the section. It uses `LCToolbarButtonStyle` with a leading `+` icon and the label "Add Variable". On tap, a new empty row appends to the list with the key field immediately focused.

---

## 9. Schedule Builder — Detailed Wireframe

### Preset Picker

A native `Picker` with `.menu` style. Its label uses `lcLabel` uppercase treatment. The selected value is shown in the picker button using `lcInput` (monospaced, 13px).

Preset options:
1. Every N minutes
2. Daily at...
3. Weekdays at...
4. Weekly on...
5. Monthly on...
6. Custom cron

Default when no schedule is set: a disabled placeholder option that reads "Choose a schedule..." rendered in `lcTextFaint`.

```
SCHEDULE
+----------------------------------+
| PRESET                           |
| [Daily at...                  v] |
|                                  |  <- sub-picker animates in below
| TIME                             |
| [09 : 00                      ]  |
|                                  |  <- cron readout always present below sub-picker
| +------------------------------+ |
| | 0 9 * * *                    | |  <- lcCode, lcCodeBackground
| | Every day at 9:00 AM         | |  <- lcCaption, lcTextSecondary
| +------------------------------+ |
+----------------------------------+
```

The sub-picker region uses `.animation(.lcFadeSlide)` on `.transition(.opacity.combined(with: .move(edge: .top)))` — the same animation used for action bar transitions in `TaskDetailView`. This prevents jarring layout shifts when the user changes presets.

### Sub-Pickers by Preset

**Every N minutes:**
```
INTERVAL
[Every 5 minutes               v]   <- Picker menu: 5, 10, 15, 30, 60
```
Single row. No time field.

**Daily at...:**
```
TIME
[09 : 00                       ]   <- Two-segment HH/MM stepper or Picker
```

**Weekdays at...:**
```
TIME
[09 : 00                       ]
```
No day picker — Monday–Friday is implied. The cron readout makes this explicit.

**Weekly on...:**
```
DAY OF WEEK
[Mon] [Tue] [Wed] [Thu] [Fri] [Sat] [Sun]   <- toggle chips, multi-select

TIME
[09 : 00                       ]
```
Day-of-week chips use the existing tag chip visual treatment but in a toggle variant:
- Unselected: `lcSurfaceContainer` background, `lcBorderInput` border, `lcTextMuted` text.
- Selected: `lcAccentBgSubtle` background, `lcAccent` border, `lcAccentLight` text.
- Corner radius: `LCRadius.badge` (4px) to match badge sizing.
- Font: `lcBadge` (11px semibold monospaced).
- Abbreviations: Mon, Tue, Wed, Thu, Fri, Sat, Sun.

At least one day must be selected. If the user deselects the last day, the tap is ignored and the chip shakes (0.1s horizontal translation of ±3pt, two cycles — a standard macOS shake feedback idiom).

**Monthly on...:**
```
DAY OF MONTH
[1      ] to [28     ]   <- note: capped at 28 to be month-safe
(single Picker or stepper, 1-28)

TIME
[09 : 00                       ]
```
Day-of-month is a single `Picker` with `.menu` style listing 1–28. 29, 30, 31 are excluded to avoid months where those days do not exist, keeping the scheduler reliable. A `lcCaption`-sized note beneath reads "Days 29–31 omitted for reliability across all months." Color: `lcTextSubtle`.

**Custom cron:**
```
CRON EXPRESSION
[*/15 * * * *                  ]   <- LCTextField, monospaced
```
A plain `LCTextField` accepting a raw cron string. The cron readout below parses and reflects the entered expression in real time. If the expression is invalid, the readout row shows an error state: background `lcRedBg`, border `lcRedBorder`, text "Invalid cron expression" in `lcRed` using `lcCaption`.

### Cron Readout Row

Present for all presets. It is a read-only display block, not a form field. It sits below the sub-picker within the Schedule section card.

```
+----------------------------------+
| 0 9 * * *                        |   <- lcCode font, lcAccentLight color
| Every day at 9:00 AM             |   <- lcCaption font, lcTextSecondary color
+----------------------------------+
```

Visual spec:
- Container: `lcCodeBackground` background, `lcBorder` border (1px), `LCRadius.button` (6px) corner radius.
- Padding: 10px vertical, 12px horizontal (`LCSpacing.lg` / `LCSpacing.xl`).
- The two lines are separated by 3px (`LCSpacing.xxxs`).
- The container is `.textSelection(.enabled)` so users can copy the expression.
- Accessibility label: "Cron expression: [expression]. Meaning: [human description]."

### Time Sub-Picker

The time input for presets that require a time is rendered as two adjacent `Picker` controls with `.menu` style in an `HStack(spacing: 4)`:

```
[09  v] : [00  v]
```

- Hour picker: values 00–23, displayed as zero-padded two digits.
- Minute picker: values 00, 05, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55. (5-minute granularity — sufficient for scheduled automation.)
- Both pickers use `lcInput` font (13px monospaced).
- The colon separator is `lcTextMuted`, `lcBodyMedium`.
- No free-text time entry — the picker enforces valid times and prevents invalid cron states.

---

## 10. Editor State Machine

The editor has three states that affect what is displayed. These are not separate views but different render paths within `EditorTabView`.

### State: Empty (no task loaded)

Shown when the user navigates to the Editor tab and no prior session exists. No task has been created or is being edited.

```
+------------------------------------------------------------------------+
|                                                                        |
|                    [pencil.and.outline icon, 48pt]                     |
|                    lcTextFaint                                         |
|                                                                        |
|                    No task loaded                                      |
|                    lcBodyMedium, lcTextMuted                           |
|                                                                        |
|                    Create a new task or open one from the Tasks tab.   |
|                    lcCaption, lcTextSubtle                             |
|                                                                        |
|                    [  + New Task  ]                                    |
|                    LCPrimaryButtonStyle                                |
|                                                                        |
+------------------------------------------------------------------------+
```

The icon, text stack, and button are centered both vertically and horizontally using `VStack(spacing: 12)` inside a `frame(maxWidth: .infinity, maxHeight: .infinity)`. This matches the empty detail panel treatment in `ContentView` (the "Select a task" empty state).

The "New Task" button in this state sets the editor to the Creating state.

### State: Creating (new task, no saved counterpart)

Top bar shows:
- Task name field: empty, placeholder "Untitled Task".
- Save button label: "Create Task".
- Discard button: hidden (there is no prior state to revert to — the action would be equivalent to navigating away, handled by the standard navigation guard instead).
- Dry Run button: hidden (no task exists to dry run yet).

The two-pane layout is fully rendered and interactive. All fields start at their default values.

`isDirty` becomes true as soon as any field has content.

### State: Editing (existing task loaded)

Top bar shows:
- Task name field: pre-filled.
- Save button label: "Save Changes".
- Discard button: visible only when `isDirty`.
- Dry Run button: visible.

`isDirty` is computed by deep comparison of the current draft against the original task snapshot taken when the task was loaded.

### Transition: Task List -> Editor

When the user taps "Edit" on a `TaskDetailView` action bar or a task row context menu, the app:
1. Posts a new notification (`editorOpenTask(LCTask)`) or sets a shared `EditorViewModel` binding.
2. Switches `selectedSidebar` to `.editor`.
3. The Editor tab loads the task into the draft state.

This replaces the current `showingEditor = .editing(task)` modal presentation in `ContentView`. The `TaskEditorState` enum and the modal overlay are retired.

---

## 11. Interaction Patterns

### Save Flow

1. User edits any field.
2. `isDirty` becomes `true` immediately.
3. Amber dot appears in sidebar nav item (`.animation(.lcQuick)` on opacity).
4. Unsaved changes banner slides in (`lcFadeSlide` transition).
5. User taps Save (or presses Cmd+S).
6. `isSaving` becomes `true`: Save button shows inline spinner, is disabled.
7. JSON-RPC call to daemon.
8. On success:
   - `isDirty` becomes `false`.
   - Banner slides out.
   - Amber dot disappears.
   - Snapshot updates to reflect saved state.
   - A brief success flash: the Save button label transitions to a checkmark for 1.2 seconds, then reverts to "Save Changes". Use a simple `@State private var showSavedConfirmation` boolean with a `DispatchQueue.main.asyncAfter` reset. The checkmark uses `Image(systemName: "checkmark")` with `lcGreen` foreground, inline with the label text, fading in via `.animation(.lcQuick)`.
9. On failure:
   - `isSaving` reverts to `false`.
   - An inline error appears below the top bar (same placement and style as the validation errors in `TaskEditorView` — `lcRed`, `exclamationmark.circle.fill` icon, `lcCaption` font).
   - `isDirty` remains `true`.

### Discard Flow

1. User taps Discard.
2. If the editor is in Creating state with content: a native `Alert` (`.alert`) presents: "Discard new task? All unsaved content will be lost." Confirm button: "Discard" (destructive role). Cancel button: default role. On confirm: editor reverts to Empty state.
3. If the editor is in Editing state: the same `Alert` presents: "Discard changes? Your edits will be lost." On confirm: draft resets to the original snapshot. `isDirty` becomes `false`. Banner and dot disappear.

### Navigate Away Guard

When `isDirty` is `true` and the user taps any other sidebar item (Tasks or Logs), a native `Alert` presents:

```
"You have unsaved changes in the Editor.
 Do you want to save before leaving?"

[Save]        [Discard Changes]        [Cancel]
  primary          secondary             cancel
```

- "Save": triggers the save flow, then navigates if save succeeds.
- "Discard Changes": resets draft, clears dirty state, navigates.
- "Cancel": dismisses the alert, stays on Editor tab.

This guard fires only for sidebar navigation. Closing the window triggers the standard macOS document-dirty close behavior if `NSDocument` is used; if not, an equivalent `.onDisappear` / `windowShouldClose` hook should present the same options.

### Dry Run Flow

Identical to the existing `TaskDetailView.dryRun()` flow. The result sheet uses the existing `dryRunSheet` component presented as a `.overlay` on `EditorTabView` using the same `lcOverlay` backdrop and `lcModalShadow()` modifier. No changes to that component.

### Keyboard Shortcuts

| Action | Shortcut |
|---|---|
| Save | Cmd+S |
| Discard (when dirty) | Cmd+Z (with confirmation) or Escape (same confirmation) |
| Dry Run | Cmd+Opt+R |
| Focus Task Name | Cmd+Shift+N |
| Focus Prompt Editor | Cmd+Opt+P |

---

## 12. Empty State Visual — Editor Pane When No Command Entered

When the prompt editor pane has no text content, a centered placeholder is shown inside the editor area (rendered via the existing `LCTextEditor` placeholder mechanism — `lcTextFaint` text, non-interactive):

```
claude -p 'Your prompt or command here...'
```

This matches the existing `TaskEditorView` placeholder for the command field. No additional empty state treatment is needed inside the pane itself.

---

## 13. Accessibility Considerations

### Focus Management

When the Editor tab becomes active via sidebar navigation:
- If state is Empty: focus moves to the "New Task" button.
- If state is Creating or Editing: focus moves to the Task Name field.
This is implemented via `.focusedValue` or a `@FocusState` variable that sets focus on `.onAppear` or `.onChange(of: selectedSidebar)`.

### VoiceOver Descriptions

| Element | Accessibility Label / Value | Hint |
|---|---|---|
| Dirty dot in sidebar | "Editor, unsaved changes" (on the nav button) | (none — conveyed via label) |
| Task name field | "Task name" | "Enter a name for this task" |
| Prompt editor | "Prompt or command" | "Enter the Claude command to run on schedule" |
| Save button | "Save changes" / "Create task" | "Saves the current task configuration" |
| Discard button | "Discard changes" | "Reverts all unsaved edits" |
| Dry Run button | "Dry run" | "Previews the resolved command without executing" |
| Preset picker | "Schedule preset" | "Choose how often this task runs" |
| Day-of-week chip (selected) | "Monday, selected" | "Tap to deselect" |
| Day-of-week chip (unselected) | "Monday" | "Tap to select" |
| Cron readout | "Cron expression: 0 9 * * *. Meaning: Every day at 9:00 AM" | (none) |
| Folder browser button | "Browse for working directory" | (none) |
| Remove tag button | "Remove tag [tag name]" | (none) |
| Env var remove button | "Remove environment variable [key]" | (none) |
| Env var value (secure) | "Value for [key], hidden" | "Double-tap to reveal" |
| Unsaved changes banner | "Unsaved changes: you have edits in progress" | (status, announced on appearance) |
| Character count | "[n] characters" | (none) |

### Reduced Motion

All transitions that use `.lcFadeSlide` (unsaved banner, sub-picker swap, sidebar dirty dot) should check `@Environment(\.accessibilityReduceMotion)`. When true, replace `.move` components of transitions with `.opacity` only. The `lcQuick` and `lcFadeSlide` animations are already short-duration; the key change is removing positional movement.

### Color Contrast

- `lcAmber` (#f59e0b) on `lcAmberBg` (amber at 10%): the amber text achieves approximately 4.6:1 contrast against the dark wash background, meeting WCAG AA for normal text.
- `lcAccentLight` (#a5b4fc) on `lcCodeBackground` (black 30% over `lcBackground` #0f1117): approximately 8:1 contrast, well within WCAG AA.
- `lcTextPrimary` (#e2e8f0) on `lcBackground` (#0f1117): approximately 13:1, AAA.
- Day-of-week chips (selected): `lcAccentLight` on `lcAccentBgSubtle` — approximately 5.8:1, AA compliant.
- All interactive controls use `.contentShape(Rectangle())` to ensure hit targets are at least 44x44pt where layout allows. Compact pickers and the day chip row may fall below 44pt height; these must be padded internally to reach at least 36pt minimum (acceptable for density-appropriate desktop UI).

### Keyboard Navigation

All interactive elements must be reachable via Tab and arrow keys. The settings scroll view must scroll to bring focused controls into view automatically (SwiftUI default behavior, but must not be suppressed).

The day-of-week chip row is navigable with arrow keys when focused: Left/Right moves between chips, Space toggles the focused chip. This is implemented by treating the chip row as a custom accessibility container with `.accessibilityElement(children: .contain)`.

---

## 14. Relationship to Existing Components

| Existing Component | Treatment in Editor Tab |
|---|---|
| `TaskEditorView` (modal) | Retired for create/edit flows. Modal is replaced by Editor tab. The component file remains for potential re-use of `LCFormField`, `LCTextField`, `LCTextEditor`, `FlowLayout`, `TagChip` — these sub-components are promoted to shared components or kept in the file and imported. |
| `TaskEditorViewModel` | Reused as `EditorViewModel`. The `isNew`, `draft`, `validationErrors`, `isSaving`, `error`, `save()` contract is preserved. Add `isDirty: Bool` (computed), `originalSnapshot: LCTaskDraft?`, `discard()`, and `schedulePreset: SchedulePreset` (new enum). |
| `LCFormField` | Used verbatim in settings sections. |
| `LCTextField` / `LCTextEditor` | Used verbatim. |
| `FlowLayout` / `TagChip` | Used verbatim. |
| `TaskDetailView.dryRunSheet` | Used verbatim, presented as an overlay on `EditorTabView`. |
| `SidebarView.sidebarButton` | Extended to support a dirty dot trailing indicator. |
| `ContentView.TaskEditorState` | Enum is removed. Editor state lives in `EditorViewModel`. |
| `ContentView` modal overlay | Removed for create/edit. `CommandImportView` modal overlay remains for the import flow, which still presents over the Tasks tab. |
