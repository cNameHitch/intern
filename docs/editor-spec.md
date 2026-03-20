# Editor Tab Feature Specification

This document is the master index for the Editor Tab feature — a full-featured, persistent editor that replaces the modal task editor and positions Loop Commander as the single point for editing and executing all Claude skills and commands.

## Spec Documents

| Document | Description |
|----------|-------------|
| [Product Requirements](editor-product-requirements.md) | Overview, motivation, 12 user stories, detailed acceptance criteria for all requirements |
| [UI Design](editor-ui-design.md) | Component hierarchy, wireframes, design tokens, schedule builder wireframe, interaction patterns, accessibility |
| [Swift Implementation](editor-swift-implementation.md) | File-by-file implementation plan: new views, view models, enums, migration from modal, dirty state management |
| [Rust/Daemon Assessment](editor-rust-assessment.md) | API gap analysis, non-breaking guarantees, one recommended new RPC method (schedule.validate) |

## Summary

### What Changes

- **New sidebar tab**: "Editor" between Tasks and Logs
- **New full-width editor view**: Two-pane layout (60% prompt editor, 40% settings panel)
- **Schedule builder UI**: Preset dropdown with sub-pickers, no cron knowledge required
- **Explicit save**: No auto-save, dirty state tracking, navigation guards
- **Modal removal**: TaskEditorView modal overlay is retired; all editing flows route to the Editor tab

### What Does NOT Change

- Rust daemon, CLI, JSON-RPC API, data formats
- TaskListView, LogsView, TaskDetailView (signatures unchanged)
- DaemonClient, all model types
- Existing shared UI components (LCFormField, LCTextField, TagChip, etc.)

### New Files (Swift)

| File | Purpose |
|------|---------|
| `Views/EditorView.swift` | Full-width two-panel editor tab |
| `ViewModels/EditorViewModel.swift` | Draft state, dirty tracking, save/discard, validation |
| `Views/ScheduleBuilderView.swift` | Preset picker + conditional sub-pickers + cron readout |
| `Models/SchedulePreset.swift` | Enum with cron generation and reverse parsing |

### Modified Files (Swift)

| File | Change |
|------|--------|
| `Views/SidebarView.swift` | Add `.editor` case, dirty dot badge |
| `Views/ContentView.swift` | Add EditorView to ZStack, remove modal overlay, wire notifications |
| `LoopCommanderApp.swift` | Add editor to View menu, create EditorViewModel |
| `Models/LCTask.swift` | Add `LCTaskDraft.isEqual(to:)` for dirty comparison |

### Rust Changes (Minimal)

One optional new method recommended: `schedule.validate` — validates a cron expression and returns success or parse error. Requires adding the `cron` crate to `lc-scheduler`. All existing methods and schemas are unchanged.

## Implementation Order

1. Create `SchedulePreset` enum and `ScheduleBuilderView` (self-contained, testable in isolation)
2. Create `EditorViewModel` with draft/dirty/save logic
3. Create `EditorView` with two-pane layout
4. Modify `SidebarView` to add `.editor` case with dirty badge
5. Modify `ContentView` to add editor to ZStack, remove modal overlay, wire notifications
6. Update `LoopCommanderApp` menu commands
7. (Optional) Add `schedule.validate` to Rust daemon
8. Integration testing and cleanup
