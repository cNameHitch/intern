# Editor Tab: Rust/Daemon Assessment

## 1. API Assessment

The existing JSON-RPC interface already covers the editor's data needs. No modifications to existing methods are required.

| Editor Need                        | JSON-RPC Method   | Notes                                              |
|------------------------------------|--------------------|----------------------------------------------------|
| Load task for editing              | `task.get`         | Returns full task YAML fields as JSON               |
| Create new task from editor        | `task.create`      | Accepts all task fields; returns created task ID    |
| Save edits to existing task        | `task.update`      | Partial update; daemon handles YAML write + plist   |
| Validate before save (dry run)     | `task.dry_run`     | Returns validation errors without persisting        |
| List available templates           | `templates.list`   | Provides starter templates for the "New Task" flow  |
| List all tasks (sidebar browser)   | `task.list`        | Used to populate the editor's task navigator        |
| Delete a task                      | `task.delete`      | Removes task YAML, plist, and launchd registration  |

All methods return standard JSON-RPC 2.0 responses over the Unix domain socket at `~/.loop-commander/daemon.sock`. The Swift app already uses these methods on the Tasks tab; the Editor tab reuses the same `DaemonClient` transport with no changes.

## 2. New API Methods

One optional additive method is recommended to support the schedule builder UI.

### `schedule.validate`

Validates a cron expression without creating or modifying any task.

**Request:**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "schedule.validate",
  "params": {
    "expression": "0 9 * * 1-5"
  }
}
```

**Success response:**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "valid": true
  }
}
```

**Failure response:**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "valid": false,
    "error": "invalid day-of-week value: 8"
  }
}
```

**Implementation plan:**

1. Add the `cron` crate (`cron = "0.12"`) to `lc-scheduler/Cargo.toml` under `[dependencies]`.
2. Add a public validation function in `lc-scheduler` (~5 lines):
   ```rust
   pub fn validate_cron(expr: &str) -> Result<(), String> {
       expr.parse::<cron::Schedule>()
           .map(|_| ())
           .map_err(|e| e.to_string())
   }
   ```
3. Register a `schedule.validate` handler in `lc-daemon/src/server.rs` (~15 lines) that deserializes the params, calls `validate_cron`, and returns the result.

Total scope: ~20 lines of Rust across two files. No schema changes, no database changes, no config changes.

This method is **optional** -- the Swift editor can ship without it by performing client-side regex validation on cron strings. The daemon method provides authoritative validation using the same parser the scheduler uses internally.

## 3. Claude Command Scanning

The editor's "Import Command" feature scans the filesystem for Claude Code command files (`.md` files under `.claude/commands/` directories). This is handled entirely in Swift via `FileManager` directory enumeration. No daemon method is needed because:

- Command files are read-only local `.md` files.
- Scanning is a pure filesystem operation with no daemon state involved.
- The imported content is transformed into a `task.create` call, which already exists.

## 4. Non-Breaking Guarantees

The following components require **zero changes** for the Editor tab:

| Component             | Status    | Rationale                                          |
|-----------------------|-----------|----------------------------------------------------|
| `lc-core`             | Unchanged | Domain types, error enums, IPC message structs      |
| `lc-config`           | Unchanged | YAML read/write logic, config schema                |
| `lc-scheduler`        | Unchanged | Plist generation, launchctl bootstrap/bootout       |
| `lc-runner`           | Unchanged | Standalone execution binary                         |
| `lc-logger`           | Unchanged | SQLite persistence, query interface                 |
| `lc-cli`              | Unchanged | CLI commands, argument parsing                      |
| All existing JSON-RPC methods | Unchanged | Request/response schemas, behavior, error codes |
| Socket protocol       | Unchanged | Unix domain socket, JSON-RPC 2.0 framing            |
| On-disk formats       | Unchanged | Task YAML, config YAML, plist XML, SQLite schema    |

If `schedule.validate` is added, it is a purely additive method. Older clients that do not call it are unaffected. Newer clients that call it against an older daemon will receive a standard JSON-RPC "method not found" error (-32601), which the Swift layer can handle gracefully by falling back to client-side validation.

## 5. Summary

- **Zero breaking changes** to any Rust crate, data format, or protocol.
- **Zero schema changes** to task YAML, config YAML, SQLite, or JSON-RPC method signatures.
- **One optional additive method** (`schedule.validate`) requiring ~20 lines across `lc-scheduler` and `lc-daemon`.
- All editor functionality is served by the existing daemon API. The work is entirely in the Swift UI layer.
