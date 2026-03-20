# Loop Commander -- Master Implementation Prompt

> **Audience:** Agent team (rust-engineer, swift-expert, cli-developer) building the full project from scratch.
> **Working directory:** `/Users/hitch/Desktop/git/loop-commander/`
> **Source documents (read these in full before starting):**
> - `specs.md` -- Complete implementation spec (domain types, crate contracts, daemon, CLI, Swift app, production addendum)
> - `SWIFTUI_DESIGN_REFERENCE.md` -- Pixel-level SwiftUI design mapping from the React prototype
> - `loop-commander.jsx` -- React prototype (visual reference, sample data structures, interaction patterns)

---

## Project Overview

Loop Commander is a native macOS scheduler for Claude Code tasks. It runs as a persistent background daemon managed by launchd, stores execution logs in SQLite, and exposes a JSON-RPC 2.0 API over a Unix domain socket. Two clients consume this API: a CLI tool (`lc`) and a native SwiftUI macOS app.

**Architecture in one sentence:** launchd triggers `lc-runner` per schedule, the daemon (`loop-commander`) owns all state and serves it over a socket, and both `lc` CLI and the Swift app are thin clients.

---

## Critical Constraints (read before writing any code)

These are the non-obvious requirements that cause the most debugging time if missed. Every agent must internalize these before starting implementation.

### CC-1. Atomic YAML Writes
All YAML file writes in `ConfigManager::save_task()` MUST use the atomic write pattern:
1. Write to `{task-id}.yaml.tmp` in the same directory
2. `fsync` the file descriptor
3. `std::fs::rename` the temp file to the final path

Rename is atomic on POSIX. This prevents corrupt YAML if the process crashes mid-write. `lc-runner` also writes task status back to YAML (for the `Running` -> `Active`/`Error` transition), so this applies there too.

### CC-2. Command Injection Prevention
**NEVER** construct commands via string interpolation into a shell. Use `tokio::process::Command::new("claude")` with `.arg("-p").arg(&task.command)` -- pass arguments as an array.

For commands that start with `claude`, parse the command into argv tokens. For all other commands, the user must explicitly use `sh -c '...'` if they need shell features. Document this behavior clearly.

The runner MUST NOT use `sh -c <user_string>` by default. See `specs.md` Section 14.1, item C2 for the full rationale.

### CC-3. Input Validation on All Mutating Paths
Add `validate()` methods on `CreateTaskInput` and `UpdateTaskInput` (specs.md C3). Enforce these rules:
- `name`: non-empty, max 200 chars, no control characters
- `command`: non-empty, max 10,000 chars
- `working_dir`: path exists and is a directory (after tilde expansion)
- `schedule`: cron expression parses successfully
- `max_budget_per_run`: > 0 and <= 100.0
- `timeout_secs`: > 0 and <= 86400
- `tags`: each max 50 chars, max 20 tags

Call `validate()` in the daemon's `task.create` and `task.update` handlers. Return structured JSON-RPC errors (see CC-8 for error codes).

### CC-4. Daemon Single-Instance Locking
On startup, the daemon MUST:
1. Check if PID file exists AND the process is alive (`kill(pid, 0)`)
2. If alive, print error and exit
3. Use `flock()` on the PID file as a belt-and-suspenders guard
4. Check if socket file exists -- try to connect. If connection succeeds, another daemon is running. If it fails, the socket is stale; remove it.

See `specs.md` Section 14.1, item C4.

### CC-5. SQLite WAL Mode + busy_timeout
Every `Logger::new()` MUST execute:
```sql
PRAGMA journal_mode=WAL;
PRAGMA busy_timeout=5000;
```
WAL mode allows concurrent reads while `lc-runner` writes. `busy_timeout` prevents "database is locked" errors when the daemon and runner access the DB simultaneously.

### CC-6. Socket Path
The Unix domain socket MUST be at `~/.loop-commander/daemon.sock`, NOT in `/tmp/`. Using `/tmp/` is vulnerable to symlink attacks on shared machines. The `LcPaths` struct enforces this.

### CC-7. launchctl Modern API
Use `launchctl bootstrap gui/<uid> <plist_path>` and `launchctl bootout gui/<uid>/<label>` (macOS 13+).

Fall back to deprecated `launchctl load -w` / `launchctl unload` ONLY if the modern API fails. Use `launchctl print gui/<uid>/<label>` to check job status (exit 0 = loaded). Do NOT parse `launchctl list` output.

When `bootstrap` returns errno 37 ("already loaded"), treat it as success.

Get the UID via `id -u` or `nix::unistd::getuid()`.

### CC-8. Structured JSON-RPC Error Codes
Define these in `lc-core` and use consistently:
- `-32001`: Task not found
- `-32002`: Validation error (include details in `data` field)
- `-32003`: Scheduler error
- `-32004`: Database error
- `-32005`: Daemon busy / resource locked
- `-32006`: Budget exceeded
- Standard JSON-RPC: `-32600` (invalid request), `-32601` (method not found), `-32602` (invalid params), `-32603` (internal error)

### CC-9. Concurrency Limit
Default `max_concurrent_tasks = 4` in `GlobalConfig`. Enforced two ways:
- **Daemon-side** (for `task.run_now`): `tokio::sync::Semaphore` with N permits. If full, queue in a `VecDeque<TaskId>`.
- **Runner-side** (for launchd-scheduled tasks): Named POSIX semaphore `/loop-commander-concurrency`. If not acquired within 60s, log as `Skipped` and exit 0.

### CC-10. Budget Tracking
Use actual API costs from Claude Code's `--output-format json` output as primary. Fall back to time-based estimation: `estimated_cost = duration_seconds * cost_estimate_per_second` (default: $0.01/sec). Mark estimates with `cost_is_estimate = true` on `ExecutionLog`. Daily budget cap defaults to `max_budget_per_run * 20` but is configurable via `GlobalConfig.daily_budget_cap`.

---

## File Structure

Create this exact structure rooted at `/Users/hitch/Desktop/git/loop-commander/`:

```
loop-commander/
+-- Cargo.toml                            # Workspace root (specs.md Section 1)
+-- CLAUDE.md                             # Project guide (specs.md Section 12)
+-- crates/
|   +-- lc-core/
|   |   +-- Cargo.toml
|   |   +-- src/lib.rs
|   +-- lc-config/
|   |   +-- Cargo.toml
|   |   +-- src/lib.rs
|   +-- lc-scheduler/
|   |   +-- Cargo.toml
|   |   +-- src/lib.rs
|   +-- lc-runner/
|   |   +-- Cargo.toml
|   |   +-- src/
|   |       +-- main.rs
|   |       +-- lib.rs                    # Shared logic (build_command, etc.)
|   +-- lc-logger/
|   |   +-- Cargo.toml
|   |   +-- src/lib.rs
|   +-- lc-daemon/
|   |   +-- Cargo.toml
|   |   +-- src/
|   |       +-- main.rs
|   |       +-- server.rs                 # JSON-RPC dispatch
|   |       +-- health.rs                 # 60s health check loop
|   |       +-- events.rs                 # DaemonEvent types + broadcast
|   +-- lc-cli/
|       +-- Cargo.toml
|       +-- src/main.rs
+-- macos-app/
    +-- LoopCommander.xcodeproj/
    +-- LoopCommander/
    |   +-- LoopCommanderApp.swift
    |   +-- Models/
    |   |   +-- LCTask.swift
    |   |   +-- ExecutionLog.swift
    |   |   +-- DashboardMetrics.swift
    |   |   +-- TaskStatus.swift
    |   |   +-- Schedule.swift
    |   +-- Services/
    |   |   +-- DaemonClient.swift
    |   |   +-- DaemonMonitor.swift
    |   |   +-- EventStream.swift
    |   +-- ViewModels/
    |   |   +-- TaskListViewModel.swift
    |   |   +-- TaskDetailViewModel.swift
    |   |   +-- LogsViewModel.swift
    |   |   +-- DashboardViewModel.swift
    |   |   +-- MenuBarViewModel.swift
    |   +-- Views/
    |   |   +-- ContentView.swift
    |   |   +-- SidebarView.swift
    |   |   +-- TaskListView.swift
    |   |   +-- TaskDetailView.swift
    |   |   +-- TaskEditorView.swift
    |   |   +-- LogsView.swift
    |   |   +-- MetricsBarView.swift
    |   |   +-- StatusBadge.swift
    |   |   +-- SparklineChart.swift
    |   |   +-- Components/
    |   |       +-- MetricCard.swift
    |   |       +-- TaskRow.swift
    |   |       +-- TaskTableHeader.swift
    |   |       +-- LogEntryRow.swift
    |   |       +-- LogTableHeader.swift
    |   |       +-- TagChip.swift
    |   |       +-- LCTextField.swift
    |   |       +-- LCTextEditor.swift
    |   |       +-- LCFormField.swift
    |   |       +-- DaemonBanner.swift
    |   |       +-- MenuBarView.swift
    |   +-- Styles/
    |   |   +-- Color+LoopCommander.swift
    |   |   +-- Font+LoopCommander.swift
    |   |   +-- LCSpacing.swift
    |   |   +-- LCRadius.swift
    |   |   +-- LCBorder.swift
    |   |   +-- LCAnimations.swift
    |   |   +-- LCButtonStyles.swift
    |   |   +-- StatusConfig.swift
    |   +-- Utilities/
    |   |   +-- Formatters.swift
    |   +-- Assets.xcassets/
    +-- LoopCommanderTests/
```

---

## Phase 1: Foundation Crates (Parallelizable)

**Goal:** Build `lc-core`, `lc-config`, and `lc-logger`. These three crates have no dependencies on each other (only `lc-config` and `lc-logger` depend on `lc-core`). All three can be built simultaneously.

### 1A. Workspace Root

Create `Cargo.toml` at the workspace root with the exact workspace configuration from `specs.md` Section 1. Copy the `[workspace.dependencies]` block verbatim. Key versions:
- `rusqlite = { version = "0.31", features = ["bundled"] }` -- `bundled` compiles SQLite from source, includes FTS5
- `tokio = { version = "1", features = ["full"] }` -- full runtime for async
- `thiserror = "2"` -- not "1"
- `clap = { version = "4", features = ["derive"] }` -- derive macros for CLI

### 1B. `lc-core` -- Domain Types

**Source:** `specs.md` Section 2 (full Rust source is provided -- implement it verbatim).

This crate defines ALL shared types. Implement every type exactly as specified:
- `TaskId` -- format `lc-XXXXXXXX` (8 hex chars from UUID v4)
- `Schedule` -- tagged enum with `Cron`, `Interval`, `Calendar` variants
- `TaskStatus` -- `Active`, `Paused`, `Error`, `Disabled` + add `Running` (per R9)
- `Task` -- full struct with all fields including `env_vars`, `max_turns`, `timeout_secs`
- `ExecStatus` -- `Success`, `Failed`, `Timeout`, `Killed`, `Skipped` with `Display` and `FromStr`
- `ExecutionLog` -- includes `tokens_used: Option<u64>`, `cost_usd: Option<f64>`
- `TaskMetrics`, `DashboardMetrics` -- aggregation types
- `JsonRpcRequest`, `JsonRpcResponse`, `JsonRpcError` -- IPC protocol
- `CreateTaskInput`, `UpdateTaskInput`, `LogQuery` -- DTOs
- `LcError` -- all error variants including `BudgetExceeded`
- `LcPaths` -- all paths under `~/.loop-commander/`, socket at `daemon.sock` (NOT /tmp/)

**Additional types from nice-to-have features (implement now, they are used by the daemon):**
- `TaskTemplate` struct + `BUILTIN_TEMPLATES` const array (5 templates, see specs.md N1)
- `DailyCost` struct (date, total_cost, run_count -- see specs.md N2)
- `DryRunResult` struct (resolved_command, working_dir, env_vars, budget info -- see specs.md N5)
- `TaskExport` struct (portable task definition -- see specs.md N4)
- `DaemonEvent` enum (see `specs.md` Section 7, `events.rs`)

**Add JSON-RPC error code constants (CC-8):**
```rust
pub mod rpc_errors {
    pub const TASK_NOT_FOUND: i32 = -32001;
    pub const VALIDATION_ERROR: i32 = -32002;
    pub const SCHEDULER_ERROR: i32 = -32003;
    pub const DATABASE_ERROR: i32 = -32004;
    pub const DAEMON_BUSY: i32 = -32005;
    pub const BUDGET_EXCEEDED: i32 = -32006;
}
```

**Add validation methods (CC-3):**
Implement `CreateTaskInput::validate() -> Result<(), Vec<String>>` and `UpdateTaskInput::validate() -> Result<(), Vec<String>>` that enforce all rules listed in CC-3.

**Tests:** (specs.md Section 10, lc-core)
- `TaskId::new()` generates `lc-XXXXXXXX` format
- `Schedule::to_human()` for all three variants
- Serde round-trip for `Task`, `ExecutionLog`
- `JsonRpcResponse::success()` and `::error()`
- Validation: empty name fails, budget of 0 fails, valid input passes

### 1C. `lc-config` -- Configuration Layer

**Source:** `specs.md` Section 3 (behavior contract provided).

**Dependencies:** `lc-core` (local path)

Implement `ConfigManager` with the exact interface from the spec:
- `GlobalConfig` struct with all fields: `version`, `claude_binary`, `default_budget`, `default_timeout`, `default_max_turns`, `log_retention_days`, `notifications_enabled`, `max_concurrent_tasks` (default: 4), `daily_budget_cap` (default: None, meaning max_budget_per_run * 20), `cost_estimate_per_second` (default: 0.01), `theme` (default: "dark")
- Config file at `~/.loop-commander/config.yaml`
- Per-task files at `~/.loop-commander/tasks/{task-id}.yaml`
- `list_tasks()` -- per-file try/catch: parse each YAML individually, log warnings for corrupt files, return valid tasks + warnings (per R1)
- `save_task()` -- **atomic writes** (CC-1): write to .tmp, fsync, rename
- `expand_path()` -- expand `~` to home dir
- `create_task_from_input()` -- apply defaults from GlobalConfig
- `apply_update()` -- partial update of existing task
- Use block scalar style for `command` field in YAML output

**Gotcha:** When serializing YAML, the `command` field should use block scalar style (`>-`) so multiline prompts are readable.

**Tests:** (specs.md Section 10, lc-config)
- CRUD for task YAML files (create, read, update, delete)
- Global config defaults when file does not exist
- Tilde expansion in paths
- `CreateTaskInput` -> `Task` with all defaults filled
- Corrupt YAML file: `list_tasks()` returns valid tasks + warning (not a crash)

### 1D. `lc-logger` -- SQLite Persistence

**Source:** `specs.md` Section 6 (full SQL schema and behavior contract provided).

**Dependencies:** `lc-core` (local path)

Implement `Logger` with:
- `new(db_path)` -- open or create DB, run migrations, enable WAL mode, set `busy_timeout(5000)` (CC-5)
- Schema from specs.md Section 6 (the exact CREATE TABLE and CREATE INDEX statements)
- Add schema versioning (R7): `schema_version` table, insert version 1 on creation, check on startup
- `insert_log()` -- insert ExecutionLog, return auto-generated ID
- `query_logs(LogQuery)` -- filter by task_id, status, limit, offset, search (LIKE for now, FTS5 later)
- `get_dashboard_metrics(tasks)` -- aggregate metrics across all tasks
- `get_task_metrics(task_id)` -- per-task aggregation
- `total_cost_since(task_id, since)` -- for budget checking
- `prune_logs(retention_days)` -- delete old entries
- `get_cost_trend(days)` -- daily cost aggregation for sparkline (specs.md N2):
  ```sql
  SELECT DATE(started_at) as date, COALESCE(SUM(cost_usd), 0.0) as total_cost,
         COUNT(*) as run_count
  FROM execution_logs WHERE started_at >= datetime('now', '-N days')
  GROUP BY DATE(started_at) ORDER BY date ASC
  ```
  Backfill missing days with zero values so the frontend always gets exactly N data points.

**Tests:** (specs.md Section 10, lc-logger)
- DB creation and migration (idempotent -- run migrate() twice, no error)
- Insert + query round-trip
- Query with filters (task_id, status, limit, offset)
- Dashboard metrics aggregation
- Log pruning deletes old entries
- `total_cost_since` returns correct sum
- Schema version check

### Phase 1 Verification Gate

Before proceeding to Phase 2, ALL of the following must pass:
```bash
cargo build --workspace           # All three crates compile
cargo test -p lc-core             # All lc-core tests pass
cargo test -p lc-config           # All lc-config tests pass
cargo test -p lc-logger           # All lc-logger tests pass
cargo clippy --workspace          # No warnings
```

---

## Phase 2: Infrastructure Crates (Sequential dependency on Phase 1)

**Goal:** Build `lc-scheduler` and `lc-runner`. These depend on Phase 1 crates. They can be built in parallel with each other.

### 2A. `lc-scheduler` -- launchd Integration

**Source:** `specs.md` Section 4 (full behavior contract and cron conversion table provided).

**Dependencies:** `lc-core`, `lc-config`, `plist` crate

Implement `Scheduler` with the exact interface from the spec:
- `find_runner()` -- search in order: (1) same dir as current exe, (2) `~/.cargo/bin/lc-runner`, (3) `/usr/local/bin/lc-runner`, (4) `which lc-runner`
- `register(task)` -- generate plist XML, write to `~/.loop-commander/plists/`, symlink to `~/Library/LaunchAgents/`
- `activate(task)` -- `launchctl bootstrap gui/<uid> <plist>` (CC-7). Handle errno 37 as success.
- `deactivate(task_id)` -- `launchctl bootout gui/<uid>/<label>` (CC-7)
- `unregister(task_id)` -- remove plist file + symlink
- `install(task)` -- register + activate
- `uninstall(task_id)` -- deactivate + unregister
- `reinstall(task)` -- deactivate, re-register, re-activate
- `is_loaded(task_id)` -- `launchctl print gui/<uid>/<label>` (exit 0 = loaded)

**Plist structure:**
- `Label`: `com.loopcommander.task.{id}`
- `ProgramArguments`: `[path_to_lc_runner, "--task-id", "{id}"]`
- Schedule: `StartInterval` OR `StartCalendarInterval` (from task schedule)
- `WorkingDirectory`: task.working_dir (expanded)
- `StandardOutPath`: `~/.loop-commander/output/{id}.stdout.log`
- `StandardErrorPath`: `~/.loop-commander/output/{id}.stderr.log`
- `RunAtLoad`: false
- `KeepAlive`: false

**Cron-to-launchd conversion** (specs.md Section 4, conversion table):
- `*/N * * * *` -> `StartInterval: N*60`
- `0 */N * * *` -> `StartInterval: N*3600`
- `M H * * *` -> `StartCalendarInterval: {Hour: H, Minute: M}`
- `M H * * D` -> single `StartCalendarInterval: {Weekday: D, Hour: H, Minute: M}`
- `M H * * D1-D2` -> **ARRAY** of `StartCalendarInterval` dicts, one per weekday. This is critical for `0 7 * * 1-5` (weekdays at 7 AM) which must generate 5 dicts.
- Invalid/unsupported expressions -> return error, not silent wrong behavior

**Gotcha:** launchd's `StartCalendarInterval` accepts either a single dict or an ARRAY of dicts. For weekday ranges, you MUST generate an array.

**Tests:** (specs.md Section 10, lc-scheduler)
- Plist generation for Interval schedule
- Plist generation for Calendar schedule
- Cron conversions: `*/15 * * * *` -> 900, `0 */2 * * *` -> 7200, `0 7 * * 1-5` -> array of 5 dicts, `0 0 * * *` -> {Hour:0, Minute:0}, `30 9 * * 1` -> {Weekday:1, Hour:9, Minute:30}
- Invalid cron -> error (not panic)
- Generated plist can be validated (round-trip through plist parsing)

### 2B. `lc-runner` -- Task Executor

**Source:** `specs.md` Section 5 (complete execution flow specified in 15 steps).

**Dependencies:** `lc-core`, `lc-config`, `lc-logger`, `tokio`, `clap`

This is a **standalone binary** (`lc-runner`) invoked by launchd. It has both `main.rs` and `lib.rs`:
- `lib.rs` -- shared logic: `build_command(task: &Task) -> Vec<String>` (extractable for dry-run), budget checking logic
- `main.rs` -- CLI entry point with the 15-step execution flow

**Execution flow (implement EXACTLY this order):**
1. Parse CLI args: `--task-id <id>`
2. Initialize tracing (to stderr, which goes to `.stderr.log` via launchd)
3. Load `LcPaths`, read task YAML via `ConfigManager`
4. Open SQLite DB via `Logger`
5. **Concurrency check** (CC-9): Acquire named POSIX semaphore `/loop-commander-concurrency`. If not acquired within 60s, log as `Skipped` ("Concurrency limit reached"), exit 0.
6. **Budget check**: query `Logger::total_cost_since` for today. If daily spend >= `daily_budget_cap`: log `Skipped` ("Daily budget cap reached"), emit `BudgetExceeded` event, exit 0.
7. Update task status to `Running` in YAML (atomic write, CC-1). Record `started_at`.
8. **Build command** (CC-2): use `tokio::process::Command::new()` with `.arg()` calls. NEVER use `sh -c`. If command starts with `claude`, parse into argv. Always append `--output-format json` for cost extraction.
9. Spawn process: `current_dir = task.working_dir` (expanded), env vars merged, stdout/stderr piped.
10. Await with `tokio::time::timeout(task.timeout_secs)`:
    - Timeout -> kill process, status = `Timeout`
    - Signal -> status = `Killed`
    - Exit 0 -> status = `Success`
    - Exit != 0 -> status = `Failed`
11. Capture stdout and stderr as strings
12. **Cost extraction**: parse stdout as JSON, look for cost/token fields. If parsing fails, use duration-based fallback (CC-10). Set `cost_is_estimate` accordingly.
13. Generate summary: first 200 chars of stdout, or stderr if stdout empty
14. Write `ExecutionLog` to SQLite
15. Update task status: `Active` if success, `Error` if failed (atomic write). Release semaphore.
16. If failure and notifications enabled, send macOS notification via `mac-notification-sys`
17. Exit with captured exit code

**Tests:** (specs.md Section 10, lc-runner)
- Integration: execute `echo hello`, verify log written to SQLite
- Budget check logic: mock logger returning high cost, verify task is skipped
- Timeout handling: spawn a `sleep 999` process with 1s timeout, verify killed
- `build_command` returns correct argv for various inputs

### Phase 2 Verification Gate

```bash
cargo build --workspace           # All 5 crates compile
cargo test -p lc-scheduler        # All scheduler tests pass
cargo test -p lc-runner            # All runner tests pass
cargo test --workspace             # Everything still passes
cargo clippy --workspace           # No warnings
# Manual: verify lc-runner binary exists at target/debug/lc-runner
```

---

## Phase 3: Daemon (Depends on Phases 1+2)

**Goal:** Build `lc-daemon`, the central service that everything else talks to.

### 3A. `lc-daemon` -- Background Service

**Source:** `specs.md` Section 7 (full behavior contract, JSON-RPC methods, event system).

**Dependencies:** `lc-core`, `lc-config`, `lc-scheduler`, `lc-logger`, `tokio`

**NOTE:** `lc-runner` is NOT a Cargo dependency. The daemon spawns `lc-runner` as a child process. It discovers the binary via `Scheduler::find_runner()`.

**Binary name:** `loop-commander` (not `lc-daemon`)

#### `src/main.rs` -- Startup Sequence
1. Parse CLI args (`--foreground` flag)
2. Initialize tracing with `tracing-subscriber` (JSON format, configurable via `RUST_LOG`)
3. `LcPaths::new().ensure_dirs()`
4. **Single-instance check** (CC-4): check PID file + socket, flock, etc.
5. Write PID file
6. Create `ConfigManager`, `Logger`, `Scheduler`
7. Sync tasks to launchd: for each `Active` task, ensure plist is registered + loaded
8. Remove stale socket file if present
9. Bind `UnixListener` at `~/.loop-commander/daemon.sock`
10. Create `broadcast::channel` for `DaemonEvent`
11. Spawn `health_check_loop` (60s interval)
12. Spawn `prune_loop` (3600s interval)
13. Event loop: accept connections, spawn `handle_connection` per client
14. On SIGTERM/SIGINT: remove PID file, remove socket, exit 0

#### `src/server.rs` -- JSON-RPC Dispatch

Implement ALL methods listed in `specs.md` Section 7:

**Task Management:**
- `task.list` -> returns `Vec<Task>`
- `task.get` -> returns `Task`
- `task.create` -> validate input (CC-3), create YAML, register plist, activate launchd, return `Task`
- `task.update` -> validate input, update YAML, reinstall plist if schedule changed, return `Task`
- `task.delete` -> check if running (R4), deactivate, unregister, delete YAML
- `task.pause` -> set status=Paused, deactivate launchd
- `task.resume` -> set status=Active, activate launchd
- `task.run_now` -> check concurrency semaphore (CC-9), spawn `lc-runner` directly. Return `{queued: bool}`.
- `task.dry_run` -> return `DryRunResult` (no side effects, no execution)
- `task.stop` -> kill running `lc-runner` process for this task

**Templates:**
- `templates.list` -> return `BUILTIN_TEMPLATES` (5 built-in templates)

**Logs & Metrics:**
- `logs.query` -> delegate to `Logger::query_logs`
- `metrics.dashboard` -> delegate to `Logger::get_dashboard_metrics`, include `cost_trend`
- `metrics.cost_trend` -> delegate to `Logger::get_cost_trend`

**Import/Export:**
- `task.export` -> convert Task to TaskExport, return it
- `task.import` -> validate TaskExport, assign new ID/timestamps, create task

**Event Subscription:**
- `events.subscribe` -> keep connection open, push newline-delimited JSON events using `tokio::sync::broadcast`. Event format is JSON-RPC notification (no `id` field).

**Config:**
- `config.get` -> return GlobalConfig
- `config.update` -> partial update of GlobalConfig

**Daemon:**
- `daemon.status` -> return `{pid, uptime, version, connected_clients, claude_available}`

#### `src/health.rs` -- Health Check Loop
Every 60s, for each active task:
- Check if launchd job is loaded via `scheduler.is_loaded()`
- If not loaded and status is Active: re-register + activate
- Log discrepancies, emit `HealthRepair` event

#### `src/events.rs` -- Event System
`DaemonEvent` enum (defined in `lc-core`, broadcast from daemon):
- `TaskStarted { task_id, task_name }`
- `TaskCompleted { task_id, task_name, duration_secs, cost_usd }`
- `TaskFailed { task_id, task_name, exit_code, summary }`
- `TaskStatusChanged { task_id, old_status, new_status }`
- `HealthRepair { task_id, action }`
- `BudgetExceeded { task_id, task_name, daily_spend, cap }`

**Concurrency model:**
- `Arc<Mutex<ConfigManager>>` -- config writes need serialization
- `Arc<Mutex<Logger>>` or open one connection per request (rusqlite Connection is not Send)
- `Arc<Scheduler>` -- scheduler operations need serialization for plist writes
- `tokio::sync::broadcast::Sender<DaemonEvent>` -- for event fan-out
- `tokio::sync::Semaphore` -- for concurrency limiting

**Also implement daemon self-install:**
- `lc daemon install` creates `~/Library/LaunchAgents/com.loopcommander.daemon.plist` with `KeepAlive: true`, `RunAtLoad: true`, then loads it. This makes the daemon survive reboots.

**Tests:** (specs.md Section 10, lc-daemon)
- JSON-RPC request parsing (valid and malformed)
- Response serialization
- Event broadcast (subscribe, trigger event, verify received)
- Integration: start daemon, send `task.list`, verify response
- Integration: subscribe to events, create a task, verify `TaskStatusChanged` event
- Templates list returns 5 templates
- Dry run returns correct DryRunResult
- Import/export round-trip

### Phase 3 Verification Gate

```bash
cargo build --workspace                    # All 6 crates compile
cargo test --workspace                     # All tests pass
cargo clippy --workspace                   # No warnings

# Manual integration test:
./target/debug/loop-commander --foreground &
sleep 2
# Verify socket exists:
ls -la ~/.loop-commander/daemon.sock
# Verify PID file:
cat ~/.loop-commander/daemon.pid
# Kill daemon:
kill $(cat ~/.loop-commander/daemon.pid)
```

---

## Phase 4: CLI (Depends on Phase 3)

**Goal:** Build `lc` CLI that talks to the daemon via JSON-RPC.

### 4A. `lc-cli` -- Command Line Interface

**Source:** `specs.md` Section 8 (full command reference).

**Dependencies:** `lc-core`, `tokio`, `serde_json`, `clap`, `chrono`

**Binary name:** `lc`

Implement all commands using clap derive macros:

```
lc list                                    # Table: ID, NAME, SCHEDULE, STATUS, RUNS, HEALTH
lc add --name "..." --command "..." --schedule "..." [--working-dir ...] [--budget ...] [--template <slug>]
lc edit <id> [--name ...] [--schedule ...]  # Inline flags OR $EDITOR
lc rm <id> [-y]                             # Confirm prompt (skip with -y)
lc pause <id>
lc resume <id>
lc run <id> [--dry-run] [--json]
lc stop <id>
lc logs [id] [--limit N] [--status success|failed] [--follow]
lc status                                   # Dashboard summary with text sparkline
lc export <id> [-o <file>]
lc import <file> [--dry-run]
lc daemon start|stop|status|install
lc config get|set <key> <value>
lc init                                     # First-run setup (R3)
```

**IPC client helper:**
```rust
async fn send_rpc(method: &str, params: serde_json::Value) -> Result<serde_json::Value> {
    // 1. Connect to Unix socket at LcPaths.socket_path
    // 2. Send JSON-RPC request + newline
    // 3. Read response line
    // 4. Parse JsonRpcResponse
    // 5. If error, map to user-friendly message based on error code
    // 6. Return result
}
```

If daemon is not running, print: `Error: Loop Commander daemon is not running. Start it with: lc daemon start`

**`lc status` output format:**
```
Loop Commander -- 5 tasks (3 active, 1 paused, 1 error)
Total runs: 351  |  Success: 97.2%  |  Spend: $35.56
7-day spend: ▂▅▇▃▁▄▆  $23.41
Daemon: PID 4821, uptime 3d 14h
```

**`lc init` command (R3):**
1. Create `~/.loop-commander/` directories
2. Write default `config.yaml`
3. Install daemon launchd plist
4. Print welcome message with example commands

**`--template` flag on `lc add`:**
Fetch templates via `templates.list`, look up by slug, merge with CLI overrides, send `task.create`.

**Tests:** (specs.md Section 10, lc-cli)
- CLI argument parsing for each subcommand
- `--template` resolves template and merges with overrides
- `--dry-run` sends correct RPC method
- `export`/`import` YAML serialization

### Phase 4 Verification Gate

```bash
cargo build --workspace                    # All 7 crates compile
cargo test --workspace                     # All tests pass

# Manual integration test:
./target/debug/loop-commander --foreground &
sleep 2
./target/debug/lc status
./target/debug/lc add --name "Test" --command "echo hello" --schedule "*/5 * * * *" --working-dir ~/
./target/debug/lc list
./target/debug/lc run <task-id> --dry-run
./target/debug/lc logs
./target/debug/lc rm <task-id> -y
kill $(cat ~/.loop-commander/daemon.pid)
```

---

## Phase 5: Swift macOS App (Can start with mock data during Phase 2)

**Goal:** Build the native SwiftUI macOS app that communicates with the daemon.

**Source documents:**
- `specs.md` Section 9 -- architecture, data models, view models, daemon dependency
- `SWIFTUI_DESIGN_REFERENCE.md` -- pixel-level design reference (30+ color tokens, 25+ font tokens, 12 component mappings, view architecture)
- `loop-commander.jsx` -- visual reference for interaction patterns

### Key Architecture Decisions
- SwiftUI with `NavigationSplitView` (three-column layout)
- `DaemonClient` is an `actor` for thread-safe socket access
- ViewModels use `@Observable` (macOS 14+) or `ObservableObject` (macOS 13 compat)
- Communication is EXCLUSIVELY via JSON-RPC over Unix socket. NO FFI, NO embedded Rust.
- Deployment target: macOS 13.0 (Ventura)
- Bundle identifier: `com.loopcommander.app`
- Default window: 1200x800, min 900x600

### 5A. Design System (build first)

Implement ALL design token files from `SWIFTUI_DESIGN_REFERENCE.md` Section 1:
- `Color+LoopCommander.swift` -- 30+ color tokens (Section 1.1). Include the hex initializer.
- `Font+LoopCommander.swift` -- 25+ font tokens (Section 1.2). Use SF Pro/SF Mono.
- `LCSpacing.swift` -- spacing scale from xxxs(3) to p32(32) (Section 1.3)
- `LCRadius.swift` -- badge(4), filter(5), button(6), card(8), panel(10), modal(12) (Section 1.4)
- `LCBorder.swift` -- standard(1), selected(2) (Section 1.5)
- `LCAnimations.swift` -- lcQuick(0.15s), lcFadeSlide(0.2s), lcPulse(1.0s repeat) (Section 1.7)
- `StatusConfig.swift` -- TaskStatusStyle enum mapping status to color/bg/label/sfSymbol (Section 1.8)
- `LCButtonStyles.swift` -- LCPrimaryButtonStyle, LCSecondaryButtonStyle (Section 2.8)

### 5B. Data Models

Mirror Rust `lc-core` types as Swift `Codable` structs (`SWIFTUI_DESIGN_REFERENCE.md` Section 3.3, `specs.md` Section 9):
- `LCTask` -- with camelCase JSON decoding (Rust uses snake_case)
- `TaskStatus` -- enum with `active, paused, error, disabled, running`
- `Schedule` -- tagged enum matching Rust's serde representation
- `ExecutionLog`
- `DashboardMetrics` (includes `costTrend: [DailyCost]`)
- `DailyCost`, `TaskTemplate`, `DryRunResult`, `TaskExport`
- `DaemonEvent` -- for event stream deserialization

**Gotcha:** Rust serializes with snake_case. Configure Swift `JSONDecoder` with `.keyDecodingStrategy = .convertFromSnakeCase`.

### 5C. Services Layer

**`DaemonClient.swift`** (specs.md Section 9, SWIFTUI_DESIGN_REFERENCE.md Section 3.4):
- `actor` for thread safety
- Unix socket connection via `NWConnection` (Network framework) or raw Foundation socket
- JSON-RPC 2.0 protocol: newline-delimited requests/responses
- Auto-reconnect with exponential backoff (1s, 2s, 4s, max 30s)
- 10s timeout per request
- Request ID correlation for concurrent calls
- `func call<T: Decodable>(_ method: String, params: any Encodable) async throws -> T`

**`EventStream.swift`**:
- Subscribes via `events.subscribe`
- Holds connection open, receives newline-delimited JSON events
- Auto-reconnect + re-subscribe on connection loss
- `@Published var lastEvent: DaemonEvent?`

**`DaemonMonitor.swift`**:
- Monitors connection health
- Provides `isConnected` state for UI indicators
- Triggers data refresh on reconnection

### 5D. ViewModels

Implement all view models from `specs.md` Section 9 and `SWIFTUI_DESIGN_REFERENCE.md` Section 3.4:

| ViewModel | JSON-RPC Methods Used | UI Trigger |
|---|---|---|
| `TaskListViewModel` | `task.list`, `task.create`, `task.delete`, `task.pause`, `task.resume` | On appear, on event |
| `TaskDetailViewModel` | `task.get`, `logs.query`, `task.run_now`, `task.dry_run`, `task.export` | Task selection |
| `LogsViewModel` | `logs.query` | On appear, filter/search change |
| `DashboardViewModel` | `metrics.dashboard` | On appear, 30s timer, on event |
| `MenuBarViewModel` | `daemon.status`, `metrics.dashboard` | Menu bar extra |

### 5E. Views

Build views referencing `SWIFTUI_DESIGN_REFERENCE.md` component mappings and `loop-commander.jsx` for visual reference:

**Core views (build in order):**
1. `ContentView.swift` -- `NavigationSplitView` shell (SWIFTUI_DESIGN_REFERENCE.md Section 3.1)
2. `SidebarView.swift` -- sidebar with Tasks/Logs + branding header (Section 3.2)
3. `StatusBadge.swift` -- status pill with SF Symbol + label (Section 2.1)
4. `MetricCard.swift` + `MetricsBarView.swift` -- responsive metric grid (Sections 2.2, 2.3)
5. `TaskRow.swift` + `TaskTableHeader.swift` -- task table (Sections 2.4, 2.5). 6-column grid layout matching JSX.
6. `TaskListView.swift` -- full task list with selection
7. `LogEntryRow.swift` + `LogTableHeader.swift` -- expandable log entries (Sections 2.6, 2.7)
8. `LogsView.swift` -- log viewer with search (`.searchable()`) and filter buttons (Section 2.11)
9. `TaskDetailView.swift` -- task info card + execution history + action toolbar (Section 2.10). Include Run Now, Dry Run, Edit, Pause/Resume, Delete buttons.
10. `TaskEditorView.swift` -- sheet modal with all form fields (Section 2.8). Include template picker for new tasks.
11. `SparklineChart.swift` -- 7-day cost trend using Swift Charts framework (Section 2.12)
12. `DaemonBanner.swift` -- "Daemon not running" banner with "Start Daemon" button (Section 4.11)
13. `MenuBarView.swift` -- menu bar extra with status + quick actions (Section 4.5)

**macOS enhancements (SWIFTUI_DESIGN_REFERENCE.md Section 4):**
- Keyboard shortcuts: Cmd+N (new), Cmd+R (run now), Cmd+E (edit), Cmd+P (pause/resume), Cmd+Delete (delete), Cmd+Shift+R (refresh), Cmd+1/2 (switch views)
- Commands menu with Task menu, View menu
- Menu bar extra (persistent status item)
- `.searchable()` for log search with Cmd+F
- Toolbar integration for detail view actions
- Drag and drop import (.yaml files)
- `UserNotifications` for task failure alerts

**Daemon dependency on launch:**
1. Attempt to connect to `~/.loop-commander/daemon.sock`
2. If fails, show `DaemonBanner` with "Start Daemon" button
3. "Start Daemon" spawns `loop-commander --foreground` via `Process`
4. Retry connection with exponential backoff (100ms, 200ms, 400ms, up to 5s)
5. Once connected, load all data and subscribe to events

**Accessibility (N7, SWIFTUI_DESIGN_REFERENCE.md Section 5):**
- All status indicators include text label + icon (not color alone)
- All interactive elements have `.accessibilityLabel()` and `.accessibilityHint()`
- Respect `@Environment(\.accessibilityReduceMotion)` for animations
- Arrow key navigation in task list
- VoiceOver: verify all custom views read correctly

### 5F. App Entry Point

`LoopCommanderApp.swift` (SWIFTUI_DESIGN_REFERENCE.md Section 4.3):
- `@main struct LoopCommanderApp: App`
- `WindowGroup` with `.defaultSize(width: 1200, height: 800)`, `.windowResizability(.contentMinSize)`
- `.preferredColorScheme(.dark)` as default
- `Commands` menus: replace New Item, add View menu, add Task menu
- `MenuBarExtra` with `MenuBarView`
- Register `loopcommander://` URL scheme for notification deep links

### Phase 5 Verification Gate

```bash
# Build Swift app
cd macos-app
xcodebuild -scheme LoopCommander -configuration Debug build

# Integration test:
# 1. Start daemon: ./target/debug/loop-commander --foreground &
# 2. Launch app from Xcode
# 3. Verify: app connects to daemon (green status indicator)
# 4. Verify: empty state shows "no tasks" placeholder
# 5. Create a task via CLI: ./target/debug/lc add --name "Test" --command "echo hello" --schedule "*/5 * * * *" --working-dir ~/
# 6. Verify: task appears in app's task list
# 7. Click task: detail view shows command, metadata, empty log history
# 8. Click "Run Now": verify execution log appears
# 9. Switch to Logs tab: verify log entry with expand/collapse
# 10. Open editor (Cmd+N): verify all form fields, template picker
# 11. Verify metrics bar shows correct counts
```

---

## CLAUDE.md Template

Create this file at the project root (`/Users/hitch/Desktop/git/loop-commander/CLAUDE.md`). Content is specified in `specs.md` Section 12 -- copy it verbatim, it contains the project overview, architecture summary, key constraints, testing instructions, and file locations that agents need as context.

---

## Cross-Cutting Concerns

### Error Handling Strategy
- **Library crates** (`lc-core`, `lc-config`, `lc-logger`, `lc-scheduler`): Use `LcError` from `lc-core`. Return `Result<T, LcError>`.
- **Binary crates** (`lc-daemon`, `lc-runner`, `lc-cli`): Use `anyhow::Result` at the main function boundary. Convert `LcError` to `anyhow` with context.
- **JSON-RPC responses**: Map `LcError` variants to error codes (CC-8). Include human-readable messages.
- **Swift app**: Display errors inline per-operation (not global error banners). Different UI for different error codes.

### Logging Strategy
- Use `tracing` crate throughout all Rust code
- `lc-daemon`: log to stderr (captured by launchd if running as agent) and optionally to `~/.loop-commander/daemon.log`
- `lc-runner`: log to stderr (goes to `~/.loop-commander/output/{id}.stderr.log` via launchd)
- Environment variable `RUST_LOG` controls verbosity (default: `info`)
- Structured JSON output when `--json` flag is used

### Testing Strategy
- Unit tests in each crate (specs.md Section 10 lists minimum coverage per crate)
- Integration tests that need launchd: gate with `#[cfg(not(ci))]`
- Swift tests in `macos-app/LoopCommanderTests/`:
  - JSON decoding round-trips for all model types
  - DaemonClient mock socket tests
  - ViewModel state transitions
  - EventStream reconnection behavior
- Use `tempdir` for tests that create files (avoid polluting `~/.loop-commander/`)

### Build & Run Commands

```bash
# Build all Rust crates
cargo build --release

# The three Rust binaries:
# target/release/loop-commander    (daemon)
# target/release/lc-runner          (task executor)
# target/release/lc                 (CLI)

# Run tests
cargo test --workspace

# Start daemon in foreground (for development)
./target/release/loop-commander --foreground

# CLI usage
./target/release/lc init              # First-run setup
./target/release/lc status            # Dashboard
./target/release/lc list              # List tasks
./target/release/lc add --name "PR Review" --command "claude -p 'Review open PRs'" --schedule "0 */2 * * *" --working-dir ~/projects/myrepo

# Build Swift app
cd macos-app
xcodebuild -scheme LoopCommander -configuration Debug build
# Or open in Xcode:
open LoopCommander.xcodeproj
```

---

## Summary Dependency Graph

```
Phase 1 (parallel):
  lc-core ─────────────────┐
  lc-config (needs core) ──┤
  lc-logger (needs core) ──┘

Phase 2 (parallel, after Phase 1):
  lc-scheduler (needs core, config)
  lc-runner (needs core, config, logger)

Phase 3 (after Phases 1+2):
  lc-daemon (needs core, config, scheduler, logger)

Phase 4 (after Phase 3):
  lc-cli (needs core)  [talks to daemon via socket]

Phase 5 (after Phase 3, can mock earlier):
  Swift macOS App  [talks to daemon via socket]
```

**Phase 4 and Phase 5 can proceed in parallel** once the daemon is functional.

---

## Final Checklist

Before declaring the project complete, verify:

- [ ] `cargo build --release --workspace` succeeds with no errors
- [ ] `cargo test --workspace` passes all tests
- [ ] `cargo clippy --workspace` produces no warnings
- [ ] Daemon starts, binds socket, writes PID file, accepts connections
- [ ] Daemon rejects second instance (CC-4)
- [ ] CLI can create, list, pause, resume, delete, run tasks
- [ ] `lc run <id> --dry-run` shows resolved command without executing
- [ ] `lc export <id>` and `lc import <file>` round-trip correctly
- [ ] lc-runner executes tasks, writes logs to SQLite, handles timeout
- [ ] lc-runner enforces concurrency limit via POSIX semaphore
- [ ] lc-runner enforces budget cap and logs Skipped status
- [ ] launchd plists are generated correctly for all schedule types
- [ ] Weekday range cron (`0 7 * * 1-5`) generates array of 5 CalendarInterval dicts
- [ ] Swift app connects to daemon, displays tasks, logs, metrics
- [ ] Swift app editor creates/edits tasks with validation
- [ ] Swift app receives real-time events (no polling for status updates)
- [ ] Swift app shows "Daemon not running" banner when disconnected
- [ ] Keyboard shortcuts work (Cmd+N, Cmd+R, Cmd+E, etc.)
- [ ] Menu bar extra shows daemon status
- [ ] All YAML writes use atomic temp+rename (CC-1)
- [ ] No shell injection possible in task execution (CC-2)
- [ ] SQLite uses WAL mode and busy_timeout (CC-5)
- [ ] Socket path is `~/.loop-commander/daemon.sock` (CC-6)
