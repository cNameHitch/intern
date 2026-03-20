# Loop Commander — Complete Implementation Spec

> **This is a one-shot build spec.** Implement everything described below in a single pass.
> No phases. No stubs. No TODOs. Every crate compiles, every test passes, the app launches.

---

## Project Identity

- **Name:** Loop Commander
- **Binary names:** `loop-commander` (daemon), `lc` (CLI), `Loop Commander.app` (native Swift macOS app)
- **Purpose:** Persistent, system-level macOS scheduler for Claude Code tasks with a native dashboard UI
- **Stack:** Rust (Cargo workspace) + Swift/SwiftUI (native macOS app) + SQLite
- **macOS scheduler:** launchd (user agents)
- **IPC:** Unix domain socket with JSON-RPC 2.0
- **Config format:** YAML (serde_yaml)
- **Log storage:** SQLite via rusqlite (WAL mode)
- **Minimum macOS:** 13.0 (Ventura)
- **Concurrency model:** The daemon is the SOLE writer to YAML config and SQLite. Both the Swift app and CLI communicate with the daemon exclusively via JSON-RPC over the Unix domain socket. This eliminates dual-writer concurrency issues entirely (see Section 14 for architectural rationale).

---

## 1. Workspace Root

```toml
# Cargo.toml
[workspace]
resolver = "2"
members = [
    "crates/lc-core",
    "crates/lc-config",
    "crates/lc-scheduler",
    "crates/lc-runner",
    "crates/lc-logger",
    "crates/lc-daemon",
    "crates/lc-cli",
]

[workspace.dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
serde_yaml = "0.9"
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1", features = ["v4"] }
thiserror = "2"
anyhow = "1"
tokio = { version = "1", features = ["full"] }
rusqlite = { version = "0.31", features = ["bundled"] }
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
dirs = "5"
clap = { version = "4", features = ["derive"] }
plist = "1"
```

Directory layout on disk:

```
loop-commander/
├── Cargo.toml
├── CLAUDE.md                          # Copy key instructions from this spec
├── crates/
│   ├── lc-core/
│   │   ├── Cargo.toml
│   │   └── src/lib.rs
│   ├── lc-config/
│   │   ├── Cargo.toml
│   │   └── src/lib.rs
│   ├── lc-scheduler/
│   │   ├── Cargo.toml
│   │   └── src/lib.rs
│   ├── lc-runner/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── main.rs
│   │       └── lib.rs
│   ├── lc-logger/
│   │   ├── Cargo.toml
│   │   └── src/lib.rs
│   ├── lc-daemon/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── main.rs
│   │       ├── server.rs
│   │       ├── health.rs
│   │       └── events.rs
│   └── lc-cli/
│       ├── Cargo.toml
│       └── src/main.rs
└── macos-app/                         # Native Swift/SwiftUI macOS app (Xcode project)
    ├── LoopCommander.xcodeproj/
    ├── LoopCommander/
    │   ├── LoopCommanderApp.swift
    │   ├── Models/
    │   │   ├── Task.swift
    │   │   ├── ExecutionLog.swift
    │   │   └── DashboardMetrics.swift
    │   ├── Services/
    │   │   ├── DaemonClient.swift        # JSON-RPC client over Unix socket
    │   │   ├── DaemonMonitor.swift        # Connection health + auto-reconnect
    │   │   └── EventStream.swift          # Real-time event subscription
    │   ├── ViewModels/
    │   │   ├── TaskListViewModel.swift
    │   │   ├── TaskDetailViewModel.swift
    │   │   ├── LogsViewModel.swift
    │   │   └── DashboardViewModel.swift
    │   ├── Views/
    │   │   ├── ContentView.swift
    │   │   ├── TaskListView.swift
    │   │   ├── TaskDetailView.swift
    │   │   ├── TaskEditorView.swift
    │   │   ├── LogsView.swift
    │   │   ├── MetricsBarView.swift
    │   │   ├── StatusBadge.swift
    │   │   └── SparklineChart.swift
    │   ├── Utilities/
    │   │   └── Formatters.swift
    │   └── Assets.xcassets/
    └── LoopCommanderTests/
```

---

## 2. `lc-core` — Domain Types

```toml
# crates/lc-core/Cargo.toml
[package]
name = "lc-core"
version = "0.1.0"
edition = "2021"

[dependencies]
serde = { workspace = true }
serde_json = { workspace = true }
chrono = { workspace = true }
uuid = { workspace = true }
thiserror = { workspace = true }
```

### `src/lib.rs` — Complete Types

```rust
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use thiserror::Error;

// ── Task ID ──────────────────────────────────────────────

/// Format: "lc-" + 8 hex chars (from UUID v4)
/// NOTE: UUID v4 hex gives 8 chars from a 32-hex-char space.
/// Collision risk: ~1 in 4 billion. Acceptable for single-user local scheduler.
/// However, the first 8 chars of a UUID are time-influenced in some impls —
/// using &id[..8] after removing hyphens is fine for v4 which is fully random.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct TaskId(pub String);

impl TaskId {
    pub fn new() -> Self {
        let id = uuid::Uuid::new_v4().simple().to_string();
        Self(format!("lc-{}", &id[..8]))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }

    /// launchd label: com.loopcommander.task.lc-xxxxxxxx
    pub fn launchd_label(&self) -> String {
        format!("com.loopcommander.task.{}", self.0)
    }
}

impl std::fmt::Display for TaskId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

// ── Schedule ─────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Schedule {
    /// Standard 5-field cron: "*/15 * * * *"
    Cron { expression: String },
    /// launchd StartInterval (seconds)
    Interval { seconds: u64 },
    /// launchd StartCalendarInterval
    Calendar {
        minute: Option<u8>,
        hour: Option<u8>,
        day: Option<u8>,
        weekday: Option<u8>,
        month: Option<u8>,
    },
}

impl Schedule {
    /// Human-readable description for display
    pub fn to_human(&self) -> String {
        match self {
            Schedule::Cron { expression } => format!("Cron: {}", expression),
            Schedule::Interval { seconds } => {
                if *seconds < 60 {
                    format!("Every {}s", seconds)
                } else if *seconds < 3600 {
                    format!("Every {}m", seconds / 60)
                } else {
                    format!("Every {}h", seconds / 3600)
                }
            }
            Schedule::Calendar { minute, hour, weekday, .. } => {
                let time = match (hour, minute) {
                    (Some(h), Some(m)) => format!("{:02}:{:02}", h, m),
                    (Some(h), None) => format!("{:02}:00", h),
                    _ => "every interval".to_string(),
                };
                match weekday {
                    Some(d) => {
                        let day_name = match d {
                            0 | 7 => "Sun", 1 => "Mon", 2 => "Tue", 3 => "Wed",
                            4 => "Thu", 5 => "Fri", 6 => "Sat", _ => "?",
                        };
                        format!("{}s at {}", day_name, time)
                    }
                    None => format!("Daily at {}", time),
                }
            }
        }
    }
}

// ── Task Status ──────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TaskStatus {
    Active,
    Paused,
    Error,
    Disabled,
}

impl std::fmt::Display for TaskStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            TaskStatus::Active => write!(f, "active"),
            TaskStatus::Paused => write!(f, "paused"),
            TaskStatus::Error => write!(f, "error"),
            TaskStatus::Disabled => write!(f, "disabled"),
        }
    }
}

// ── Task ─────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub id: TaskId,
    pub name: String,
    pub command: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub skill: Option<String>,
    pub schedule: Schedule,
    pub schedule_human: String,
    pub working_dir: PathBuf,
    #[serde(default)]
    pub env_vars: HashMap<String, String>,
    #[serde(default = "default_budget")]
    pub max_budget_per_run: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_turns: Option<u32>,
    #[serde(default = "default_timeout")]
    pub timeout_secs: u64,
    pub status: TaskStatus,
    #[serde(default)]
    pub tags: Vec<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

fn default_budget() -> f64 { 5.0 }
fn default_timeout() -> u64 { 600 }

// ── Execution Log ────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExecStatus {
    Success,
    Failed,
    Timeout,
    Killed,
    Skipped,
}

impl std::fmt::Display for ExecStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ExecStatus::Success => write!(f, "success"),
            ExecStatus::Failed => write!(f, "failed"),
            ExecStatus::Timeout => write!(f, "timeout"),
            ExecStatus::Killed => write!(f, "killed"),
            ExecStatus::Skipped => write!(f, "skipped"),
        }
    }
}

impl std::str::FromStr for ExecStatus {
    type Err = LcError;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "success" => Ok(ExecStatus::Success),
            "failed" => Ok(ExecStatus::Failed),
            "timeout" => Ok(ExecStatus::Timeout),
            "killed" => Ok(ExecStatus::Killed),
            "skipped" => Ok(ExecStatus::Skipped),
            _ => Err(LcError::InvalidStatus(s.to_string())),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionLog {
    pub id: i64,
    pub task_id: String,
    pub task_name: String,
    pub started_at: DateTime<Utc>,
    pub finished_at: DateTime<Utc>,
    pub duration_secs: u64,
    pub exit_code: i32,
    pub status: ExecStatus,
    pub stdout: String,
    pub stderr: String,
    pub tokens_used: Option<u64>,
    pub cost_usd: Option<f64>,
    pub summary: String,
}

// ── Dashboard Metrics ────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskMetrics {
    pub task_id: String,
    pub total_runs: u64,
    pub success_count: u64,
    pub fail_count: u64,
    pub total_cost: f64,
    pub total_tokens: u64,
    pub avg_duration_secs: f64,
    pub last_run: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DashboardMetrics {
    pub total_tasks: u64,
    pub active_tasks: u64,
    pub total_runs: u64,
    pub overall_success_rate: f64,
    pub total_spend: f64,
    pub tasks: Vec<TaskMetrics>,
}

// ── IPC Messages ─────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcRequest {
    pub jsonrpc: String,
    pub method: String,
    #[serde(default)]
    pub params: serde_json::Value,
    pub id: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcResponse {
    pub jsonrpc: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<JsonRpcError>,
    pub id: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcError {
    pub code: i32,
    pub message: String,
}

impl JsonRpcResponse {
    pub fn success(id: serde_json::Value, result: serde_json::Value) -> Self {
        Self { jsonrpc: "2.0".into(), result: Some(result), error: None, id }
    }
    pub fn error(id: serde_json::Value, code: i32, message: String) -> Self {
        Self { jsonrpc: "2.0".into(), result: None, error: Some(JsonRpcError { code, message }), id }
    }
}

// ── Create/Update DTOs ───────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateTaskInput {
    pub name: String,
    pub command: String,
    pub skill: Option<String>,
    pub schedule: Schedule,
    pub schedule_human: Option<String>,
    pub working_dir: String,
    pub env_vars: Option<HashMap<String, String>>,
    pub max_budget_per_run: Option<f64>,
    pub max_turns: Option<u32>,
    pub timeout_secs: Option<u64>,
    pub tags: Option<Vec<String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateTaskInput {
    pub id: String,
    pub name: Option<String>,
    pub command: Option<String>,
    pub skill: Option<String>,
    pub schedule: Option<Schedule>,
    pub schedule_human: Option<String>,
    pub working_dir: Option<String>,
    pub env_vars: Option<HashMap<String, String>>,
    pub max_budget_per_run: Option<f64>,
    pub max_turns: Option<u32>,
    pub timeout_secs: Option<u64>,
    pub tags: Option<Vec<String>>,
    pub status: Option<TaskStatus>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogQuery {
    pub task_id: Option<String>,
    pub status: Option<String>,
    pub limit: Option<u32>,
    pub offset: Option<u32>,
    pub search: Option<String>,
}

// ── Errors ───────────────────────────────────────────────

#[derive(Debug, Error)]
pub enum LcError {
    #[error("Task not found: {0}")]
    TaskNotFound(String),

    #[error("Config error: {0}")]
    Config(String),

    #[error("Scheduler error: {0}")]
    Scheduler(String),

    #[error("Runner error: {0}")]
    Runner(String),

    #[error("Database error: {0}")]
    Database(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("YAML error: {0}")]
    Yaml(String),

    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("Invalid status: {0}")]
    InvalidStatus(String),

    #[error("Budget exceeded: task {task_id} spent ${spent:.2}, limit ${limit:.2}")]
    BudgetExceeded { task_id: String, spent: f64, limit: f64 },

    #[error("Daemon not running")]
    DaemonNotRunning,

    #[error("IPC error: {0}")]
    Ipc(String),
}

// ── Paths ────────────────────────────────────────────────

/// All data lives under ~/.loop-commander/
pub struct LcPaths {
    pub root: PathBuf,
    pub config_file: PathBuf,
    pub tasks_dir: PathBuf,
    pub plists_dir: PathBuf,
    pub output_dir: PathBuf,
    pub db_file: PathBuf,
    pub socket_path: PathBuf,
    pub pid_file: PathBuf,
    pub launch_agents_dir: PathBuf,
}

impl LcPaths {
    pub fn new() -> Self {
        let home = dirs::home_dir().expect("No home directory");
        let root = home.join(".loop-commander");
        Self {
            config_file: root.join("config.yaml"),
            tasks_dir: root.join("tasks"),
            plists_dir: root.join("plists"),
            output_dir: root.join("output"),
            db_file: root.join("logs.db"),
            // SECURITY: Using /tmp is vulnerable to symlink attacks and other users
            // on shared machines. Use a user-scoped path under the data dir instead.
            // The /tmp path is kept as a fallback only if the XDG_RUNTIME_DIR approach fails.
            socket_path: root.join("daemon.sock"),
            pid_file: root.join("daemon.pid"),
            launch_agents_dir: home.join("Library/LaunchAgents"),
            root,
        }
    }

    /// Create all directories if they don't exist
    pub fn ensure_dirs(&self) -> std::io::Result<()> {
        std::fs::create_dir_all(&self.root)?;
        std::fs::create_dir_all(&self.tasks_dir)?;
        std::fs::create_dir_all(&self.plists_dir)?;
        std::fs::create_dir_all(&self.output_dir)?;
        Ok(())
    }
}

impl Default for LcPaths {
    fn default() -> Self {
        Self::new()
    }
}
```

### Additional Types (added for N1-N5 features)

The following types are also defined in `lc-core` to support features N1-N5. See the
respective feature sections (14.3) for full definitions and field documentation.

- `TaskTemplate` — Built-in task template with slug, name, description, schedule, etc. (N1)
- `BUILTIN_TEMPLATES` — Static array of 5 built-in templates (N1)
- `DailyCost` — Per-day cost aggregate: date, total_cost, run_count (N2)
- `DryRunResult` — Resolved command, env vars, budget info for dry-run preview (N5)
- `TaskExport` — Portable task definition for import/export, omitting runtime fields (N4)
- `DaemonEvent` — Event enum for real-time push to subscribed clients (defined in `lc-daemon/src/events.rs`, but the serialization types live in `lc-core` so CLI can deserialize events too)

---

## 3. `lc-config` — Configuration Layer

```toml
# crates/lc-config/Cargo.toml
[package]
name = "lc-config"
version = "0.1.0"
edition = "2021"

[dependencies]
lc-core = { path = "../lc-core" }
serde = { workspace = true }
serde_yaml = { workspace = true }
serde_json = { workspace = true }
chrono = { workspace = true }
anyhow = { workspace = true }
tracing = { workspace = true }
dirs = { workspace = true }
```

### Behavior Contract

```rust
/// Global config file: ~/.loop-commander/config.yaml
/// Per-task files: ~/.loop-commander/tasks/{task-id}.yaml
///
/// ConfigManager handles:
/// 1. Loading/saving global config with defaults
/// 2. CRUD for task YAML files  
/// 3. Expanding ~ in paths to absolute
/// 4. Watching tasks/ dir for external edits (optional, via notify crate)

pub struct GlobalConfig {
    pub version: u32,               // Always 1
    pub claude_binary: String,      // Default: "claude"
    pub default_budget: f64,        // Default: 5.0
    pub default_timeout: u64,       // Default: 600
    pub default_max_turns: u32,     // Default: 50
    pub log_retention_days: u32,    // Default: 90
    pub notifications_enabled: bool, // Default: true
}

pub struct ConfigManager {
    paths: LcPaths,
    global: GlobalConfig,
}

impl ConfigManager {
    /// Load or create default global config
    pub fn new(paths: LcPaths) -> Result<Self>;

    /// List all task YAML files and deserialize
    pub fn list_tasks(&self) -> Result<Vec<Task>>;

    /// Read a single task by ID
    pub fn get_task(&self, id: &str) -> Result<Task>;

    /// Write a task YAML file. Creates if new, overwrites if exists.
    /// Sets updated_at to now. If created_at is None, sets it too.
    pub fn save_task(&self, task: &Task) -> Result<()>;

    /// Delete task YAML file
    pub fn delete_task(&self, id: &str) -> Result<()>;

    /// Apply CreateTaskInput → Task with defaults filled in
    pub fn create_task_from_input(&self, input: CreateTaskInput) -> Task;

    /// Apply UpdateTaskInput to existing Task (partial update)
    pub fn apply_update(&self, task: &mut Task, update: UpdateTaskInput);

    /// Expand ~ to home dir in a path string
    pub fn expand_path(path: &str) -> PathBuf;
}
```

**IMPORTANT:** When serializing task YAML, use block scalar style for the `command` field so multiline prompts are readable. The YAML should look like:

```yaml
command: >-
  claude -p 'Review all open PRs in this repo.
  Check for logic errors, missing tests, and style violations.'
```

---

## 4. `lc-scheduler` — launchd Integration

```toml
# crates/lc-scheduler/Cargo.toml
[package]
name = "lc-scheduler"
version = "0.1.0"
edition = "2021"

[dependencies]
lc-core = { path = "../lc-core" }
lc-config = { path = "../lc-config" }
plist = { workspace = true }
anyhow = { workspace = true }
tracing = { workspace = true }
```

### Behavior Contract

```rust
/// Scheduler manages launchd plists for tasks.
///
/// Each active task gets:
///   ~/.loop-commander/plists/com.loopcommander.task.{id}.plist
///   symlinked to ~/Library/LaunchAgents/com.loopcommander.task.{id}.plist
///
/// Plist structure:
/// - Label: com.loopcommander.task.{id}
/// - ProgramArguments: [path_to_lc_runner, "--task-id", "{id}"]
/// - Schedule: StartInterval OR StartCalendarInterval (derived from Task.schedule)
/// - WorkingDirectory: task.working_dir (expanded)
/// - StandardOutPath: ~/.loop-commander/output/{id}.stdout.log
/// - StandardErrorPath: ~/.loop-commander/output/{id}.stderr.log
/// - EnvironmentVariables: merged from task config
/// - RunAtLoad: false
/// - KeepAlive: false
///
/// For Cron schedule type: parse the 5-field expression and convert to
/// StartCalendarInterval. If the cron is a simple interval (*/N pattern),
/// convert to StartInterval instead. Complex cron expressions that can't
/// map to a single CalendarInterval should use the closest approximation
/// and log a warning.

pub struct Scheduler {
    paths: LcPaths,
    runner_path: PathBuf,  // Discovered or configured path to lc-runner binary
}

impl Scheduler {
    pub fn new(paths: LcPaths) -> Result<Self>;

    /// Find the lc-runner binary. Checks:
    /// 1. Same directory as current executable
    /// 2. ~/.cargo/bin/lc-runner
    /// 3. /usr/local/bin/lc-runner
    /// 4. `which lc-runner`
    pub fn find_runner(&self) -> Result<PathBuf>;

    /// Generate plist XML, write to plists_dir, symlink to LaunchAgents
    pub fn register(&self, task: &Task) -> Result<()>;

    /// Load the launchd job. Use `launchctl bootstrap gui/<uid> <plist_path>` on
    /// macOS 13+. Fall back to `launchctl load -w <plist_path>` if bootstrap fails.
    /// NOTE: `launchctl load` is deprecated since macOS 10.10 but still works.
    /// The modern API is `launchctl bootstrap gui/$(id -u) <plist_path>`.
    pub fn activate(&self, task: &Task) -> Result<()>;

    /// Unload the launchd job. Use `launchctl bootout gui/<uid>/<label>`.
    /// Fall back to `launchctl unload <plist_path>`.
    /// Keeps plist on disk.
    pub fn deactivate(&self, task_id: &str) -> Result<()>;

    /// Remove plist file + symlink
    pub fn unregister(&self, task_id: &str) -> Result<()>;

    /// Register + activate in one call
    pub fn install(&self, task: &Task) -> Result<()>;

    /// Deactivate + unregister in one call
    pub fn uninstall(&self, task_id: &str) -> Result<()>;

    /// Deactivate, re-register, re-activate (for schedule/config changes)
    pub fn reinstall(&self, task: &Task) -> Result<()>;

    /// Check if a task's launchd job is loaded.
    /// Uses: `launchctl print gui/<uid>/<label>` (exit 0 = loaded).
    /// Fallback: `launchctl list <label>` (exit 0 = loaded).
    /// Avoid `launchctl list | grep` as it is fragile and slow.
    pub fn is_loaded(&self, task_id: &str) -> Result<bool>;

    /// Convert Schedule enum to plist key/value pairs
    fn schedule_to_plist(&self, schedule: &Schedule) -> plist::Dictionary;

    /// Parse cron expression to Calendar or Interval
    fn cron_to_launchd(&self, cron: &str) -> Schedule;
}
```

### Cron → launchd Conversion Rules

```
*/N * * * *       → StartInterval: N*60
0 */N * * *       → StartInterval: N*3600
0 H * * *         → StartCalendarInterval: {Hour: H, Minute: 0}
M H * * *         → StartCalendarInterval: {Hour: H, Minute: M}
M H * * D         → StartCalendarInterval: {Weekday: D, Hour: H, Minute: M}
M H * * D1-D2     → ARRAY of StartCalendarInterval, one per weekday in range
                    (launchd supports an array of CalendarInterval dicts)
M H D * *         → StartCalendarInterval: {Day: D, Hour: H, Minute: M}
M H * MO *        → StartCalendarInterval: {Month: MO, Hour: H, Minute: M}
Everything else   → Best-effort StartCalendarInterval, log warning
```

**NOTE:** launchd's `StartCalendarInterval` key accepts either a single dict or an array of dicts. For cron patterns with weekday ranges (e.g., `1-5` = Mon-Fri), generate one dict per weekday in the range. This is common and the spec's test case `0 7 * * 1-5` requires this.

---

## 5. `lc-runner` — Task Executor

```toml
# crates/lc-runner/Cargo.toml
[package]
name = "lc-runner"
version = "0.1.0"
edition = "2021"

[[bin]]
name = "lc-runner"
path = "src/main.rs"

[dependencies]
lc-core = { path = "../lc-core" }
lc-config = { path = "../lc-config" }
lc-logger = { path = "../lc-logger" }
tokio = { workspace = true }
serde_json = { workspace = true }
chrono = { workspace = true }
anyhow = { workspace = true }
tracing = { workspace = true }
tracing-subscriber = { workspace = true }
clap = { workspace = true }
```

### Behavior Contract

```rust
/// lc-runner is invoked by launchd for each task execution.
/// It is a standalone binary with its own main().
///
/// Usage: lc-runner --task-id <id>
///
/// Execution flow (this is the EXACT order of operations):
///
/// 1. Parse CLI args (--task-id)
/// 2. Initialize tracing (to stderr, which goes to .stderr.log via launchd)
/// 3. Load LcPaths, read task YAML via ConfigManager
/// 4. Open SQLite DB via Logger
/// 5. Budget check: query Logger for total cost of this task in current day
///    - If daily spend >= max_budget_per_run * 20 (safety cap): log Skipped, exit 0
/// 6. Record started_at = Utc::now()
/// 7. Build the command:
///    - If task.command starts with "claude": use it directly
///    - Otherwise: wrap as `claude -p '<command>' --output-format json`
///    - Append --max-turns if set
/// 8. Spawn via tokio::process::Command:
///    - current_dir = task.working_dir (expanded)
///    - env vars from task config merged with inherited env
///    - stdout = piped, stderr = piped
/// 9. Await completion with tokio::time::timeout(task.timeout_secs)
///    - On timeout: kill process, status = Timeout
///    - On signal: status = Killed
///    - On exit 0: status = Success
///    - On exit != 0: status = Failed
/// 10. Capture stdout and stderr as strings
/// 11. Attempt to parse stdout as JSON for token/cost extraction:
///     - Look for "usage" or "tokens" or "cost" fields
///     - This is best-effort; if claude isn't in JSON mode, skip
/// 12. Generate summary: first 200 chars of stdout, or stderr if stdout empty
/// 13. Write ExecutionLog to SQLite
/// 14. If status != Success: attempt to update task YAML status to Error
///     (best-effort, don't fail if config write fails)
/// 15. Exit with the captured exit code

#[derive(clap::Parser)]
struct Args {
    #[arg(long)]
    task_id: String,
}
```

---

## 6. `lc-logger` — SQLite Persistence

```toml
# crates/lc-logger/Cargo.toml
[package]
name = "lc-logger"
version = "0.1.0"
edition = "2021"

[dependencies]
lc-core = { path = "../lc-core" }
rusqlite = { workspace = true }
chrono = { workspace = true }
serde = { workspace = true }
serde_json = { workspace = true }
anyhow = { workspace = true }
tracing = { workspace = true }
```

### Behavior Contract

```rust
/// Logger manages the SQLite database at ~/.loop-commander/logs.db
///
/// Uses WAL mode for concurrent reads.
/// The daemon is the primary writer (via lc-runner which opens its own connection).
/// The Swift app and CLI are readers (via JSON-RPC queries to the daemon).

pub struct Logger {
    conn: rusqlite::Connection,
}

impl Logger {
    /// Open or create DB, run migrations, enable WAL, set busy_timeout(5000)
    pub fn new(db_path: &Path) -> Result<Self>;

    /// Create tables if not exist (idempotent)
    fn migrate(&self) -> Result<()>;

    /// Insert a new execution log row. Returns the auto-generated ID.
    pub fn insert_log(&self, log: &ExecutionLog) -> Result<i64>;

    /// Query logs with optional filters
    pub fn query_logs(&self, query: &LogQuery) -> Result<Vec<ExecutionLog>>;

    /// Get aggregate metrics for the dashboard
    pub fn get_dashboard_metrics(&self, tasks: &[Task]) -> Result<DashboardMetrics>;

    /// Get per-task metrics
    pub fn get_task_metrics(&self, task_id: &str) -> Result<TaskMetrics>;

    /// Total cost for a task since a given datetime
    pub fn total_cost_since(&self, task_id: &str, since: DateTime<Utc>) -> Result<f64>;

    /// Delete logs older than N days
    pub fn prune_logs(&self, retention_days: u32) -> Result<u64>;

    /// Count total log entries
    pub fn count_logs(&self) -> Result<u64>;
}
```

### SQL Schema (run in migrate())

```sql
CREATE TABLE IF NOT EXISTS execution_logs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id         TEXT NOT NULL,
    task_name       TEXT NOT NULL,
    started_at      TEXT NOT NULL,
    finished_at     TEXT NOT NULL,
    duration_secs   INTEGER NOT NULL,
    exit_code       INTEGER NOT NULL,
    status          TEXT NOT NULL,
    stdout          TEXT NOT NULL DEFAULT '',
    stderr          TEXT NOT NULL DEFAULT '',
    tokens_used     INTEGER,
    cost_usd        REAL,
    summary         TEXT NOT NULL DEFAULT '',
    created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_logs_task_id ON execution_logs(task_id);
CREATE INDEX IF NOT EXISTS idx_logs_started ON execution_logs(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_logs_status ON execution_logs(status);
```

---

## 7. `lc-daemon` — Background Service

```toml
# crates/lc-daemon/Cargo.toml
[package]
name = "lc-daemon"
version = "0.1.0"
edition = "2021"

[[bin]]
name = "loop-commander"
path = "src/main.rs"

[dependencies]
lc-core = { path = "../lc-core" }
lc-config = { path = "../lc-config" }
lc-scheduler = { path = "../lc-scheduler" }
# NOTE: lc-runner is NOT a dependency. The daemon spawns lc-runner as a child
# process (or launchd does). The daemon only needs lc-runner's binary path,
# which it discovers via Scheduler::find_runner().
lc-logger = { path = "../lc-logger" }
tokio = { workspace = true }
serde = { workspace = true }
serde_json = { workspace = true }
chrono = { workspace = true }
anyhow = { workspace = true }
tracing = { workspace = true }
tracing-subscriber = { workspace = true }
```

### Behavior Contract

```rust
/// The daemon is the SOLE API server for Loop Commander. Both the Swift
/// macOS app and the CLI communicate with the daemon exclusively via
/// JSON-RPC 2.0 over a Unix domain socket. This single-writer architecture
/// eliminates the dual-writer concurrency problem that existed when Tauri
/// talked directly to crates.
///
/// The daemon is a long-running process that:
/// 1. Listens on a Unix domain socket for JSON-RPC requests
/// 2. Manages task lifecycle (create/update/delete → config + scheduler)
/// 3. Runs a health check loop every 60s
/// 4. Runs log pruning once per hour
/// 5. Pushes real-time events to subscribed clients (Swift app, etc.)
///
/// It writes its PID to ~/.loop-commander/daemon.pid on startup
/// and removes it on clean shutdown.
///
/// STARTUP SEQUENCE:
/// 1. Parse CLI args (--foreground flag skips daemonization)
/// 2. Initialize tracing
/// 3. Ensure all directories exist
/// 4. Write PID file
/// 5. Open SQLite via Logger
/// 6. Load all tasks via ConfigManager
/// 7. For each Active task: ensure launchd plist is registered + loaded
/// 8. Bind Unix socket
/// 9. Enter event loop (tokio select over socket accept + timers)
///
/// JSON-RPC METHODS (handle in server.rs):
///
/// ── Task Management ──
/// "task.list"       → params: {}                → Vec<Task>
/// "task.get"        → params: {id}              → Task
/// "task.create"     → params: CreateTaskInput   → Task
///   (Creates YAML, registers plist, activates launchd)
/// "task.update"     → params: UpdateTaskInput   → Task
///   (Updates YAML, reinstalls plist if schedule changed)
/// "task.delete"     → params: {id}              → ()
///   (Deactivates, unregisters, deletes YAML)
/// "task.pause"      → params: {id}              → Task
///   (Sets status=Paused, deactivates launchd)
/// "task.resume"     → params: {id}              → Task
///   (Sets status=Active, activates launchd)
/// "task.run_now"    → params: {id}              → ()
///   (Spawns lc-runner directly, not via launchd)
/// "task.dry_run"    → params: {id}              → DryRunResult
///   (Returns resolved command, env, budget info without executing — see N5)
/// "task.stop"       → params: {id}              → ()
///   (Kills a currently-running lc-runner process for this task)
///
/// ── Templates (N1) ──
/// "templates.list"  → params: {}                → Vec<TaskTemplate>
///   (Returns all built-in task templates)
///
/// ── Logs & Metrics ──
/// "logs.query"      → params: LogQuery          → Vec<ExecutionLog>
/// "metrics.dashboard" → params: {}              → DashboardMetrics
///   (Now includes cost_trend: Vec<DailyCost> for the last 7 days — see N2)
/// "metrics.cost_trend" → params: {days?: u32}   → Vec<DailyCost>
///   (Standalone cost trend query, defaults to 7 days — see N2)
///
/// ── Import/Export (N4) ──
/// "task.export"     → params: {id}              → TaskExport
///   (Returns a portable task definition without runtime fields)
/// "task.import"     → params: TaskExport        → Task
///   (Validates, assigns new ID/timestamps, creates task)
///
/// ── Event Subscription ──
/// "events.subscribe" → params: {types?: Vec<String>} → (streaming)
///   (Keeps connection open, pushes newline-delimited JSON events.
///    Event types: "task.started", "task.completed", "task.failed",
///    "task.status_changed", "health.repair", "budget.exceeded".
///    If types is empty/omitted, subscribes to all events.
///    The Swift app uses this for real-time UI updates.)
///
/// ── Config ──
/// "config.get"      → params: {}                → GlobalConfig
///   (Returns the current global configuration)
/// "config.update"   → params: Partial<GlobalConfig> → GlobalConfig
///   (Updates global config fields, returns the updated config)
///
/// ── Daemon ──
/// "daemon.status"   → params: {}                → {pid, uptime, version, connected_clients}
///
/// HEALTH CHECK (health.rs):
/// Every 60s, for each active task:
///   - Check if launchd job is loaded (scheduler.is_loaded)
///   - If not loaded and status is Active: re-register + activate
///   - Log any discrepancies
///   - Emit "health.repair" event to subscribed clients if a repair occurred
///
/// GRACEFUL SHUTDOWN:
/// On SIGTERM/SIGINT: remove PID file, remove socket, exit 0
```

### `src/main.rs` structure:

```rust
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // 1. Init tracing
    // 2. Parse args (--foreground)
    // 3. LcPaths::new().ensure_dirs()
    // 4. Write PID
    // 5. Create ConfigManager, Logger, Scheduler
    // 6. Sync tasks to launchd (register any active tasks missing plists)
    // 7. Remove socket if stale
    // 8. Bind UnixListener
    // 9. Spawn health_check_loop (60s interval)
    // 10. Spawn prune_loop (3600s interval)
    // 11. Loop: accept connections, spawn handle_connection for each
    // 12. On ctrl+c: cleanup + exit
}
```

### `src/server.rs` — connection handler:

```rust
/// Read newline-delimited JSON-RPC from the socket.
/// Each line is one request. Parse, dispatch to handler, write response + newline.
/// Keep connection open until client disconnects.
///
/// For "events.subscribe" requests, the connection transitions to push mode:
/// the server holds the connection open and writes newline-delimited JSON
/// event objects as they occur. The client can still send requests on the
/// same connection (multiplexed). Events use JSON-RPC notification format
/// (no "id" field):
///   {"jsonrpc": "2.0", "method": "event", "params": {"type": "task.completed", "data": {...}}}
///
/// The daemon maintains a broadcast channel (tokio::sync::broadcast) for events.
/// When lc-runner completes, the daemon detects it (via the runner sending a
/// notification to the socket, or via file system watching on the output dir)
/// and broadcasts the event to all subscribers.
pub async fn handle_connection(
    stream: UnixStream,
    config: Arc<Mutex<ConfigManager>>,
    logger: Arc<Logger>,
    scheduler: Arc<Scheduler>,
    event_tx: broadcast::Sender<DaemonEvent>,
) -> Result<()>;
```

### `src/events.rs` — event types:

```rust
/// Events that can be pushed to subscribed clients (Swift app, etc.)
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
pub enum DaemonEvent {
    /// A task execution started (lc-runner spawned)
    TaskStarted { task_id: String, task_name: String },
    /// A task execution completed successfully
    TaskCompleted { task_id: String, task_name: String, duration_secs: u64, cost_usd: Option<f64> },
    /// A task execution failed
    TaskFailed { task_id: String, task_name: String, exit_code: i32, summary: String },
    /// A task's status changed (paused, resumed, error, etc.)
    TaskStatusChanged { task_id: String, old_status: String, new_status: String },
    /// Health check repaired a launchd discrepancy
    HealthRepair { task_id: String, action: String },
    /// A task was skipped due to budget cap
    BudgetExceeded { task_id: String, task_name: String, daily_spend: f64, cap: f64 },
}
```

---

## 8. `lc-cli` — Command Line Interface

```toml
# crates/lc-cli/Cargo.toml
[package]
name = "lc-cli"
version = "0.1.0"
edition = "2021"

[[bin]]
name = "lc"
path = "src/main.rs"

[dependencies]
lc-core = { path = "../lc-core" }
tokio = { workspace = true }
serde_json = { workspace = true }
clap = { workspace = true }
anyhow = { workspace = true }
chrono = { workspace = true }
```

### Behavior Contract

```rust
/// CLI communicates with the daemon via Unix socket JSON-RPC.
/// If daemon is not running, prints helpful error and suggests `lc daemon start`.
///
/// COMMANDS:
///
/// lc list
///   → Send task.list, display as table:
///     ID           NAME              SCHEDULE          STATUS   RUNS   HEALTH
///     lc-a1b2c3d4  PR Review Sweep   Every 2 hours     active   42     95%
///
/// lc add --name "..." --command "..." --schedule "*/15 * * * *" [--working-dir ...] [--budget ...]
///   → Send task.create
///   → Print: Created task lc-xxxxxxxx "Name" (active, next run in ~15m)
///
/// lc edit <id>
///   → Read task YAML from config dir, open in $EDITOR
///   → On save: send task.update with full task
///   → Alternatively: accept inline flags like --schedule, --command
///
/// lc rm <id>
///   → Confirm prompt (skip with -y)
///   → Send task.delete
///
/// lc pause <id>
///   → Send task.pause
///
/// lc resume <id>
///   → Send task.resume
///
/// lc run <id>
///   → Send task.run_now
///   → Print: Triggered immediate run of "Name"
///
/// lc logs [id] [--limit N] [--status success|failed] [--follow]
///   → Send logs.query
///   → Display formatted table or streaming output
///
/// lc status
///   → Send metrics.dashboard
///   → Display summary card:
///     Loop Commander — 5 tasks (3 active, 1 paused, 1 error)
///     Total runs: 351  |  Success: 97.2%  |  Spend: $35.56
///     Daemon: PID 4821, uptime 3d 14h
///
/// lc daemon start
///   → Spawn loop-commander binary in background (or load its launchd plist)
///
/// lc daemon stop
///   → Send SIGTERM to PID from daemon.pid
///
/// lc daemon status
///   → Send daemon.status or check PID file

/// IPC client helper:
async fn send_rpc(method: &str, params: serde_json::Value) -> Result<serde_json::Value> {
    // 1. Connect to Unix socket at LcPaths.socket_path
    // 2. Send JSON-RPC request + newline
    // 3. Read response line
    // 4. Parse JsonRpcResponse
    // 5. Return result or error
}
```

---

## 9. Swift macOS App

The Loop Commander GUI is a native Swift/SwiftUI macOS application. It communicates
with the Rust daemon exclusively via JSON-RPC 2.0 over the Unix domain socket —
there is NO FFI, no embedded Rust, and no direct crate access. This clean boundary
means the Swift app and Rust crates evolve independently with the JSON-RPC API as
the contract between them.

### Architecture Overview

```
┌─────────────────────────────┐     Unix Socket (JSON-RPC 2.0)     ┌──────────────┐
│   Swift macOS App           │ ◄──────────────────────────────────► │  lc-daemon   │
│                             │    Request/Response + Event Stream   │  (Rust)      │
│  SwiftUI Views              │                                     │              │
│    ↕                        │                                     │  ConfigMgr   │
│  ViewModels (@Observable)   │                                     │  Logger      │
│    ↕                        │                                     │  Scheduler   │
│  DaemonClient (service)     │                                     └──────────────┘
└─────────────────────────────┘
```

### Communication Layer (`Services/DaemonClient.swift`)

```swift
/// DaemonClient manages the Unix socket connection to the lc-daemon.
/// It sends JSON-RPC 2.0 requests and receives responses.
///
/// Socket path: ~/.loop-commander/daemon.sock
///
/// Usage:
///   let client = DaemonClient()
///   let tasks: [LCTask] = try await client.call("task.list", params: [:])
///
/// The client:
/// 1. Connects to the Unix domain socket on first request
/// 2. Sends newline-delimited JSON-RPC requests
/// 3. Reads newline-delimited JSON-RPC responses
/// 4. Auto-reconnects on connection loss with exponential backoff
/// 5. Supports concurrent requests via request ID correlation

actor DaemonClient {
    func call<T: Decodable>(_ method: String, params: Encodable) async throws -> T
    func subscribe(types: [String]?) -> AsyncStream<DaemonEvent>
    var isConnected: Bool { get }
}
```

### Event Streaming (`Services/EventStream.swift`)

```swift
/// The Swift app subscribes to real-time events via "events.subscribe".
/// The daemon holds the connection open and pushes JSON-RPC notifications.
/// The app uses this for:
/// - Updating task status in real-time (no polling needed)
/// - Showing "task running" animations
/// - Displaying completion/failure toasts
/// - Updating metrics without manual refresh
///
/// On connection loss, EventStream auto-reconnects and re-subscribes.

class EventStream: ObservableObject {
    @Published var lastEvent: DaemonEvent?
    func start() async
    func stop()
}
```

### Data Models (`Models/`)

Swift data models mirror the Rust `lc-core` types, decoded from JSON-RPC responses:

```swift
struct LCTask: Codable, Identifiable {
    let id: String             // "lc-a1b2c3d4"
    let name: String
    let command: String
    let skill: String?
    let schedule: Schedule
    let scheduleHuman: String
    let workingDir: String
    let envVars: [String: String]
    let maxBudgetPerRun: Double
    let maxTurns: Int?
    let timeoutSecs: Int
    let status: TaskStatus
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
}

enum TaskStatus: String, Codable {
    case active, paused, error, disabled, running
}

enum Schedule: Codable {
    case cron(expression: String)
    case interval(seconds: Int)
    case calendar(minute: Int?, hour: Int?, day: Int?, weekday: Int?, month: Int?)
}

struct ExecutionLog: Codable, Identifiable { /* mirrors lc-core::ExecutionLog */ }
struct DashboardMetrics: Codable { /* mirrors lc-core::DashboardMetrics, includes cost_trend */ }
struct DailyCost: Codable { /* date: String, total_cost: Double, run_count: Int */ }
struct TaskTemplate: Codable { /* mirrors lc-core::TaskTemplate */ }
struct DryRunResult: Codable { /* mirrors lc-core::DryRunResult */ }
struct TaskExport: Codable { /* mirrors lc-core::TaskExport */ }
```

### ViewModels (`ViewModels/`)

ViewModels use `@Observable` (macOS 14+) or `ObservableObject` (macOS 13 compatibility)
and call `DaemonClient` methods:

```swift
@Observable class TaskListViewModel {
    var tasks: [LCTask] = []
    var isLoading = false
    var error: String?

    func loadTasks() async { /* client.call("task.list") */ }
    func createTask(_ input: CreateTaskInput) async throws -> LCTask
    func deleteTask(_ id: String) async throws
    func pauseTask(_ id: String) async throws -> LCTask
    func resumeTask(_ id: String) async throws -> LCTask
}

@Observable class TaskDetailViewModel {
    var task: LCTask?
    var logs: [ExecutionLog] = []
    var dryRunResult: DryRunResult?

    func runNow() async throws { /* client.call("task.run_now") */ }
    func dryRun() async throws { /* client.call("task.dry_run") */ }
    func exportTask() async throws -> TaskExport
}

@Observable class DashboardViewModel {
    var metrics: DashboardMetrics?
    var costTrend: [DailyCost] = []

    func loadMetrics() async { /* client.call("metrics.dashboard") */ }
}
```

### SwiftUI Views (`Views/`)

The Swift app replicates the visual design from the `loop-commander.jsx` prototype:

**Key UI requirements (same as original prototype):**
- Dark background (#0f1117), light text (#e2e8f0)
- SF Mono for all code/data, SF Pro for UI text (native macOS equivalents)
- Indigo accent (#818cf8) for active states, buttons
- Status colors: green (#22c55e) active/success, amber (#f59e0b) paused, red (#ef4444) error
- Three views: Tasks (list/table), Detail (task info + task-specific logs), Logs (global log viewer)
- Sheet/modal editor for create/edit with fields: name, command (TextEditor), skill, working dir, cron, human schedule, budget, tags
- Log entries are expandable — click to show full stdout/stderr in monospace text
- Metric cards across the top: Active Tasks, Total Runs, Success Rate, Total Spend, 7-Day Sparkline, Daemon Status

**SwiftUI-specific patterns:**
- Use `NavigationSplitView` for the sidebar + detail layout (native macOS feel)
- Use `.sheet()` for the task editor modal
- Use `Charts` framework (macOS 13+) for the sparkline cost chart instead of custom SVG
- Use `UserNotifications` framework for native macOS notifications (N3)
- Support macOS toolbar with `.toolbar {}` for action buttons
- Respect system dark/light mode via `@Environment(\.colorScheme)` with dark as default
- Use `NWConnection` (Network framework) for the Unix socket, or raw `socket()` + `connect()` via Foundation

### Daemon Dependency

The Swift app REQUIRES the daemon to be running. On launch:
1. Attempt to connect to `~/.loop-commander/daemon.sock`
2. If connection fails, show a "Daemon not running" banner with a "Start Daemon" button
3. The "Start Daemon" button spawns `loop-commander --foreground` as a child process
   (or loads the launchd plist if installed)
4. Retry connection with exponential backoff (100ms, 200ms, 400ms, up to 5s)
5. Once connected, load all data and subscribe to events

### Xcode Project Notes

The Swift app is a standalone Xcode project in `macos-app/`. It has no Cargo/Rust
build dependencies. The only contract is the JSON-RPC API served by the daemon.

- **Bundle identifier:** `com.loopcommander.app`
- **Deployment target:** macOS 13.0 (Ventura)
- **Signing:** Development team signing for local builds
- **Window:** Default size 1200x800, min 900x600
- **Menu bar:** Standard macOS menu with Loop Commander menu items

---

## 10. Testing Requirements

Every crate must have tests that pass. Minimum coverage:

### `lc-core`
- TaskId::new() generates correct format
- Schedule::to_human() for each variant
- Serialization round-trip for Task, ExecutionLog
- JsonRpcResponse::success and ::error

### `lc-config`
- Create + read + update + delete task YAML
- Global config defaults when file doesn't exist
- Path expansion (~)
- CreateTaskInput → Task with defaults

### `lc-scheduler`
- Plist generation for Interval schedule
- Plist generation for Calendar schedule
- Cron → launchd conversion for common patterns:
  - `*/15 * * * *` → StartInterval 900
  - `0 */2 * * *` → StartInterval 7200
  - `0 7 * * 1-5` → Array of 5 StartCalendarInterval dicts (Mon-Fri at 07:00)
  - `0 0 * * *` → StartCalendarInterval {Hour: 0, Minute: 0}
  - `30 9 * * 1` → StartCalendarInterval {Weekday: 1, Hour: 9, Minute: 30}
  - Invalid/unsupported expressions → returns error, not silent wrong behavior
- Symlink creation in LaunchAgents dir
- Plist validation: generated plist can be parsed back by `plutil -lint`

### `lc-logger`
- DB creation and migration (idempotent)
- Insert + query round-trip
- Query with filters (task_id, status, limit)
- Dashboard metrics aggregation
- Log pruning

### `lc-runner`
- (Integration) Execute a simple `echo` command, verify log written
- Budget check logic (mock logger)
- Timeout handling

### `lc-daemon`
- JSON-RPC request parsing
- Response serialization
- Event subscription and broadcast
- (Integration) Start daemon, send task.list, verify response
- (Integration) Subscribe to events, trigger a task, verify event received
- Templates list returns all built-in templates
- Dry run returns correct resolved command and budget info
- Import/export round-trip (export task, import it back, verify equivalence)

### `lc-cli`
- CLI argument parsing for each subcommand
- `--template` flag resolves template and merges with overrides
- `--dry-run` flag sends correct RPC method
- `export` / `import` subcommand YAML serialization

### Swift macOS App (`macos-app/LoopCommanderTests/`)
- `DaemonClient` connection and request/response round-trip (using mock socket)
- JSON decoding of all model types from sample JSON-RPC responses
- `EventStream` reconnection behavior
- ViewModel state transitions (loading, loaded, error)

---

## 11. Build & Run

```bash
# Build all Rust crates
cargo build --release

# The three binaries:
# target/release/loop-commander    (daemon)
# target/release/lc-runner          (task executor)
# target/release/lc                 (CLI)

# Start the daemon
./target/release/loop-commander --foreground

# In another terminal, use the CLI
./target/release/lc status
./target/release/lc add --name "Test" --command "echo hello" --schedule "*/5 * * * *"
./target/release/lc list

# Build and run the Swift macOS app (requires Xcode)
cd macos-app
xcodebuild -scheme LoopCommander -configuration Debug build
# Or open in Xcode:
open LoopCommander.xcodeproj

# NOTE: The Swift app requires the daemon to be running.
# Start the daemon first, then launch the app.
```

---

## 12. CLAUDE.md (copy this into the project root)

```markdown
# Loop Commander

System-level macOS scheduler for Claude Code tasks with a native Swift dashboard.

## Architecture

7-crate Cargo workspace + native Swift macOS app:
- `lc-core`: Domain types, errors, IPC messages
- `lc-config`: YAML config read/write for global config + per-task files
- `lc-scheduler`: launchd plist generation, launchctl load/unload
- `lc-runner`: Standalone binary invoked by launchd to execute claude commands
- `lc-logger`: SQLite persistence for execution logs
- `lc-daemon`: Long-running Unix socket server, health checks, task lifecycle, event streaming
- `lc-cli`: Command line interface communicating with daemon via JSON-RPC
- `macos-app/`: Native Swift/SwiftUI macOS app (separate Xcode project, no Rust dependency)

All data lives in ~/.loop-commander/

## Key constraints

- macOS only (launchd, ~/Library/LaunchAgents)
- Tasks persist across reboots (launchd user agents)
- SQLite in WAL mode (concurrent readers)
- JSON-RPC 2.0 over Unix domain socket for ALL IPC
- The daemon is the SOLE API server — both the Swift app and CLI communicate through it
- No FFI between Swift and Rust — JSON-RPC is the only contract
- lc-runner is a separate binary for process isolation

## Testing

Run `cargo test --workspace` from root. Every crate has unit tests.
Integration tests may need launchd access (skip in CI with `#[cfg(not(ci))]`).
Swift app tests are in `macos-app/LoopCommanderTests/` (run via Xcode).

## File locations

- ~/.loop-commander/config.yaml — global settings
- ~/.loop-commander/tasks/*.yaml — one file per task
- ~/.loop-commander/plists/*.plist — generated launchd plists
- ~/.loop-commander/output/*.log — stdout/stderr from runs
- ~/.loop-commander/logs.db — SQLite execution log
- ~/.loop-commander/daemon.pid — daemon PID
- ~/.loop-commander/daemon.sock — daemon Unix socket
- ~/Library/LaunchAgents/com.loopcommander.task.*.plist — symlinks
```

---

## 13. Critical Implementation Notes

1. **No stubs.** Every function body must be implemented. If something can't work without macOS (like launchctl), gate it behind `#[cfg(target_os = "macos")]` and provide a no-op fallback that logs a warning.

2. **Error handling.** Use `anyhow::Result` at binary boundaries (main, command handlers). Use `LcError` in library crates. Return structured JSON-RPC errors with codes to clients.

3. **Concurrency.** The daemon uses `Arc<Mutex<ConfigManager>>` since config writes need serialization. Logger uses its own connection per thread (rusqlite Connection is not Send). For the daemon, wrap Logger in `Arc<Mutex<>>` too or open a connection per request. Since the daemon is the sole writer (no more dual-writer from the old Tauri architecture), YAML file contention is limited to daemon-internal operations. YAML writes should still use atomic semantics (write-to-temp-file + rename) for crash safety. SQLite WAL mode handles DB concurrency with lc-runner's writes, and busy_timeout should be set (recommended: 5000ms).

4. **Path safety.** Always expand `~` before passing to any system call. Use `shellexpand` crate or the manual `dirs::home_dir()` approach in LcPaths.

5. **launchctl commands.** Use `std::process::Command::new("launchctl")`. Prefer the modern `bootstrap`/`bootout`/`print` subcommands over the deprecated `load`/`unload`/`list`. The exit code of `launchctl bootstrap` is 0 on success. If the job is already loaded, `bootstrap` returns non-zero (errno 37, "already loaded") — handle gracefully by treating this as success. Use `launchctl print gui/<uid>/<label>` to check job status rather than parsing `launchctl list` output.

6. **The design prototype.** The `loop-commander.jsx` file delivered alongside this spec is the visual design reference for the Swift macOS app. Match its colors, layout structure, and interaction patterns using native SwiftUI equivalents (SF Mono instead of JetBrains Mono, NavigationSplitView instead of div-based layout, native macOS sheets instead of modal overlays, etc.).

7. **Daemon self-install.** Include a `lc daemon install` command that creates `~/Library/LaunchAgents/com.loopcommander.daemon.plist` with `KeepAlive: true` and `RunAtLoad: true`, then loads it. This makes the daemon survive reboots.

---

## 14. Production Readiness Addendum

This section captures findings from a comprehensive product review of the spec. Issues are organized by severity.

---

### 14.1 Critical Issues (must fix before building)

#### C1. ~~Race Condition Between Tauri and Daemon on YAML Writes~~ RESOLVED

**Original Problem:** The old Tauri architecture had both the Tauri app and the daemon writing to the same YAML files, creating race conditions.

**Resolution:** By pivoting to a native Swift app that communicates exclusively via JSON-RPC through the daemon, this problem is eliminated entirely. The daemon is now the sole writer to YAML config files and SQLite. The only remaining concurrent writer is `lc-runner`, which writes execution logs to SQLite (handled safely by WAL mode) and may update task status in YAML (handled by atomic writes).

All YAML writes (in `ConfigManager::save_task`) should still use atomic write semantics for crash safety:
1. Write to `{task-id}.yaml.tmp` in the same directory
2. `fsync` the file descriptor
3. `rename` the temp file to the final path (rename is atomic on POSIX)

#### C2. Command Injection via Task Commands

**Problem:** Section 5 (lc-runner) builds shell commands by string concatenation:
> "If task.command starts with 'claude': use it directly"
> "Otherwise: wrap as `claude -p '<command>' --output-format json`"

If a user-supplied command contains single quotes (e.g., `it's broken`), the wrapping creates a shell injection vector. Even for the "use it directly" path, spawning via a shell (`sh -c`) is dangerous if any part of the command comes from user input.

**Fix:**
- Never construct commands via string interpolation into a shell.
- Use `tokio::process::Command::new("claude")` with `.arg("-p").arg(&task.command)` — pass arguments as an array, not as a shell string.
- For commands that start with `claude`, parse the command string into argv tokens (respecting quoting) or require structured fields (`binary`, `args[]`, `prompt`) instead of a freeform string.
- Document that commands are NOT executed via a shell. If users need shell features (pipes, redirects), they must explicitly use `sh -c '...'` as the command, understanding the risks.

#### C3. No Input Validation on Task Creation

**Problem:** `CreateTaskInput` (Section 2) accepts arbitrary strings for `name`, `command`, `working_dir`, and `schedule` with no validation. There are several failure modes:
- `working_dir` pointing to a nonexistent directory causes silent launchd failures
- Empty `name` or `command` creates broken tasks
- Invalid cron expression causes scheduler panic or wrong schedule
- `max_budget_per_run` of 0 or negative bypasses budget safety
- Extremely long command strings could cause issues with plist generation

**Fix:** Add a `validate()` method on `CreateTaskInput` and `UpdateTaskInput` that checks:
- `name`: non-empty, max 200 chars, no control characters
- `command`: non-empty, max 10,000 chars
- `working_dir`: path exists and is a directory (after tilde expansion)
- `schedule`: cron expression parses successfully (use `cron` crate for validation)
- `max_budget_per_run`: must be > 0 and <= some reasonable cap (e.g., 100.0)
- `timeout_secs`: must be > 0 and <= 86400 (24 hours)
- `tags`: each tag max 50 chars, max 20 tags per task

Call `validate()` in the daemon's `task.create`/`task.update` handlers. Return structured JSON-RPC validation errors so the Swift app and CLI can display them.

#### C4. Missing Daemon Locking / Single-Instance Guarantee

**Problem:** The spec says the daemon writes a PID file on startup, but there is no mechanism to prevent a second daemon instance from starting. If two daemons run simultaneously, they will both:
- Try to bind the same Unix socket (one will fail, but the error may be confusing)
- Both run health checks and potentially double-register launchd jobs
- Both write to the PID file

**Fix:**
1. On startup, check if the PID file exists AND the process is alive (`kill(pid, 0)`).
2. If an existing daemon is running, print an error and exit.
3. Use `flock()` (advisory file lock) on the PID file as a belt-and-suspenders guard.
4. On startup, also check if the socket file exists. If it does, try to connect — if connection succeeds, another daemon is running. If it fails, the socket is stale and should be removed.

#### C5. Budget Safety Cap is Silently Hardcoded and Surprising

**Problem:** Section 5 (lc-runner) defines a safety cap: "If daily spend >= max_budget_per_run * 20: log Skipped, exit 0." This is an arbitrary multiplier (20x) that is:
- Not configurable
- Not documented in the UI or CLI output
- Not visible to the user when a task is silently skipped
- Calculated per-day, but the budget field is called `max_budget_per_run`

A user with `max_budget_per_run: $5.00` may not realize their task stops executing after $100/day of total spend.

**Fix:**
- Rename to be clearer: add a separate `daily_budget_cap` field to GlobalConfig (default: `max_budget_per_run * 20`, but user-configurable)
- When a task is skipped due to budget, set its status to a new `BudgetExceeded` state (or use the existing `Error` state with a clear error message)
- Surface budget-skip events in the execution log with status `Skipped` and a summary like "Daily budget cap ($100.00) reached. Task will resume tomorrow."
- Show remaining daily budget in the dashboard metrics

---

### 14.2 Recommended Improvements (should fix for production quality)

#### R1. No Graceful Handling of Corrupt YAML or DB

**Problem:** If a task YAML file is manually edited and becomes invalid (syntax error, missing required field, wrong type), `ConfigManager::list_tasks()` will return an error, potentially breaking the entire dashboard.

**Fix:**
- `list_tasks()` should use a per-file try/catch pattern: parse each YAML file individually, collect successes, and log warnings for failures.
- Return both the valid tasks AND a list of warnings/errors for corrupt files.
- In the UI, show a banner: "1 task file could not be loaded (lc-abc123.yaml: invalid syntax on line 5)"
- For SQLite corruption, `Logger::new()` should run `PRAGMA integrity_check` on startup. If the DB is corrupt, rename it to `logs.db.corrupt.{timestamp}` and create a fresh one, logging the incident.

#### R2. No Log Rotation or Size Limits

**Problem:** Section 6 defines log pruning by age (default 90 days), but there are no size limits. A task running every 15 minutes with verbose output could generate:
- ~96 runs/day * 90 days = 8,640 log entries
- If each has 10KB of stdout, that is ~84MB just for one task
- With 10+ tasks, the DB could easily exceed 1GB

Also, the `output/` directory (stdout/stderr files from launchd) is never cleaned up.

**Fix:**
- Add `max_log_entries_per_task` to GlobalConfig (default: 1000). Prune oldest entries per task when exceeded.
- Add `max_stdout_bytes` to GlobalConfig (default: 100KB). Truncate stdout/stderr in the execution log to this limit, appending "[truncated, full output in {path}]" with a pointer to the file on disk.
- Prune `output/` directory alongside DB pruning — delete stdout/stderr files for tasks that no longer exist.
- Add a `lc prune` CLI command for manual cleanup.
- Consider SQLite `VACUUM` after large deletes to reclaim space.

#### R3. No First-Run / Onboarding Experience

**Problem:** A new user who installs Loop Commander has no guidance. The daemon must be started manually, there is no `lc init` command, and the app shows an empty dashboard with no help text.

**Fix:**
- Add `lc init` command that: creates `~/.loop-commander/` directories, writes default `config.yaml`, installs the daemon launchd plist, and prints a welcome message with example commands.
- The Swift app should detect empty state (no tasks, or daemon returns empty task list) and show an onboarding view: "Welcome to Loop Commander. Create your first scheduled Claude task." with a prominent "New Task" button and example task templates.
- `lc` invoked with no arguments should show a helpful status summary (not just help text), similar to `git status`.
- The Swift app should auto-start the daemon on launch if it is not running (spawn `loop-commander` process or load the launchd plist).

#### R4. No Task Deletion Safety for Running Tasks

**Problem:** Section 7 defines `task.delete` as "Deactivates, unregisters, deletes YAML." But what if the task's lc-runner process is currently executing? Deleting the YAML while lc-runner is mid-execution means:
- lc-runner finishes and tries to update the task status to Error (step 14 in Section 5) — file not found
- The execution log is written to a task_id that no longer exists in config
- The launchd job may still be loaded even after plist deletion

**Fix:**
- Before deleting, check if lc-runner is currently running for this task (check for a PID file or use `launchctl list <label>` to see if a process is active).
- If running, either: (a) kill the process first, then delete, or (b) return an error "Task is currently executing. Stop it first with `lc stop <id>` or use `lc rm --force <id>`."
- Add a `task.stop` / `lc stop <id>` command that kills a running lc-runner process.
- Ensure `task.delete` removes the launchd job BEFORE deleting the YAML file (order matters).

#### R5. Structured Error Codes in JSON-RPC Responses

**Problem:** JSON-RPC errors need structured codes so clients (Swift app, CLI) can distinguish between "task not found", "database error", and "scheduler failed" and handle each appropriately.

**Fix:**
- Define standard JSON-RPC error codes in `lc-core` that map to `LcError` variants:
  - `-32001`: Task not found
  - `-32002`: Validation error (with details in `data` field)
  - `-32003`: Scheduler error
  - `-32004`: Database error
  - `-32005`: Daemon busy / resource locked
  - `-32006`: Budget exceeded
- Map `LcError` variants to these codes in the daemon's response builder.
- The Swift app should show different UI treatments for different error codes (e.g., "task not found" navigates back to task list, "daemon not running" shows a reconnect banner).

#### R6. Real-Time Event Streaming (IMPLEMENTED)

**Original Problem:** Polling-based updates feel sluggish. When a user clicks "Run Now," there's no feedback until the next poll.

**Resolution:** The daemon now supports an `events.subscribe` JSON-RPC method (see Section 7) that keeps the connection open and pushes real-time events to the Swift app. The Swift `EventStream` service (see Section 9) subscribes on launch and updates ViewModels immediately when events arrive. This eliminates polling entirely for status updates. The Swift app still does a full data refresh on window focus as a consistency safety net, but real-time updates handle the normal case.

#### R7. No Version Field in SQLite Schema

**Problem:** The SQL schema (Section 6) has no version tracking. If a future release changes the schema (adds columns, changes types), there is no way to detect or migrate.

**Fix:**
- Add a `schema_version` table: `CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL);`
- Insert version 1 on initial creation.
- In `migrate()`, check current version and apply sequential migrations.
- If the DB version is higher than the binary's known version, refuse to open it (prevents data corruption from downgrade).

#### R8. Prototype UI / Spec Mismatch: Missing "Run Now" Button

**Problem:** The prototype (`loop-commander.jsx`) has no "Run Now" button anywhere in the UI. The spec (Section 7) defines a `task.run_now` JSON-RPC method, but the prototype's TaskDetail view only has Edit, Pause/Resume, and Delete buttons.

**Fix:** Add a "Run Now" button to the TaskDetailView in the Swift app, positioned between the Edit and Pause buttons in the toolbar. Style it with the indigo accent to indicate it is an action button. Disable it when the task status is "running" (which leads to the next issue: there is no "running" status).

#### R9. Missing "Running" Task Status

**Problem:** The `TaskStatus` enum has `Active`, `Paused`, `Error`, `Disabled` — but no `Running` state. When a task's lc-runner is actively executing, the dashboard shows it as "Active" which is indistinguishable from "active but idle, waiting for next schedule." The UI prototype also lacks a "running" status in `STATUS_CONFIG`.

**Fix:**
- Add `Running` to `TaskStatus`.
- lc-runner should update the task status to `Running` at the start of execution (step 6, before spawning the process) and back to `Active` (or `Error`) at the end.
- The Swift app should show a pulsing animation for running tasks (use SwiftUI's `.animation(.easeInOut.repeatForever())` modifier).
- Since this introduces a write from lc-runner to YAML at runtime, use the atomic write strategy from C1.

---

### 14.3 Nice-to-Haves (would improve the product but not blocking)

#### Priority Ranking Summary

Ranked by value/effort ratio. Value considers user impact, activation improvement, and differentiation. Effort is relative T-shirt size.

| Rank | ID | Feature                    | Effort | Value   | Rationale                                                      |
|------|----|----------------------------|--------|---------|----------------------------------------------------------------|
| 1    | N5 | Dry Run Mode               | S      | High    | Tiny effort, massive debugging value, builds user confidence   |
| 2    | N7 | Accessibility              | S      | High    | Ethical baseline, low effort since StatusBadge already exists  |
| 3    | N4 | Task Import/Export          | S      | Medium  | Small CLI addition, unlocks sharing and multi-machine setups   |
| 4    | N1 | Task Templates             | M      | High    | Biggest onboarding accelerator, moderate effort                |
| 5    | N3 | Notification Integration   | M      | High    | Closes a gap the config already promises, moderate wiring      |
| 6    | N8 | Dark/Light Theme Toggle    | M      | Medium  | User comfort, but dark-first already works for most            |
| 7    | N6 | Log Search Full-Text Index | M      | Medium  | Only matters at scale; LIKE works fine for early usage         |
| 8    | N2 | Cost Trend Charts          | L      | Medium  | High polish value but requires charting library and new query  |

---

#### N1. Task Templates

**User Story**

As a new Loop Commander user, I want to pick from pre-built task templates when creating a task so that I can get a working scheduled Claude task in under 30 seconds without writing a prompt from scratch.

**Acceptance Criteria**

- [ ] The TaskEditor modal, when opened in "New Task" mode, shows a "Start from template" section above the form fields.
- [ ] Five built-in templates are available: PR Review Sweep, Dependency Audit, Test Health Check, Morning Briefing, and Error Log Monitor.
- [ ] Selecting a template populates all form fields (name, command, schedule, scheduleHuman, tags, maxBudget) with sensible defaults. The `workingDir` field is left as `~/projects/` for the user to customize.
- [ ] The user can edit any pre-filled field before saving. Templates are starting points, not locked presets.
- [ ] Each template displays a one-line description so users understand what it does before selecting.
- [ ] The CLI supports `lc add --template <name>` to create a task from a template, prompting for `workingDir` interactively or accepting it via `--working-dir`.
- [ ] Templates are defined as static data, not persisted to disk. No user-created templates in v1.

**Implementation Plan**

*Data structures (lc-core/src/lib.rs):*
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskTemplate {
    pub slug: &'static str,         // "pr-review", "dep-audit", etc.
    pub name: &'static str,
    pub description: &'static str,
    pub command: &'static str,
    pub schedule: Schedule,
    pub schedule_human: &'static str,
    pub max_budget_per_run: f64,
    pub tags: &'static [&'static str],
}

/// Built-in templates. Defined as a const array.
pub const BUILTIN_TEMPLATES: &[TaskTemplate] = &[
    TaskTemplate {
        slug: "pr-review",
        name: "PR Review Sweep",
        description: "Review all open PRs for logic errors, missing tests, and style issues",
        command: "claude -p 'Review all open PRs in this repo. Check for logic errors, missing tests, and style violations. Auto-fix what you can, leave comments on what you cannot.'",
        schedule: Schedule::Interval { seconds: 7200 },
        schedule_human: "Every 2 hours",
        max_budget_per_run: 5.0,
        tags: &["code-review", "automation"],
    },
    // ... 4 more templates (dep-audit, test-health, morning-briefing, error-monitor)
];
```

*Crates/files changed:*
- `lc-core/src/lib.rs` — Add `TaskTemplate` struct and `BUILTIN_TEMPLATES` constant.
- `lc-daemon/src/server.rs` — Add `templates.list` JSON-RPC method that returns `BUILTIN_TEMPLATES` as JSON. This is the single source of truth — the Swift app fetches templates from the daemon rather than duplicating them.
- `lc-cli/src/main.rs` — Add `--template <slug>` option to the `add` subcommand. When provided, fetch templates via `templates.list`, look up by slug, merge with any CLI overrides, and send `task.create`.
- `macos-app/.../TaskEditorView.swift` — Add a template picker section at the top of the "New Task" sheet. Render as a horizontal scrollable row of clickable cards (name + one-line description). On select, populate form fields from the template. Templates are fetched once from the daemon via `templates.list` and cached.

*API changes:* New `templates.list` JSON-RPC method (see Section 7).

**UI/UX Design**

When the TaskEditorView opens in "New" mode, the top of the sheet shows:
```
START FROM TEMPLATE (optional)
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ ...
│  PR Review      │ │  Dep Audit      │ │  Test Health    │
│  Review open    │ │  Scan for CVEs  │ │  Track flaky    │
│  PRs for issues │ │  daily          │ │  tests nightly  │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```
Cards use native SwiftUI styling on the dark background. Selected card gets an indigo border (`.overlay(RoundedRectangle(...).stroke(.indigo))`). Below the template row, all form fields appear as they do today, pre-filled from the selected template. A "Clear template" button resets to empty defaults.

**Effort Estimate:** M (Medium) — Static data definition is trivial; the UI template picker and CLI integration require moderate frontend/CLI work.

**Dependencies:** None. Can be built independently of all other features.

---

#### N2. Cost Trend Charts

**User Story**

As a Loop Commander user tracking spending across multiple tasks, I want to see a 7-day cost trend chart on the dashboard so that I can spot spending spikes and understand my cost trajectory without manually reviewing individual log entries.

**Acceptance Criteria**

- [ ] The MetricsBar section of the dashboard includes a "7-Day Spend" chart to the right of the existing "Total Spend" metric card.
- [ ] The chart shows daily aggregated cost (sum of `cost_usd` from `execution_logs`) for each of the last 7 days.
- [ ] The chart renders as an inline SVG sparkline (no external charting library). Height: 48px, width: 160px. Line color: indigo accent (#818cf8). Fill: gradient from indigo to transparent.
- [ ] Hovering over a data point shows a tooltip with the date and exact dollar amount.
- [ ] The chart handles zero-cost days gracefully (line touches the baseline).
- [ ] A new JSON-RPC method `metrics.cost_trend` returns the data. The CLI `lc status` command also displays a text-based sparkline using Unicode block characters.
- [ ] If there is no cost data for the last 7 days, show the chart area with a "No data yet" placeholder.

**Implementation Plan**

*Data structures (lc-core/src/lib.rs):*
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DailyCost {
    pub date: String,        // "2026-03-15"
    pub total_cost: f64,
    pub run_count: u64,
}

// Add to DashboardMetrics:
pub struct DashboardMetrics {
    // ... existing fields ...
    pub cost_trend: Vec<DailyCost>,  // Last 7 days, ordered oldest to newest
}
```

*Crates/files changed:*
- `lc-core/src/lib.rs` — Add `DailyCost` struct. Add `cost_trend` field to `DashboardMetrics`.
- `lc-logger/src/lib.rs` — Add `get_cost_trend(&self, days: u32) -> Result<Vec<DailyCost>>` method. SQL:
  ```sql
  SELECT DATE(started_at) as date,
         COALESCE(SUM(cost_usd), 0.0) as total_cost,
         COUNT(*) as run_count
  FROM execution_logs
  WHERE started_at >= datetime('now', '-7 days')
  GROUP BY DATE(started_at)
  ORDER BY date ASC
  ```
  Backfill missing days with zero values so the frontend always gets exactly 7 data points.
- `lc-daemon/src/server.rs` — Populate `cost_trend` in the `metrics.dashboard` handler. Also add a standalone `metrics.cost_trend` method (see Section 7) for clients that want cost data without the full dashboard payload.
- `macos-app/.../SparklineChart.swift` — New SwiftUI view using the `Charts` framework (available macOS 13+). Render as a `Chart { LineMark(...) AreaMark(...) }` with indigo color. Supports hover interaction via `.chartOverlay` for tooltip display.
- `macos-app/.../MetricsBarView.swift` — Add the SparklineChart as an additional metric card alongside Active Tasks, Total Runs, etc.
- `lc-cli/src/main.rs` — In the `status` display, render a text sparkline using Unicode block characters (` `, `▁`, `▂`, `▃`, `▄`, `▅`, `▆`, `▇`, `█`).

**UI/UX Design**

The sparkline sits inside a metric card styled identically to the existing ones:
```
┌──────────────────────────────────────┐
│  7-DAY SPEND                         │
│  ╭─╮                                 │
│ ╭╯ ╰╮  ╭╮                           │
│╯    ╰──╯╰─╮╭─                       │
│            ╰╯          $23.41 total  │
│  Mar 9 ─────────── Mar 15           │
└──────────────────────────────────────┘
```
In the CLI `lc status` output:
```
7-day spend: ▂▅▇▃▁▄▆  $23.41
```

**Effort Estimate:** L (Large) — Requires a new SQL query, backend wiring, a custom SVG chart component, tooltip interaction, and CLI sparkline rendering.

**Dependencies:** None, but benefits from the existing `DashboardMetrics` infrastructure.

---

#### N3. Notification Integration

**User Story**

As a Loop Commander user with tasks running in the background, I want to receive macOS native notifications when something goes wrong (task failure, budget exhaustion, daemon issues) so that I don't have to constantly check the dashboard to stay informed.

**Acceptance Criteria**

- [ ] When `notifications_enabled: true` in `config.yaml` (default), the following events trigger a macOS notification:
  - A task transitions from a non-error state to `Error` or `Failed` status.
  - A task is skipped due to daily budget cap being reached.
  - The daemon health check detects and auto-repairs a launchd discrepancy.
- [ ] Notifications use macOS native `UserNotifications` framework, appearing in Notification Center.
- [ ] Each notification includes: a title (e.g., "Task Failed: PR Review Sweep"), a body with summary text (first 100 chars of the error summary), and the Loop Commander app icon.
- [ ] Clicking a notification opens the Swift app to the relevant task's detail view (via a custom URL scheme `loopcommander://task/{id}` or `NSUserNotification` action handling).
- [ ] Notifications are rate-limited: no more than 1 notification per task per 5-minute window (prevents spam from frequently-scheduled failing tasks).
- [ ] The user can disable notifications globally via `config.yaml` or per-task via a `notifications: false` field on the task.
- [ ] The CLI `lc status` output indicates whether notifications are enabled.

**Implementation Plan**

*Data structures:*
- Add `notifications: Option<bool>` to `Task` struct in `lc-core` (default: `None`, meaning inherit from global config).
- No new structs needed; notification dispatch is a side effect, not a query.

*Crates/files changed:*
- `lc-runner/src/main.rs` — After writing the execution log (step 13), if the run status is `Failed` or `Timeout` or `Killed`, and notifications are enabled (check global config + task-level override), send a notification. Use the `mac-notification-sys` crate (pure Rust, no Objective-C bridging needed, MIT license). Implementation:
  ```rust
  use mac_notification_sys::*;

  fn send_failure_notification(task_name: &str, summary: &str) {
      let bundle = get_bundle_identifier_or_default("com.loopcommander.app");
      set_application(&bundle).ok();
      send_notification(
          &format!("Task Failed: {}", task_name),
          None,  // subtitle
          &summary[..summary.len().min(100)],
          None,  // sound
      ).ok();  // Best-effort, never fail the run for notification issues
  }
  ```
- `lc-daemon/src/health.rs` — After auto-repairing a launchd discrepancy, send a notification: "Health Check: Re-registered {task_name}".
- `lc-runner/src/main.rs` — For budget-skip events (step 5), send a notification: "Budget Cap Reached: {task_name}. Task will resume tomorrow."
- `lc-core/src/lib.rs` — Add `notifications: Option<bool>` field to `Task` struct with `#[serde(skip_serializing_if = "Option::is_none")]`.
- `Cargo.toml` (workspace) — Add `mac-notification-sys = "0.6"` to workspace dependencies.
- `lc-runner/Cargo.toml` — Add `mac-notification-sys` dependency.
- `lc-daemon/Cargo.toml` — Add `mac-notification-sys` dependency.

*Rate limiting:* Implement via a simple file-based timestamp check. Before sending a notification, check `~/.loop-commander/notify-last/{task_id}` for the last notification timestamp. If less than 5 minutes ago, skip. This avoids adding state to the runner binary.

*Alternative approach — daemon-driven notifications:* Instead of (or in addition to) having lc-runner send notifications directly via `mac-notification-sys`, the daemon can send notifications via the `events.subscribe` stream. The Swift app receives these events and uses the native `UserNotifications` framework to display them. This approach is cleaner because:
1. The Swift app has proper access to `UNUserNotificationCenter` with full control over presentation.
2. The daemon's event stream already carries all the needed data (`TaskFailed`, `BudgetExceeded`, `HealthRepair` events).
3. Notification rate-limiting can be handled in the Swift app's event handler rather than via filesystem timestamps.
4. Clicking a notification can navigate directly to the relevant task view via `UNNotificationAction`.

When the Swift app is NOT running, lc-runner should still send notifications via `mac-notification-sys` as a fallback so the user is informed even without the GUI open.

*Custom URL scheme:* Register `loopcommander://` in the Swift app's `Info.plist`. The app handles `loopcommander://task/{id}` by navigating to the task detail view via `onOpenURL` modifier.

**UI/UX Design**

The notification appears as a standard macOS banner/alert:
```
┌──────────────────────────────────────────────┐
│ [Loop Commander icon]                         │
│ Task Failed: PR Review Sweep                  │
│ Process exited with code 1. Auth token        │
│ expired, unable to access GitHub API.         │
└──────────────────────────────────────────────┘
```
Clicking the notification opens the Swift app directly to that task's detail view.

In the TaskEditorView, add a toggle: "Disable notifications for this task" (only visible when global notifications are enabled).

**Effort Estimate:** M (Medium) — The `mac-notification-sys` crate handles lc-runner notifications. The Swift app uses `UserNotifications` framework natively for daemon-driven notifications. Deep-link handling uses standard macOS URL scheme registration.

**Dependencies:**
- The `notifications_enabled` field already exists in `GlobalConfig`.
- Deep-link click-to-open depends on the Swift app being installed (registered URL scheme).

---

#### N4. Task Import/Export

**User Story**

As a user with multiple machines (or working on a team), I want to export a task configuration to a YAML file and import it on another machine so that I can share and replicate scheduled tasks without manual re-entry.

**Acceptance Criteria**

- [ ] `lc export <id>` writes the task's YAML to stdout. The output is a valid standalone YAML document that includes all task fields except `id`, `created_at`, `updated_at`, and runtime statistics (those are regenerated on import).
- [ ] `lc export <id> -o <file>` writes to a file instead of stdout.
- [ ] `lc import <file>` reads a YAML file, validates it, assigns a new `TaskId`, sets timestamps to now, and creates the task via the daemon's `task.create` method.
- [ ] `lc import <file> --dry-run` validates the file and shows what task would be created without actually creating it.
- [ ] Import validates all fields using the same validation logic as `CreateTaskInput::validate()` (from C3).
- [ ] If the imported YAML has unknown fields, they are silently ignored (forward compatibility).
- [ ] The Swift app has "Export" and "Import" buttons: Export saves a `.yaml` file via `NSSavePanel`. Import opens a file picker via `NSOpenPanel` and creates the task.
- [ ] The exported YAML includes a `# Loop Commander Task Export` header comment and a `version: 1` field for future format evolution.

**Implementation Plan**

*Data structures (lc-core/src/lib.rs):*
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskExport {
    pub version: u32,           // Always 1
    pub name: String,
    pub command: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub skill: Option<String>,
    pub schedule: Schedule,
    pub schedule_human: String,
    pub working_dir: String,    // Kept as string, not PathBuf, for portability
    #[serde(default)]
    pub env_vars: HashMap<String, String>,
    pub max_budget_per_run: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_turns: Option<u32>,
    pub timeout_secs: u64,
    #[serde(default)]
    pub tags: Vec<String>,
}
```

*Crates/files changed:*
- `lc-core/src/lib.rs` — Add `TaskExport` struct. Add `impl From<&Task> for TaskExport` and `impl From<TaskExport> for CreateTaskInput`.
- `lc-daemon/src/server.rs` — Add `task.export` and `task.import` JSON-RPC methods (see Section 7). Export returns a `TaskExport` JSON object. Import validates, assigns new ID/timestamps, and creates the task.
- `lc-cli/src/main.rs` — Add `export` and `import` subcommands:
  - `export`: Send `task.export` to daemon, serialize result as YAML, write to stdout or file.
  - `import`: Read file, deserialize `TaskExport`, send `task.import` to daemon. Print the new task ID.
- `macos-app/.../TaskDetailView.swift` — Add an "Export" toolbar button. On click, call `task.export` via DaemonClient, then present `NSSavePanel` to write the YAML file.
- `macos-app/.../ContentView.swift` — Add an "Import" toolbar button near "New Task". On click, present `NSOpenPanel` for `.yaml` files, read contents, send to `task.import` via DaemonClient.

**UI/UX Design**

Export button in TaskDetailView: a toolbar button with `systemImage: "square.and.arrow.up"`, tooltip "Export as YAML".

Import button in toolbar: positioned next to "New Task" with `systemImage: "square.and.arrow.down"`, label "Import".

On import, a brief alert or toast appears: "Imported: PR Review Sweep (lc-f3a9b2c1)" or "Import failed: invalid schedule expression".

**Effort Estimate:** S (Small) — Mostly serialization/deserialization with existing types. CLI subcommands are trivial. The Swift `NSSavePanel`/`NSOpenPanel` integration is straightforward.

**Dependencies:**
- Validation logic from C3 (CreateTaskInput::validate) should exist for import validation in the daemon's `task.import` handler.
- `NSSavePanel` / `NSOpenPanel` are part of AppKit (available on all macOS versions).

---

#### N5. Dry Run Mode

**User Story**

As a user debugging a task configuration, I want to preview exactly what command would be executed, in what directory, and with what environment variables, without actually running it, so that I can verify my setup before committing to a real execution.

**Acceptance Criteria**

- [ ] `lc run <id> --dry-run` outputs a formatted summary showing:
  - The resolved command (after template expansion, with the exact argv array that would be passed to `tokio::process::Command`)
  - The working directory (after tilde expansion)
  - All environment variables that would be set (task-specific + inherited)
  - The timeout value
  - The budget cap and current daily spend
  - Whether the task would be skipped due to budget
  - The schedule (for informational context)
- [ ] The command exits with code 0 and does NOT execute the claude command, modify any state, write any logs, or contact launchd.
- [ ] `lc run <id> --dry-run --json` outputs the same information as a JSON object (for scripting/piping).
- [ ] The Swift app's TaskDetailView has a "Dry Run" button that shows the same information in a sheet styled as a monospace code block.

**Implementation Plan**

*Crates/files changed:*
- `lc-core/src/lib.rs` — Add a `DryRunResult` struct:
  ```rust
  #[derive(Debug, Clone, Serialize, Deserialize)]
  pub struct DryRunResult {
      pub task_id: String,
      pub task_name: String,
      pub resolved_command: Vec<String>,  // argv array
      pub working_dir: String,
      pub env_vars: HashMap<String, String>,
      pub timeout_secs: u64,
      pub max_budget_per_run: f64,
      pub daily_spend_so_far: f64,
      pub would_be_skipped: bool,
      pub skip_reason: Option<String>,
      pub schedule_human: String,
  }
  ```
- `lc-runner/src/lib.rs` — Extract the command-building logic (step 7 in the runner's execution flow) into a public function `build_command(task: &Task) -> Vec<String>` so it can be reused by dry-run without duplicating the logic.
- `lc-daemon/src/server.rs` — Add a `task.dry_run` JSON-RPC method. It loads the task, calls `build_command`, queries `Logger::total_cost_since` for today, assembles `DryRunResult`, and returns it. No side effects.
- `lc-cli/src/main.rs` — Add `--dry-run` flag to the `run` subcommand. When set, send `task.dry_run` instead of `task.run_now`. Format the result:
  ```
  DRY RUN: PR Review Sweep (lc-a1b2c3d4)
  ─────────────────────────────────────────
  Command:     claude -p "Review all open PRs..." --output-format json
  Working dir: /Users/hitch/projects/hello-ai-site
  Timeout:     600s
  Budget:      $5.00/run | $12.47 spent today | cap $100.00/day
  Skipped:     No
  Schedule:    Every 2 hours

  Environment:
    PATH=/usr/local/bin:...
    CLAUDE_MODEL=opus
  ```
- `macos-app/.../TaskDetailView.swift` — Add "Dry Run" toolbar button. On click, call `task.dry_run` via DaemonClient and display the result in a `.sheet()` with a `ScrollView { Text(...).font(.system(.body, design: .monospaced)) }` block.

**UI/UX Design**

CLI output as shown above. In the Swift app, the Dry Run button sits in the TaskDetailView toolbar (alongside Run Now, Edit, Pause, Delete). Clicking it opens a sheet with the same information formatted as monospaced text on the dark background, with a "Close" button.

**Effort Estimate:** S (Small) — No new infrastructure. Mostly formatting existing data that the runner already computes internally. The `build_command` extraction is the only code refactoring needed.

**Dependencies:**
- The command-building logic in `lc-runner` must be extractable as a library function. This requires `lc-runner` to have both a `lib.rs` and `main.rs`, which the spec already structures.
- Budget check depends on `Logger::total_cost_since`.

---

#### N6. Log Search Full-Text Index

**User Story**

As a power user with hundreds or thousands of execution logs, I want fast full-text search across log summaries and stdout output so that I can quickly find specific task results, error messages, or patterns without waiting for slow LIKE queries.

**Acceptance Criteria**

- [ ] An FTS5 virtual table is created in the SQLite database alongside the existing `execution_logs` table.
- [ ] The FTS5 table indexes the `summary` and `stdout` columns from `execution_logs`.
- [ ] When `LogQuery.search` is set, the query uses the FTS5 `MATCH` operator instead of `LIKE '%term%'`.
- [ ] FTS5 search supports standard query syntax: quoted phrases (`"exact match"`), prefix search (`error*`), boolean operators (`fail AND timeout`).
- [ ] The FTS5 index is populated automatically when new logs are inserted (via triggers or explicit insert in `Logger::insert_log`).
- [ ] A migration adds the FTS5 table and backfills it from existing data. The migration is idempotent.
- [ ] Search results include FTS5 snippet highlighting (the matching text context), passed to the frontend for display.
- [ ] Performance target: search across 10,000 logs completes in under 50ms.
- [ ] The feature degrades gracefully: if FTS5 is not available (unlikely with bundled rusqlite, but defensive), fall back to LIKE.

**Implementation Plan**

*Schema changes (lc-logger migration):*
```sql
-- FTS5 virtual table for full-text search on logs
CREATE VIRTUAL TABLE IF NOT EXISTS execution_logs_fts
USING fts5(
    summary,
    stdout,
    content='execution_logs',
    content_rowid='id',
    tokenize='porter unicode61'
);

-- Triggers to keep FTS in sync
CREATE TRIGGER IF NOT EXISTS logs_fts_insert AFTER INSERT ON execution_logs BEGIN
    INSERT INTO execution_logs_fts(rowid, summary, stdout)
    VALUES (new.id, new.summary, new.stdout);
END;

CREATE TRIGGER IF NOT EXISTS logs_fts_delete AFTER DELETE ON execution_logs BEGIN
    INSERT INTO execution_logs_fts(execution_logs_fts, rowid, summary, stdout)
    VALUES ('delete', old.id, old.summary, old.stdout);
END;

CREATE TRIGGER IF NOT EXISTS logs_fts_update AFTER UPDATE ON execution_logs BEGIN
    INSERT INTO execution_logs_fts(execution_logs_fts, rowid, summary, stdout)
    VALUES ('delete', old.id, old.summary, old.stdout);
    INSERT INTO execution_logs_fts(rowid, summary, stdout)
    VALUES (new.id, new.summary, new.stdout);
END;

-- Backfill existing data (run once during migration)
INSERT INTO execution_logs_fts(rowid, summary, stdout)
SELECT id, summary, stdout FROM execution_logs;
```

*Crates/files changed:*
- `lc-logger/src/lib.rs` — Update `migrate()` to include FTS5 table creation and triggers (gated behind a schema version check from R7). Update `query_logs()`:
  ```rust
  fn query_logs(&self, query: &LogQuery) -> Result<Vec<ExecutionLog>> {
      if let Some(ref search) = query.search {
          // Use FTS5 MATCH query with snippet highlighting
          let sql = "SELECT e.*, snippet(execution_logs_fts, 0, '<mark>', '</mark>', '...', 32) as highlighted_summary
                     FROM execution_logs e
                     JOIN execution_logs_fts f ON e.id = f.rowid
                     WHERE execution_logs_fts MATCH ?1
                     ORDER BY rank
                     LIMIT ?2 OFFSET ?3";
          // ...
      } else {
          // Existing query logic without FTS
      }
  }
  ```
- `lc-core/src/lib.rs` — Add `highlighted_summary: Option<String>` to `ExecutionLog` for passing FTS snippet data to clients.
- `macos-app/.../Views/LogsView.swift` — When displaying search results, parse `highlighted_summary` and render with `AttributedString` to highlight matched terms in the indigo accent color.

*Note on rusqlite FTS5:* The `rusqlite` crate with the `bundled` feature compiles SQLite from source and includes FTS5 by default. No additional feature flags are needed.

**UI/UX Design**

No visible UI changes beyond improved search speed and highlighted search matches in the LogsView. The search field already exists in the LogsView. Search results now show the matching text fragment with the search terms highlighted in the indigo accent color.

**Effort Estimate:** M (Medium) — The SQL and trigger setup is well-documented FTS5 boilerplate. The main effort is the migration logic, backfill, and snippet rendering on the frontend.

**Dependencies:**
- Schema versioning from R7 (to gate the FTS5 migration).
- `rusqlite` with `bundled` feature (already specified in workspace dependencies).

---

#### N7. Accessibility

**User Story**

As a user who relies on keyboard navigation, a screen reader, or works in lighting conditions where color alone is insufficient, I want the Loop Commander dashboard to be fully accessible so that I can use the product without barriers.

**Acceptance Criteria**

- [ ] Status is never conveyed by color alone. Every status indicator includes a text label and/or icon (SF Symbols). The `StatusBadge` view shows icons and text labels (`Active`, `Paused`, `Error`) — verify this is consistent everywhere status appears (task list rows, detail views, log entries, metric cards).
- [ ] All interactive elements (buttons, form inputs, navigation, expandable log entries) support standard macOS keyboard navigation.
- [ ] Focus states are visible: SwiftUI's default focus ring behavior is enabled and styled appropriately for the dark theme.
- [ ] The task list supports arrow-key navigation: Up/Down to move between rows, Enter/Return to open detail view.
- [ ] All interactive elements have appropriate accessibility labels and traits:
  - Buttons: `.accessibilityLabel()` when icon-only (e.g., toolbar buttons).
  - Status badges: `.accessibilityLabel("Task status: Active")`.
  - Expandable log entries: `.accessibilityAddTraits(.isButton)` with `.accessibilityValue()` indicating expanded/collapsed.
  - Sheet modals: automatically handled by SwiftUI.
  - The task list: `.accessibilityElement(children: .contain)` with proper row labels.
- [ ] Color contrast ratios meet WCAG 2.1 AA standards (4.5:1 for normal text, 3:1 for large text). Audit all text/background combinations. The current palette (#e2e8f0 on #0f1117) is approximately 15:1, which passes. Verify accent colors and muted text.
- [ ] The app responds correctly to the macOS "Reduce motion" accessibility setting. When enabled, disable the pulse animation on running tasks and any hover transitions.
- [ ] Screen reader announces view changes (e.g., switching from Tasks to Logs view) via `aria-live="polite"` regions.

**Implementation Plan**

*Files changed (all in macos-app/LoopCommander/):*
- `Views/StatusBadge.swift` — Add `.accessibilityLabel("Task status: \(status.rawValue)")` and `.accessibilityAddTraits(.isStaticText)`.
- `Views/TaskListView.swift` — Ensure `List` or `ForEach` rows have `.accessibilityLabel()` summarizing each task (name, status, schedule).
- `Views/TaskEditorView.swift` — Sheets in SwiftUI handle focus trapping automatically. Add `.accessibilityLabel()` to the sheet.
- `Views/LogsView.swift` — For expandable log entries, use `DisclosureGroup` which provides built-in accessibility, or add `.accessibilityAddTraits(.isButton)` with `.accessibilityValue(isExpanded ? "expanded" : "collapsed")`.
- All animated views — Respect `@Environment(\.accessibilityReduceMotion)` and disable pulse/transition animations when true.

*No Rust/backend changes needed.* This is entirely a Swift/UI concern.

**UI/UX Design**

Visual changes are minimal — SwiftUI provides strong accessibility defaults out of the box. The main work is:
- Ensuring all custom views have proper `.accessibilityLabel()` and `.accessibilityHint()`.
- Respecting `accessibilityReduceMotion` for the running-task pulse animation.
- Verifying VoiceOver reads task status, metrics, and log entries correctly.

**Effort Estimate:** S (Small) — SwiftUI provides much better accessibility out of the box than web-based UIs. Most of the work is adding labels to custom views and verifying VoiceOver behavior.

**Dependencies:** None. Can be implemented at any time.

---

#### N8. Dark/Light Theme Toggle

**User Story**

As a user who works in a well-lit environment or prefers light interfaces, I want to switch Loop Commander to a light theme so that the UI is comfortable to use in all lighting conditions.

**Acceptance Criteria**

- [ ] A theme toggle control appears in the Header, to the right of the navigation. It shows a sun/moon icon indicating the current theme.
- [ ] Clicking the toggle switches between dark and light themes instantly (no page reload).
- [ ] The selected theme is persisted in `~/.loop-commander/config.yaml` as a `theme: "dark" | "light" | "system"` field.
- [ ] The default value is `"dark"` (matching the current spec mandate).
- [ ] `"system"` follows the macOS system appearance preference and responds to changes in real-time (via `NSApp.effectiveAppearance` / SwiftUI's `@Environment(\.colorScheme)`).
- [ ] All UI elements adapt to the theme: backgrounds, text colors, borders, status colors, metric cards, the task editor sheet, and the log viewer.
- [ ] The light theme maintains the same layout, typography (SF Mono + SF Pro), and indigo accent. Only surface/text colors change.
- [ ] Status colors remain unchanged in both themes (green, amber, red have sufficient contrast on both dark and light backgrounds).

**Implementation Plan**

*Data structures:*
- Add `theme: Option<String>` to `GlobalConfig` in `lc-config`. Default: `"dark"`. Valid values: `"dark"`, `"light"`, `"system"`.

*SwiftUI approach:* Use `@Environment(\.colorScheme)` and `.preferredColorScheme()` to control the app's appearance. Define custom color sets in `Assets.xcassets` with light and dark variants, or use a `Theme` struct that resolves colors based on the current scheme.

*Color palette:*
```swift
struct Theme {
    // Dark mode (default)
    static let darkBackground = Color(hex: "#0f1117")
    static let darkSurface = Color(hex: "#1a1d23")
    static let darkText = Color(hex: "#e2e8f0")
    static let darkMuted = Color.white.opacity(0.35)

    // Light mode
    static let lightBackground = Color(hex: "#f8f9fc")
    static let lightSurface = Color.white
    static let lightText = Color(hex: "#1a1d23")
    static let lightMuted = Color(hex: "#718096")

    // Shared
    static let accent = Color(hex: "#818cf8")  // indigo
    static let success = Color(hex: "#22c55e")
    static let warning = Color(hex: "#f59e0b")
    static let error = Color(hex: "#ef4444")
}
```

*Crates/files changed:*
- `lc-config/src/lib.rs` — Add `theme: Option<String>` to `GlobalConfig` with `#[serde(default = "default_theme")]`. `fn default_theme() -> String { "dark".to_string() }`.
- `lc-daemon/src/server.rs` — Theme is read/written via the existing `config.get` and `config.update` JSON-RPC methods.
- `macos-app/.../LoopCommanderApp.swift` — On launch, fetch theme from daemon via `config.get`. Apply `.preferredColorScheme()` to the root `WindowGroup`. For `"system"`, omit the modifier (SwiftUI follows system default). For `"dark"`/`"light"`, set explicitly.
- `macos-app/.../Views/` — Use `@Environment(\.colorScheme)` in views that need conditional styling. Most SwiftUI views adapt automatically.
- `macos-app/.../Assets.xcassets` — Define color sets with light/dark variants for custom colors (background, surface, muted text).

**UI/UX Design**

The theme toggle sits in the toolbar, right-aligned:
```
[ Tasks | Logs ]                                    [sun/moon] [New Task]
```
Use SF Symbols: `sun.max.fill` (light mode active), `moon.fill` (dark mode active), `circle.lefthalf.filled` (system mode). The toggle cycles through dark -> light -> system via a menu or long-press.

The light theme preserves all layout and spacing. SwiftUI handles most color adaptation automatically when using semantic colors and color assets with light/dark variants.

**Effort Estimate:** S (Small) — SwiftUI's built-in dark/light mode support handles most of the work. The main effort is defining custom color assets with both variants and ensuring custom-colored views adapt. Much simpler than the CSS migration that would have been needed with the Tauri approach.

**Dependencies:** None.

---

### 14.4 Resolved Decisions

The following decisions reflect the architecture pivot from Tauri (React) to a **native Swift macOS app (SwiftUI)**. The Swift app communicates with the Rust daemon exclusively via the Unix socket JSON-RPC interface, which eliminates the dual-writer problem from the original Tauri design and simplifies the overall architecture.

#### D1. The Swift App Communicates Exclusively Through the Daemon

**Decision:** The Swift app talks to the daemon via the Unix domain socket (JSON-RPC 2.0). There is no direct Rust crate access from Swift. The daemon must be running for the app to function.

**Rationale:** A native Swift app cannot call Rust crates in-process the way a Tauri app could. This constraint turns out to be an architectural advantage:
- **Single code path.** Every client (Swift app, CLI, future integrations) goes through the daemon's JSON-RPC API. One set of validation logic, one set of concurrency controls, one source of truth.
- **Eliminates C1 entirely.** The dual-writer race condition on YAML files is no longer possible. The daemon is the sole writer.
- **Simpler testing.** The daemon API is the only integration surface. The Swift app is a pure presentation layer.

**Implementation notes:**
- On launch, the Swift app checks for the daemon process (PID file at `~/.loop-commander/daemon.pid` + socket connectivity test).
- If the daemon is not running, the app starts it automatically via `Process` (spawning the `loop-commander` binary with `--foreground` piped to a log, or by triggering the launchd agent).
- The app displays a connection status indicator in the toolbar: green dot when connected, red dot with "Reconnecting..." when the socket is unavailable.
- If the daemon cannot be started (binary not found, permissions error), the app shows a blocking modal with diagnostic information and a "Retry" button.
- The app maintains a persistent socket connection to the daemon and reconnects with exponential backoff (1s, 2s, 4s, max 30s) on disconnection.
- All JSON-RPC calls use a 10-second timeout. On timeout, the app shows inline error states per-operation rather than a global error banner.

#### D2. Claude Code Detection and Configuration

**Decision:** The app and daemon validate Claude Code availability at two points: daemon startup (non-blocking warning) and task creation/execution (blocking error). Users can configure a custom binary path.

**Rationale:** Failing silently at execution time with a buried "command not found" error is unacceptable UX. However, Claude Code not being installed should not prevent the app from launching or the daemon from running, because users may install it after setting up Loop Commander, or may only need it on specific machines.

**Implementation notes:**
- **Daemon startup:** On boot, the daemon checks for the `claude` binary using the configured path (default: `claude`, resolved via `PATH`). If not found, it logs a warning via tracing but continues running. The `daemon.status` JSON-RPC response includes a `claude_available: bool` field.
- **App startup:** After connecting to the daemon, the Swift app calls `daemon.status`. If `claude_available` is false, it displays a non-blocking banner: "Claude Code not found. Install it or configure the path in Settings." The banner includes a "Configure" button that opens the settings view.
- **Task creation:** The daemon's `task.create` handler performs a pre-flight check: verify the claude binary exists and is executable. If not, return a JSON-RPC error with code `-32001` and a message like `"Claude Code binary not found at 'claude'. Install Claude Code or set claude_binary in config."` The Swift app surfaces this as a form validation error on the task editor.
- **Task execution:** `lc-runner` checks for the binary before spawning. If missing, it writes an `ExecutionLog` with status `Failed` and summary `"Claude Code not found at configured path"`, then exits with code 1.
- **Custom path configuration:** The `GlobalConfig.claude_binary` field (already in the spec) serves this purpose. The Swift app exposes this in a Settings view. The daemon validates the path is executable when the config is saved. Common locations to suggest: `/usr/local/bin/claude`, `~/.claude/bin/claude`, `~/.npm/bin/claude`.
- **PATH resolution:** The daemon resolves the binary path using `which` semantics at startup and caches the resolved absolute path. `lc-runner` inherits the configured path from the task's environment or the global config.

#### D3. Daylight Saving Time Handling

**Decision:** Document launchd's wall-clock DST behavior explicitly in the app UI. Recommend UTC-based intervals (`Schedule::Interval`) for time-sensitive tasks. Do not add a timezone field to tasks.

**Rationale:** launchd's `StartCalendarInterval` inherently uses the system's local wall-clock time. This is the correct behavior for most use cases ("run my PR review at 9 AM every morning" should track wall-clock 9 AM regardless of DST). Adding timezone support would mean reimplementing cron scheduling outside of launchd, which contradicts the design principle of delegating scheduling to the OS.

**Implementation notes:**
- **UI documentation:** When a user creates a task with a `Calendar` or `Cron` schedule, the task editor shows an info callout: "Schedules use your Mac's local time. During daylight saving transitions, tasks scheduled between 2:00-3:00 AM may be skipped (spring forward) or run twice (fall back)."
- **Interval-based alternative:** For tasks where exact timing matters (monitoring, alerting), recommend `Schedule::Interval` which uses elapsed seconds and is unaffected by DST. The task editor should note: "Interval schedules are immune to daylight saving changes."
- **No timezone field.** All calendar schedules run in the system timezone, matching launchd semantics. This avoids confusing mismatches where the user sets a timezone but launchd ignores it.
- **`lc-runner` logging:** When a task executes, the execution log records both UTC and local timestamps. This makes it easy to diagnose DST-related "double run" or "skipped run" situations after the fact.
- **Dashboard indicator:** During the week of a DST transition (detectable via the system's timezone database), the dashboard shows a subtle informational notice: "Daylight saving time change occurs this week. Calendar-scheduled tasks near 2:00 AM may be affected."

#### D4. Distribution Strategy

**Decision:** Two distribution channels: DMG for the Swift app (primary), Homebrew for the CLI tools. The Swift app bundles the Rust CLI binaries inside the app bundle.

**Rationale:** A native Swift app distributes most naturally as a DMG (or eventually via the Mac App Store). The Rust daemon and CLI binaries are implementation details that most users should not need to install separately. However, power users and CI environments need standalone CLI access via Homebrew.

**Implementation notes:**
- **Primary channel: DMG download.**
  - The Swift app is built as `Loop Commander.app` and distributed as a signed, notarized DMG.
  - The app bundle embeds the Rust binaries inside `Loop Commander.app/Contents/MacOS/`: `loop-commander` (daemon), `lc` (CLI), and `lc-runner` (task executor).
  - On first launch, the app symlinks `lc` to `/usr/local/bin/lc` (with user permission via a macOS authorization prompt) so the CLI is available from the terminal. If the user declines, the CLI remains usable via the full path.
  - The `find_runner()` logic (Section 4) searches in this order: (1) same directory as the running binary, (2) `~/.loop-commander/bin/`, (3) `/usr/local/bin/`, (4) `$PATH`.
- **Secondary channel: Homebrew.**
  - `brew install loop-commander` installs the three Rust binaries (`loop-commander`, `lc`, `lc-runner`) to the Homebrew prefix.
  - The Homebrew formula does NOT include the Swift app. It is CLI-only for users who want headless operation, CI pipelines, or remote servers.
  - `brew install --cask loop-commander` installs the full DMG (Swift app + embedded binaries).
- **`cargo install` is not an official channel.** Building from source requires the full Cargo workspace and Swift toolchain. It is documented in the README for contributors but not advertised to end users.
- **Binary discovery:** The daemon and `lc-runner` binaries must be co-located or discoverable. The `lc daemon install` command writes a launchd plist that references the absolute path to the `loop-commander` binary, ensuring launchd can find it regardless of installation method.

#### D5. Budget Tracking Uses Actual API Costs with Estimation Fallback

**Decision:** Use actual API costs extracted from Claude Code's `--output-format json` output as the primary budget tracking mechanism. Fall back to a conservative time-based estimate when JSON output is unavailable or unparseable.

**Rationale:** Accurate cost tracking is essential for budget enforcement to be trustworthy. Claude Code's `--output-format json` provides structured output including token usage and cost data. The spec already wraps non-claude commands with `--output-format json` (Section 5, step 7), so this data should be available for most executions. However, the system must degrade gracefully when it is not.

**Implementation notes:**
- **Primary: actual cost extraction.**
  - `lc-runner` always passes `--output-format json` when invoking Claude Code (this is already in the spec).
  - After execution, parse the JSON output for the `result.cost_usd` field (or equivalent -- the exact field name should be documented when Claude Code's JSON schema stabilizes).
  - If the cost field is present and valid, record it in `ExecutionLog.cost_usd`.
- **Fallback: time-based estimation.**
  - If JSON parsing fails or the cost field is absent, estimate cost based on execution duration: `estimated_cost = duration_seconds * $0.01` (configurable via `GlobalConfig.cost_estimate_per_second`, default `0.01`).
  - Record the estimate in `ExecutionLog.cost_usd` and set a new boolean field `ExecutionLog.cost_is_estimate = true`.
  - The dashboard displays estimated costs with a distinct visual treatment (italic text, "(est.)" suffix) so users know which numbers are precise and which are approximate.
- **Budget enforcement:**
  - The daily budget cap (from C5's fix: `GlobalConfig.daily_budget_cap`) uses the sum of all recorded costs, whether actual or estimated.
  - Per-run budget is checked *before* execution (pre-flight) by comparing the task's `max_budget_per_run` against the running daily total. The per-run limit is also enforced via Claude Code's `--max-cost` flag if available.
  - When a task is skipped due to budget, the execution log records status `Skipped` with a clear summary.
- **Dashboard display:**
  - The "Total Spend" metric card shows the sum, with a tooltip breaking down actual vs. estimated portions.
  - Per-task cost history distinguishes actual from estimated costs.
  - A settings option allows users to adjust the `cost_estimate_per_second` rate based on their API plan.

#### D6. Upgrade Path

**Decision:** The Swift app uses the Sparkle framework for automatic updates. Homebrew handles CLI-only upgrades. Version mismatches between components are detected and surfaced to the user.

**Rationale:** macOS users expect in-app auto-update (like virtually every Mac app outside the App Store). Sparkle is the de facto standard for this in the Swift ecosystem. Homebrew users expect `brew upgrade`. The critical concern is version mismatches between the daemon, CLI, and runner binaries, which can cause subtle protocol-level bugs.

**Implementation notes:**
- **Swift app updates (Sparkle):**
  - The app integrates the Sparkle framework (`https://sparkle-project.org`).
  - An appcast XML feed is hosted at a stable URL (e.g., `https://loopcommander.dev/appcast.xml`).
  - The app checks for updates on launch (configurable: daily, weekly, or manual-only).
  - When an update is available, Sparkle presents its standard UI: release notes, "Install Update" button, option to skip this version.
  - Since the Rust binaries are embedded in the app bundle, updating the app automatically updates the daemon and runner. After update, the app restarts the daemon if it was running.
- **Homebrew CLI updates:**
  - `brew upgrade loop-commander` updates the CLI binaries.
  - The Homebrew formula version is kept in sync with the app version.
- **Version mismatch detection:**
  - All binaries (`loop-commander`, `lc`, `lc-runner`) embed a version string at compile time via `env!("CARGO_PKG_VERSION")`.
  - The daemon's `daemon.status` response includes its version.
  - `lc-runner` passes its version to the daemon when spawned (via `--version` in the execution log metadata).
  - The daemon compares its version against `lc-runner`'s version on each execution. If they differ, it logs a warning and includes a `version_mismatch: true` field in the `daemon.status` response.
  - The Swift app surfaces version mismatches as a warning banner: "The daemon (v0.2.0) and task runner (v0.1.0) are different versions. Update all components to avoid unexpected behavior."
  - The CLI (`lc --version`) shows its own version and queries the daemon for its version, displaying both.
- **Handling running tasks during upgrade:**
  - The Sparkle update process first sends `SIGTERM` to the daemon, which triggers graceful shutdown (Section 7: remove PID file, remove socket, exit 0).
  - Running `lc-runner` processes are NOT killed. They were spawned by launchd and will complete with the old binary. Their execution logs will record the old version.
  - After the update completes, the app starts the new daemon, which re-registers all active launchd jobs with the new `lc-runner` binary path.
- **Schema migrations:**
  - SQLite schema migrations are handled by the version field (R7). On startup, the daemon checks the DB schema version and runs migrations sequentially.
  - YAML config migrations: `GlobalConfig.version` (currently `1`) is checked on load. If the version is older than expected, the daemon applies transforms in order (v1->v2, v2->v3, etc.) and rewrites the file.
  - Task YAML files do not have a version field. If the task schema changes, the daemon applies a best-effort migration on load (missing fields get defaults, unknown fields are preserved via `serde(flatten)` or ignored).

#### D7. Concurrency Limit for Simultaneous Task Executions

**Decision:** Default `max_concurrent_tasks = 4` in `GlobalConfig`, enforced by the daemon via a semaphore. Tasks beyond the limit are queued and executed in FIFO order.

**Rationale:** Each Claude Code invocation consumes significant resources: CPU for the language model client, network bandwidth for API calls, and API rate limit quota. Running 20 simultaneous tasks would degrade performance for all of them and risk API rate limiting. A default of 4 balances throughput with resource safety, and matches the typical number of performance cores on modern Macs.

**Implementation notes:**
- **GlobalConfig field:**
  ```yaml
  max_concurrent_tasks: 4    # 1-16, default 4
  ```
  Validated on save: minimum 1, maximum 16. The UI exposes this in Settings with a stepper control and explanatory text: "Maximum number of tasks that can run simultaneously. Lower values reduce system load and API rate limit risk."
- **Daemon-side enforcement (for `task.run_now`):**
  - The daemon maintains a `tokio::sync::Semaphore` with `max_concurrent_tasks` permits.
  - When `task.run_now` is called: acquire a permit (non-blocking check). If available, spawn `lc-runner`. If not, add the task to a FIFO queue (`VecDeque<TaskId>`).
  - When a running task completes (daemon detects via child process exit), release the permit and dequeue the next waiting task.
  - The `task.run_now` response includes a `queued: bool` field so the UI can show "Queued" vs. "Running" status.
- **launchd-side enforcement (for scheduled tasks):**
  - launchd spawns `lc-runner` directly, bypassing the daemon's semaphore. To enforce concurrency limits for scheduled tasks, `lc-runner` itself checks a system-wide semaphore before executing.
  - Implementation: `lc-runner` uses a named POSIX semaphore (`/loop-commander-concurrency`) initialized to `max_concurrent_tasks` (read from `GlobalConfig` at startup).
  - If the semaphore cannot be acquired within 60 seconds, `lc-runner` logs the execution as `Skipped` with summary `"Concurrency limit reached (4/4 tasks running). Task will retry at next scheduled time."` and exits with code 0 (so launchd does not mark it as failed).
  - The 60-second wait allows for brief bursts where multiple tasks are scheduled at the same minute but complete quickly.
- **Dashboard visibility:**
  - The dashboard shows a "Running: 2/4" indicator next to the task count, reflecting current utilization vs. the concurrency limit.
  - Queued tasks appear in the task list with a "Queued" badge.
  - If tasks are frequently being skipped due to concurrency limits, the dashboard shows a suggestion: "Tasks are being skipped due to concurrency limits. Consider increasing max_concurrent_tasks in Settings or staggering task schedules."

---

### 14.5 Architecture Review Summary

The architecture is a Cargo workspace with clean separation of concerns, launchd for reliable scheduling, SQLite for structured logs, and a native Swift macOS app. The pivot from Tauri to Swift resolved the most critical architectural concern (dual-writer concurrency) and provides a better native macOS experience.

**Resolved concerns:**

1. **Dual-writer architecture (C1, Q1):** RESOLVED. By making the daemon the sole API server that both the Swift app and CLI talk to, there is no more dual-writer problem. The daemon is the single source of truth for config and state.

2. **Real-time updates (R6):** RESOLVED. The `events.subscribe` JSON-RPC method provides push-based real-time updates to the Swift app, eliminating sluggish polling.

**Remaining concerns:**

3. **Security surface (C2, C3):** Command execution and input validation still need hardening before this can be trusted to run unattended.

4. **launchd API modernity:** The spec references deprecated `launchctl load`/`unload` APIs. While they still work, using the modern `bootstrap`/`bootout` APIs is more forward-compatible. (Fixed inline above.)

5. **Crate dependency graph:** The `lc-daemon` Cargo.toml listed `lc-runner` as a dependency, but lc-runner is a standalone binary — the daemon should spawn it, not link it. (Fixed inline above.)

6. **Missing observability:** The spec has no structured logging format, no metrics endpoint, no way to debug why a task is misbehaving other than reading raw stdout/stderr. Adding structured tracing output (JSON format, configurable via `RUST_LOG`) and a `lc doctor` command for diagnosing common issues would significantly improve the operational experience.

**Key benefit of the Swift pivot:** The clean JSON-RPC boundary means the Rust crates and Swift app can be developed, tested, and released independently. The daemon's API is the contract — any client that speaks JSON-RPC over the Unix socket can operate Loop Commander.
