# Loop Commander Editor Feature Specification

## 1. Overview and Motivation

### Purpose

Loop Commander currently enables users to create and schedule Claude Code tasks through a modal editor overlay on the Tasks screen. To improve the user experience and establish Loop Commander as the central hub for managing all Claude skills and commands, we are introducing a dedicated **Editor Tab**—a full-featured, persistent editing environment that replaces the modal workflow and enables comprehensive task management, command import, and skill lifecycle management.

### Problem Statement

The current modal-based editor has several limitations:

1. **Limited space and context**: Users cannot see the full task list, execution history, or detailed configuration simultaneously while editing, reducing productivity when managing multiple related tasks.
2. **Scattered skill management**: Claude Code skills and commands live across multiple project directories and global locations. Loop Commander lacks a cohesive interface to browse, import, edit, and manage these skills.
3. **Fragmented workflow**: Creating a task, editing an existing task, and importing a command follow different paths, leading to context switching and reduced efficiency.
4. **No persistent editing state**: Users cannot save draft edits and return later, losing work if they accidentally close the modal.
5. **Schedule complexity**: The schedule field requires cron knowledge; users must manually type expressions like "0 9 * * 1-5" with no guidance.

### Target Users

- **Power users** who create and refine multiple tasks regularly and need quick navigation and editing.
- **Team leads** who maintain shared task libraries and want to import/export skills across environments.
- **Automation enthusiasts** who want Loop Commander to be their single source of truth for all Claude task definitions.

### Business Goals

- Increase feature adoption by reducing friction in the editor workflow.
- Position Loop Commander as the primary interface for Claude task automation, not just scheduling.
- Enable deeper integration with Claude Code command discovery and management.
- Drive longer session times and higher engagement by improving the editing experience.

### Non-Breakage Guarantee

All changes are UI-layer only. The CLI, daemon, JSON-RPC API, data models, and persistence layer remain unchanged. Existing workflows—both CLI and current macOS app—continue to work identically.

---

## 2. User Stories

### Story 1: Navigate to Editor Tab
**As a** macOS app user,
**I want to** access a dedicated "Editor" tab in the sidebar,
**so that** I can edit tasks without losing context of the broader app.

**Acceptance Criteria:**
- Sidebar displays three tabs: "Tasks", "Editor", and "Logs" (in that order).
- "Editor" tab is clearly labeled with an appropriate icon.
- Clicking "Editor" navigates to the Editor view, replacing the current content panel.
- The sidebar remains visible when the Editor tab is active.
- Tab selection persists during the session (user preference is remembered).

### Story 2: Open Editor for New Task
**As a** macOS app user,
**I want to** click "New Task" on the Tasks screen and have the app navigate to the Editor tab with a blank form,
**so that** I can seamlessly create tasks without modal overlays.

**Acceptance Criteria:**
- "New Task" button on TaskListView navigates to Editor tab.
- Editor displays an empty form with all fields set to defaults.
- The form title reads "New Scheduled Task".
- All fields are editable and focused (cursor in first field).
- Pressing Escape cancels and returns to Tasks tab.

### Story 3: Open Editor for Existing Task
**As a** macOS app user,
**I want to** click "Edit" on a task detail or context menu and have the app navigate to the Editor tab with that task loaded,
**so that** I can edit tasks without losing the rest of the app's context.

**Acceptance Criteria:**
- "Edit" button (both in TaskDetailView action bar and context menu) navigates to Editor tab.
- Editor displays the task's current values pre-populated in all fields.
- The form title reads "Edit Task" (task name displayed).
- A clear visual indicator shows which task is being edited (e.g., task ID or name in header).
- Navigating to Editor with a different task ID reloads the form with the new task's data.

### Story 4: Drag-and-Drop / Import Commands
**As a** macOS app user,
**I want to** browse and import Claude Code commands directly from the Editor,
**so that** I can discover existing commands and convert them into scheduled tasks without leaving the editor.

**Acceptance Criteria:**
- Editor displays an "Import Command" button or link.
- Clicking "Import Command" opens the CommandImportView (current import dialog).
- Upon import, the editor form is populated with the command's name, prompt, and default schedule.
- The skill field is pre-filled with the command name (e.g., `/review-pr`).
- User can then modify fields and save as a new task.

### Story 5: Schedule Builder UI
**As a** macOS app user,
**I want to** select a schedule from a friendly dropdown menu instead of typing cron expressions,
**so that** I can configure schedules without needing to understand cron syntax.

**Acceptance Criteria:**
- A "Schedule" field in the editor displays a dropdown labeled "Schedule Builder".
- Dropdown menu includes these preset options:
  - "Every 15 minutes"
  - "Every 30 minutes"
  - "Every hour"
  - "Every 2 hours"
  - "Every 4 hours"
  - "Daily at..."
  - "Weekdays at..."
  - "Weekly on..."
  - "Monthly on..."
  - "Custom (Advanced)" (for manual cron entry)
- When "Daily at..." is selected, a time picker appears (hours and minutes).
- When "Weekdays at..." is selected, a time picker appears (hours and minutes).
- When "Weekly on..." is selected, checkboxes appear for day-of-week (Mon–Sun) plus a time picker.
- When "Monthly on..." is selected, a day-of-month picker (1–31) appears plus a time picker.
- The generated cron expression is always visible (read-only) and updates in real-time as selections change.
- A human-readable description (e.g., "Every weekday at 09:00") is displayed below the cron field.
- An "Advanced" toggle enables direct cron expression editing for power users.

### Story 6: Full-Featured Editor Form
**As a** macOS app user,
**I want to** edit all task properties—command, schedule, budget, timeout, environment variables, and tags—in a single, organized form,
**so that** I can manage all aspects of a task in one place without context switching.

**Acceptance Criteria:**
- Editor displays a full-screen form with these fields (in order):
  1. **Task Name** (text input)
  2. **Claude Command** (large text editor with multiline support)
  3. **Skill** (optional; text input or dropdown of discovered skills)
  4. **Working Directory** (text input + folder picker button)
  5. **Schedule** (Schedule Builder dropdown as per Story 5)
  6. **Max Budget per Run** (numeric input, default 5.0)
  7. **Timeout (seconds)** (numeric input, default 600)
  8. **Max Turns** (optional numeric input)
  9. **Environment Variables** (key-value editor; see Story 7)
  10. **Tags** (tag input with add/remove; limit 20 tags)
- Fields are organized into logical sections (e.g., "Basic Info", "Execution", "Budget & Safety", "Metadata").
- All fields display validation errors in real-time (below the field or in a summary).
- A read-only "Cron Expression" field shows the computed cron value from the Schedule Builder.
- Form fields support standard keyboard navigation (Tab, Enter, Escape).
- Form width is optimized for readability (not full-screen-wide; likely 600–700px).

### Story 7: Environment Variables Editor
**As a** macOS app user,
**I want to** edit environment variables in a user-friendly key-value interface,
**so that** I can configure API keys, tokens, and other secrets for task execution.

**Acceptance Criteria:**
- Environment Variables section displays a list of key-value pairs.
- Each pair has an input for the key, an input for the value, and a remove button.
- An "Add Variable" button adds a new empty pair.
- Keys are validated to be valid environment variable names (alphanumeric + underscore).
- Values can contain any text (may include special characters).
- Removing a variable updates the form draft immediately.
- Values are not displayed as plaintext in a non-focused state (masking is optional but recommended).

### Story 8: Explicit Save with Unsaved Changes Detection
**As a** macOS app user,
**I want to** see a clear "Save" button and an unsaved changes indicator,
**so that** I can confirm my changes are persisted and never accidentally lose work.

**Acceptance Criteria:**
- A "Save" button is always visible in the footer (bottom-right).
- When the form is unchanged from the saved state, the Save button is disabled.
- When the form has unsaved changes, the Save button is enabled and visually prominent (e.g., highlighted).
- A small indicator (e.g., red dot or "Unsaved" label) appears next to the form title when there are unsaved changes.
- Clicking "Save" disables the button, shows a loading state, and persists the task via the daemon.
- Upon successful save, the unsaved indicator clears and the button reverts to disabled (until next edit).
- If save fails, an error message appears below the Save button, and the button remains enabled.
- Keyboard shortcut: Cmd+S triggers save (when Editor tab is focused).

### Story 9: Confirm Before Navigating Away with Unsaved Changes
**As a** macOS app user,
**I want to** be prompted if I try to leave the Editor tab with unsaved changes,
**so that** I never accidentally discard my work.

**Acceptance Criteria:**
- If the editor has unsaved changes and the user clicks another sidebar tab, a confirmation dialog appears.
- Dialog offers three options: "Save", "Discard", and "Cancel".
- "Save" persists changes and navigates to the new tab.
- "Discard" loses changes and navigates to the new tab.
- "Cancel" remains in the Editor tab.
- If the form is clean (no unsaved changes), navigation occurs without a prompt.

### Story 10: Test / Dry-Run from Editor
**As a** macOS app user,
**I want to** test the task without saving,
**so that** I can validate that the command and schedule work as expected before committing.

**Acceptance Criteria:**
- A "Dry Run" button is displayed in the editor footer (next to Save).
- Clicking "Dry Run" does NOT save the current draft; it runs a validation check only.
- A dry-run result sheet appears showing:
  - Resolved command (with env vars and working dir applied)
  - Parsed schedule (human-readable description)
  - Budget and timeout values
  - Any warnings or skip reasons (e.g., budget exceeded)
- User can close the dry-run sheet without affecting the draft form.

### Story 11: Create New Skill / Command from Scratch
**As a** a power user,
**I want to** create a new Claude skill/command directly in the Editor,
**so that** Loop Commander becomes my single hub for task and skill definition.

**Acceptance Criteria:**
- The Editor supports creating and editing task definitions that can be exported as Claude Code command files.
- An "Export as Command" button is available in the editor (after saving a task).
- Clicking "Export as Command" opens a dialog to choose a save location (e.g., project's `.claude/commands/` directory).
- The task's command/prompt is saved as a markdown file with YAML frontmatter.
- Frontmatter includes: name, description, tags, and other metadata.
- The exported file can later be imported via "Import Command" (full lifecycle).

### Story 12: Simplify Tasks Screen
**As a** macOS app user,
**I want to** see the Tasks screen focused on monitoring and status,
**so that** I have a clear overview without editor overlays cluttering the view.

**Acceptance Criteria:**
- The modal TaskEditorView is completely removed.
- TaskListView displays a clean task list with only action buttons (Run Now, Pause, Resume, Delete, Edit).
- "Edit" button navigates to the Editor tab instead of opening a modal.
- "New Task" button navigates to the Editor tab with a blank form.
- TaskListView remains focused on displaying task status, metrics, and execution summaries.
- The overall layout is cleaner and easier to scan.

---

## 3. Detailed Requirements

### 3.1 Editor Tab Navigation

#### Requirement E1.1: Add "Editor" to Sidebar
- **Description**: Update SidebarView enum to include `.editor` as a case.
- **Implementation Detail**: The enum `SidebarItem` should have three cases: `tasks`, `editor`, `logs`.
- **Acceptance Criteria**:
  - The sidebar renders three navigation buttons: "Tasks", "Editor", "Logs".
  - "Editor" is positioned between "Tasks" and "Logs".
  - The current selected tab is highlighted with the accent color and subtle background.
  - The active task count badge (if any) appears only on the "Tasks" button.

#### Requirement E1.2: Route "New Task" to Editor
- **Description**: When user clicks "New Task" on TaskListView, navigate to the Editor tab with a blank form.
- **Acceptance Criteria**:
  - `onNewTask()` callback sets the sidebar selection to `.editor`.
  - Editor receives a signal that a new task should be created (vs. editing an existing one).
  - The editor form is cleared and ready for input.
  - Form title displays "New Scheduled Task".

#### Requirement E1.3: Route "Edit" to Editor
- **Description**: When user clicks "Edit" from TaskDetailView or context menu, navigate to the Editor tab with the task loaded.
- **Acceptance Criteria**:
  - `onEdit()` callback sets the sidebar selection to `.editor` and passes the task ID.
  - Editor detects the task ID change and loads the task via the daemon.
  - Form title displays "Edit Task" (with task name).
  - All form fields are pre-populated with the task's current values.

#### Requirement E1.4: Persist Tab Selection
- **Description**: Remember the user's last selected sidebar tab during the session.
- **Acceptance Criteria**:
  - When the user navigates away from Editor and returns, the same tab view is displayed.
  - Tab selection is stored in a property (does not need to persist across app launches).

### 3.2 Editor View Layout

#### Requirement E2.1: Full-Screen Editor Panel
- **Description**: Display a dedicated, full-screen editor panel as the main content area (not a modal overlay).
- **Acceptance Criteria**:
  - The Editor view occupies the full content area (right side of the sidebar).
  - The sidebar remains visible and interactive.
  - Editor is not a sheet or modal; it is a standard view replacement.
  - Content is scrollable if it exceeds the view height.

#### Requirement E2.2: Form Organization
- **Description**: Organize form fields into logical sections for clarity.
- **Suggested Sections**:
  - **Basic Info**: Task Name, Claude Command
  - **Command & Location**: Skill (optional), Working Directory
  - **Schedule**: Schedule Builder
  - **Execution & Budget**: Max Budget per Run, Timeout, Max Turns (optional)
  - **Metadata**: Tags, Environment Variables
- **Acceptance Criteria**:
  - Each section is visually distinct (e.g., separated by spacing or subtle dividers).
  - Section headers are labeled and styled consistently.
  - Fields within sections follow a logical reading order (top to bottom, left to right for multi-column layouts).

#### Requirement E2.3: Header and Footer
- **Description**: Display a header and footer for navigation and actions.
- **Header**:
  - Left: "New Scheduled Task" (for new) or "Edit Task: [Task Name]" (for edit).
  - Right: Close button (X) to return to Tasks tab (with unsaved changes prompt if dirty).
- **Footer**:
  - Left: "Import Command" link/button.
  - Center: Unsaved changes indicator (if dirty).
  - Right: "Dry Run" button, "Cancel" button, "Save" button.
- **Acceptance Criteria**:
  - Header is fixed at the top of the editor panel.
  - Footer is fixed at the bottom (buttons remain visible while scrolling form).
  - All buttons and links are properly labeled and accessible.

### 3.3 Form Field Specifications

#### Requirement E3.1: Task Name Field
- **Description**: Text input for the task name.
- **Properties**:
  - Placeholder: "e.g., PR Review Sweep"
  - Validation: Non-empty, max 200 characters.
  - Display Error: "Task name is required" if empty; "Too long (max 200 chars)" if exceeded.
- **Acceptance Criteria**:
  - User can type and edit the task name freely.
  - Validation error appears below the field if invalid.
  - Focus is placed in this field when editor opens for a new task.

#### Requirement E3.2: Claude Command Field
- **Description**: Large text editor for the Claude command/prompt.
- **Properties**:
  - Placeholder: "claude -p 'Your prompt here...'"
  - Multiline: Yes, with wrapping.
  - Syntax Highlighting: Optional (can be basic; full syntax highlighting deferred to future).
  - Minimum Height: 120px; expands as needed.
  - Validation: Non-empty.
  - Display Error: "Command is required" if empty.
- **Acceptance Criteria**:
  - User can type multi-line commands with proper formatting.
  - Command field grows/shrinks with content (within reasonable bounds).
  - Validation error appears if field is empty.

#### Requirement E3.3: Skill Field (Optional)
- **Description**: Optional text input for Claude Code skill/command reference.
- **Properties**:
  - Placeholder: "/review-pr, /loop, etc."
  - Validation: Alphanumeric, hyphens, underscores (no spaces).
  - Display Error: "Invalid skill name" if format incorrect.
- **Acceptance Criteria**:
  - Field is optional; empty value is valid.
  - User can type a skill reference (e.g., "/review-pr").
  - Validation error appears if format is invalid.
  - Future enhancement: Dropdown of discovered skills (deferred).

#### Requirement E3.4: Working Directory Field
- **Description**: Text input with a folder picker button.
- **Properties**:
  - Placeholder: "~/projects/my-repo"
  - Folder Picker Button: Opens NSOpenPanel (directory selection only).
  - Validation: Valid path (expand `~`).
  - Display Error: "Invalid directory" if path does not exist (warning only, does not block save).
- **Acceptance Criteria**:
  - User can type a directory path or click the folder button.
  - Clicking folder button opens a native file browser.
  - Selected directory path is populated in the field.
  - Empty value defaults to current working directory (home, `~/`).

#### Requirement E3.5: Schedule Builder Dropdown
- **Description**: User-friendly schedule selection UI with preset options and custom cron editing.
- **Presets**:
  1. "Every 15 minutes" → `*/15 * * * *`
  2. "Every 30 minutes" → `*/30 * * * *`
  3. "Every hour" → `0 * * * *`
  4. "Every 2 hours" → `0 */2 * * *`
  5. "Every 4 hours" → `0 */4 * * *`
  6. "Daily at..." → Shows time picker; default to 09:00 → `0 9 * * *`
  7. "Weekdays at..." → Shows time picker; default to 09:00 → `0 9 * * 1-5`
  8. "Weekly on..." → Shows day-of-week checkboxes (Mon–Sun) and time picker; default Monday at 09:00 → `0 9 * * 1`
  9. "Monthly on..." → Shows day-of-month picker (1–31) and time picker; default 1st at 09:00 → `0 9 1 * *`
  10. "Custom (Advanced)" → Enables direct cron field editing.
- **Time Picker**:
  - Separate inputs for hour (0–23) and minute (0–59).
  - Incremental buttons (+ / -) for quick adjustment.
- **Cron Expression Field**:
  - Read-only, displays the computed cron expression.
  - Updates in real-time as selections change.
  - Font: Monospace.
  - User can copy the expression to clipboard (copy button).
- **Human-Readable Description**:
  - Below the cron field, displays a plain-English description (e.g., "Every weekday at 09:00").
  - Updates in real-time.
- **Advanced Toggle**:
  - A toggle switch or link labeled "Edit Cron Directly" or "Advanced".
  - When enabled, the cron field becomes editable (not read-only).
  - When disabled, cron field reverts to read-only and resets to the preset-generated value.
- **Acceptance Criteria**:
  - User can select a preset option from the dropdown.
  - Selecting a preset with time/day shows the appropriate picker UI.
  - Cron expression is generated correctly from all presets.
  - Cron expression and human-readable description are always visible.
  - Advanced toggle allows direct cron editing for power users.
  - Invalid cron expressions show a validation error.

#### Requirement E3.6: Max Budget per Run Field
- **Description**: Numeric input for spending limit per task execution.
- **Properties**:
  - Placeholder: "5.0"
  - Validation: Numeric, greater than 0, max 2 decimal places.
  - Display Error: "Budget must be a number greater than 0" if invalid.
  - Default: 5.0 (for new tasks).
- **Acceptance Criteria**:
  - User can type a decimal value (e.g., 5.0, 10.50).
  - Non-numeric input is rejected or sanitized.
  - Validation error appears if value is invalid or zero.

#### Requirement E3.7: Timeout (seconds) Field
- **Description**: Numeric input for execution timeout.
- **Properties**:
  - Placeholder: "600"
  - Validation: Numeric, greater than 0.
  - Display Error: "Timeout must be a positive number" if invalid.
  - Default: 600 (10 minutes for new tasks).
- **Acceptance Criteria**:
  - User can type a numeric value (e.g., 600, 3600).
  - Non-numeric input is rejected or sanitized.
  - Validation error appears if value is invalid or zero.

#### Requirement E3.8: Max Turns Field (Optional)
- **Description**: Optional numeric input for maximum conversation turns.
- **Properties**:
  - Placeholder: "Leave blank for no limit"
  - Validation: Numeric, greater than 0 (or empty).
  - Display Error: "Max turns must be a positive number or blank" if invalid.
- **Acceptance Criteria**:
  - Field is optional; empty value is valid (no limit).
  - User can type a numeric value if desired.
  - Validation error appears if value is invalid (non-numeric or zero).

#### Requirement E3.9: Tags Field
- **Description**: Tag input with add and remove functionality.
- **Properties**:
  - Input Placeholder: "Press enter to add tag"
  - Max Tags: 20.
  - Validation: Non-empty tag names, no special characters (alphanumeric, hyphens, underscores only).
  - Display Error: "Max 20 tags reached" if limit exceeded; "Invalid tag name" if format incorrect.
- **Tag Display**:
  - Each tag is displayed as a chip/pill with a remove (X) button.
  - Tags are displayed below the input field.
- **Acceptance Criteria**:
  - User can type a tag and press Enter to add it.
  - Tags appear as chips below the input.
  - Clicking the X on a chip removes the tag.
  - Validation error appears if tag format is invalid or limit is reached.
  - Input field clears after a tag is added.

#### Requirement E3.10: Environment Variables Field
- **Description**: Key-value editor for environment variables.
- **Properties**:
  - Display: List of key-value pairs, each with remove button.
  - Key Validation: Valid environment variable name (alphanumeric, underscore, uppercase convention).
  - Value: Any text (may include special chars).
  - Add Button: "Add Environment Variable" or "+ Add" to create a new pair.
  - Display Error: "Invalid key name" if key format incorrect.
- **Acceptance Criteria**:
  - User can add, edit, and remove environment variable pairs.
  - Keys are validated in real-time.
  - Values are stored as plain text.
  - Each pair has an independent remove button.
  - An "Add" button creates a new empty pair.

### 3.4 Save and Validation

#### Requirement E4.1: Explicit Save Button
- **Description**: A prominent "Save" button in the footer that persists changes.
- **States**:
  - **Disabled**: When form has no unsaved changes (form matches saved state).
  - **Enabled**: When form has unsaved changes.
  - **Loading**: When save is in progress (button shows spinner, text reads "Saving...").
  - **Error**: If save fails, button reverts to enabled and error message displays.
- **Keyboard Shortcut**: Cmd+S (when Editor tab is focused).
- **Acceptance Criteria**:
  - Save button is visible and properly labeled.
  - Button disabled state accurately reflects form dirty status.
  - Clicking Save triggers a daemon call to create/update the task.
  - Success clears the unsaved indicator and disables the button.
  - Failure shows an error message and keeps button enabled.

#### Requirement E4.2: Unsaved Changes Indicator
- **Description**: Visual indicator showing that the form has unsaved changes.
- **Display**:
  - A small red dot or "Unsaved" label next to the form title.
  - Only appears when form is dirty (has changes compared to saved state).
- **Acceptance Criteria**:
  - Indicator appears when user makes any change.
  - Indicator disappears after successful save.
  - Indicator is subtle but clearly visible.

#### Requirement E4.3: Validation and Error Display
- **Description**: Real-time validation of form fields with error messages.
- **Validation Rules**:
  - Task Name: Required, max 200 chars.
  - Command: Required, non-empty.
  - Budget: Numeric, > 0.
  - Timeout: Numeric, > 0.
  - Cron: Valid cron expression (if in advanced mode).
  - Schedule: Valid selection from presets or custom cron.
  - Tags: Alphanumeric + hyphens/underscores, max 20.
  - Env Var Keys: Valid environment variable names.
- **Error Display**:
  - Errors appear below the affected field in red text.
  - A summary of all validation errors appears above the form or in a dedicated error banner.
  - Save button is disabled if any validation errors are present.
- **Acceptance Criteria**:
  - Validation runs in real-time as user types.
  - Error messages are clear and actionable.
  - Save is blocked until all errors are resolved.

#### Requirement E4.4: Confirm Navigation with Unsaved Changes
- **Description**: Prompt user before navigating away with unsaved changes.
- **Trigger**: User clicks a different sidebar tab while form is dirty.
- **Dialog**:
  - Title: "You have unsaved changes"
  - Message: "Do you want to save, discard, or continue editing?"
  - Options: "Save", "Discard", "Cancel".
- **Behavior**:
  - "Save": Persists changes and navigates to the new tab.
  - "Discard": Loses changes and navigates to the new tab.
  - "Cancel": Remains in the Editor tab.
- **Acceptance Criteria**:
  - Dialog appears only when form is dirty.
  - Dialog does not appear if form is clean.
  - All three options work as expected.

### 3.5 Import and Dry-Run

#### Requirement E5.1: Import Command Button
- **Description**: A button or link to import Claude Code commands from the filesystem.
- **Location**: Editor footer (left side).
- **Label**: "Import Command" or "+ Import Command".
- **Behavior**:
  - Clicking opens the CommandImportView (existing component).
  - Upon successful import, the editor form is populated with the command's data.
  - Skill field is pre-filled with the command name (e.g., `/review-pr`).
  - Command/prompt is pre-filled with the command's content.
  - User can edit fields and save as a new task.
- **Acceptance Criteria**:
  - Button is visible and clickable.
  - CommandImportView opens as an overlay.
  - Upon import, form is updated with command data.
  - User can proceed to edit and save the task.

#### Requirement E5.2: Dry-Run Button
- **Description**: A button to test the task without saving.
- **Location**: Editor footer (right side, next to Save).
- **Label**: "Dry Run" or "Preview".
- **Behavior**:
  - Clicking does NOT save the draft.
  - Sends the current draft to the daemon's dry-run endpoint.
  - Displays the dry-run result in a sheet/modal.
  - Result shows: resolved command, parsed schedule, budget, timeout, warnings.
- **Dry-Run Result Sheet**:
  - Resolved command (with env vars applied).
  - Human-readable schedule description.
  - Budget and timeout values.
  - Any warnings (e.g., budget exceeded, path not found).
  - Close button to dismiss (without affecting draft form).
- **Acceptance Criteria**:
  - Dry Run button is visible.
  - Clicking Dry Run does not save the form.
  - Dry-run result sheet appears with correct information.
  - Closing the sheet leaves the draft form intact.

### 3.6 Schedule Builder Details

#### Requirement E6.1: Preset Schedule Options
- **Description**: Implement each preset schedule with correct cron generation.
- **Presets and Cron Mappings**:
  1. "Every 15 minutes" → `*/15 * * * *`
  2. "Every 30 minutes" → `*/30 * * * *`
  3. "Every hour" → `0 * * * *`
  4. "Every 2 hours" → `0 */2 * * *`
  5. "Every 4 hours" → `0 */4 * * *`
  6. "Daily at HH:MM" → `0 HH * * *` (user selects hour and minute)
  7. "Weekdays at HH:MM" → `0 HH * * 1-5` (user selects hour and minute)
  8. "Weekly on DAY at HH:MM" → `0 HH * * D` where D = 0-6 (Sun-Sat; user selects day and time)
  9. "Monthly on DAY at HH:MM" → `0 HH D * *` where D = 1-31 (user selects day and time)
  10. "Custom (Advanced)" → Direct cron editing.
- **Acceptance Criteria**:
  - Each preset generates the correct cron expression.
  - Cron field updates immediately when a preset is selected.
  - Human-readable description is accurate for each preset.

#### Requirement E6.2: Time Picker Implementation
- **Description**: Implement hour and minute selection UI.
- **Components**:
  - Hour input: Text field or stepper (0–23, padded to 2 digits).
  - Minute input: Text field or stepper (0–59, padded to 2 digits).
  - Increment/Decrement buttons: + / - for quick adjustment.
- **Validation**:
  - Hour: 0–23.
  - Minute: 0–59.
- **Acceptance Criteria**:
  - User can select hour and minute via input or stepper.
  - Values are validated in real-time.
  - Cron expression updates immediately when time changes.

#### Requirement E6.3: Day-of-Week Picker
- **Description**: Checkbox UI for selecting days of the week.
- **Days**: Mon, Tue, Wed, Thu, Fri, Sat, Sun (or checkboxes for each).
- **Default**: Monday selected.
- **Cron Generation**: `0 HH * * D` where D = 0-6 (Sunday = 0).
- **Acceptance Criteria**:
  - User can check/uncheck days.
  - Cron expression updates to include selected days.
  - Multiple days are supported (e.g., "Mondays and Wednesdays" → `0 HH * * 1,3`).

#### Requirement E6.4: Day-of-Month Picker
- **Description**: Dropdown or number input for selecting a day of the month.
- **Range**: 1–31.
- **Default**: 1st.
- **Cron Generation**: `0 HH D * *` where D = 1-31.
- **Acceptance Criteria**:
  - User can select a day (1–31).
  - Cron expression updates immediately.
  - Invalid days (e.g., Feb 30th) are allowed in the UI (daemon validates).

#### Requirement E6.5: Advanced Cron Editing
- **Description**: Allow power users to edit cron directly.
- **Toggle**: "Edit Cron Directly" or "Advanced" toggle.
- **Behavior**:
  - When disabled (default): Cron field is read-only, preset-generated.
  - When enabled: Cron field becomes editable text input.
  - When toggled back to disabled: Cron field reverts to read-only and preset-generated value.
- **Validation**: Invalid cron expressions show an error.
- **Acceptance Criteria**:
  - Toggle is clearly labeled and easy to find.
  - Cron field is editable when toggle is on.
  - Cron is validated and errors are displayed.

### 3.7 Data Persistence and API Integration

#### Requirement E7.1: Load Task Data from Daemon
- **Description**: Fetch task details from the daemon via JSON-RPC when opening editor for an existing task.
- **Endpoint**: `get_task(id)` JSON-RPC method (existing).
- **Behavior**:
  - Editor detects task ID change (from navigation).
  - Issues JSON-RPC request to daemon.
  - Displays loading state while fetching.
  - Populates form with task data upon success.
  - Shows error message if fetch fails.
- **Acceptance Criteria**:
  - Loading spinner appears while fetching.
  - Task data is correctly populated in form.
  - Error is handled gracefully with a user-facing message.

#### Requirement E7.2: Save Task to Daemon
- **Description**: Persist task changes via daemon JSON-RPC.
- **Endpoints**:
  - `create_task(params)` for new tasks.
  - `update_task(id, params)` for existing tasks.
- **Behavior**:
  - User clicks Save button.
  - Form is validated; if errors, show error banner and don't proceed.
  - Issue JSON-RPC request with task data.
  - Display loading state (button shows spinner).
  - On success: Clear unsaved indicator, disable Save button, show success toast (optional).
  - On failure: Show error message, keep Save button enabled.
- **Task Data Sent**:
  - All form fields (name, command, skill, schedule, budget, timeout, tags, env vars, etc.).
  - Cron expression in the Schedule object.
  - Working directory path (expanded if needed).
- **Acceptance Criteria**:
  - Form data is correctly serialized and sent to daemon.
  - Save state is reflected accurately in the UI.
  - Success and failure states are handled.

#### Requirement E7.3: Dry-Run Request to Daemon
- **Description**: Send draft form data to daemon's dry-run endpoint (no save).
- **Endpoint**: `dry_run(params)` JSON-RPC method (existing).
- **Behavior**:
  - User clicks "Dry Run" button.
  - Form is validated; if errors, show error message and don't proceed.
  - Issue JSON-RPC request with current draft data.
  - Display loading state.
  - On success: Show dry-run result sheet with resolved command, schedule, budget, warnings.
  - On failure: Show error message in dry-run sheet.
- **Acceptance Criteria**:
  - Dry-run request is sent without saving the form.
  - Dry-run result is displayed clearly.
  - Form is not affected by dry-run action.

### 3.8 Non-Breaking Changes

#### Requirement E8.1: CLI Unchanged
- **Description**: No changes to the CLI (`lc` command).
- **Acceptance Criteria**:
  - All existing CLI commands continue to work.
  - No new CLI commands are added (out of scope for this feature).

#### Requirement E8.2: Daemon API Unchanged
- **Description**: No changes to JSON-RPC API or data models.
- **Acceptance Criteria**:
  - Existing JSON-RPC methods remain unchanged.
  - Task data models (LCTask, LCTaskDraft) remain compatible.
  - No new daemon endpoints are added (use existing `create_task`, `update_task`, `dry_run`, etc.).

#### Requirement E8.3: Data Persistence Format Unchanged
- **Description**: No changes to YAML task files or SQLite schema.
- **Acceptance Criteria**:
  - Task YAML files continue to be written and read in the current format.
  - SQLite logs database is unaffected.
  - Backward compatibility is maintained.

---

## Appendix: UI Component Reference

### Colors and Styling
- Use existing design system colors: `.lcAccent`, `.lcSurface`, `.lcCodeBackground`, `.lcTextPrimary`, etc.
- Form fields use the same styling as existing TaskEditorView components.
- Buttons follow existing button styles: `LCPrimaryButtonStyle`, `LCSecondaryButtonStyle`, `LCDangerButtonStyle`.

### Typography
- Section headers: `.lcSectionLabel`
- Field labels: `.lcLabel`
- Form input: `.lcInput`
- Error text: `.lcCaption` in red (`Color.lcRed`)

### Spacing and Sizing
- Use existing spacing constants: `LCSpacing.p20`, `LCSpacing.p32`, etc.
- Form width: ~600–700px (constrained for readability).
- Editor panel height: Full viewport height (minus app chrome).

### Accessibility
- All form fields have proper accessibility labels.
- Tab navigation is supported.
- Error messages are announced to assistive technologies.
- Keyboard shortcuts are provided (Cmd+S for save, Cmd+E to edit, etc.).

---

## Summary

This feature transforms Loop Commander from a task scheduler into a comprehensive task and skill management hub. By replacing the modal editor with a dedicated, full-featured Editor tab, users gain:

1. **Better context**: See tasks, logs, and editor side-by-side without modal overlays.
2. **Friendlier workflows**: Drag-and-drop command import, schedule builder UI, environment variable management.
3. **Stronger safety**: Explicit save, unsaved changes detection, and dry-run validation.
4. **Extensibility**: Foundation for future enhancements (skill marketplace, template sharing, etc.).

All changes remain UI-layer only, preserving backward compatibility with the CLI, daemon, and data formats.
